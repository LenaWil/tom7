
#include "menu.h"
#include "draw.h"
#include "chars.h"

/* n.b.: for fixing all these crazy corner cases, it seems that a good
   technique is to simply 'retype' any area that needs to be reflown. */

/* 
  we have an invariant that 'before' is chunked into lines
  by virtual line-breaks (or real line breaks), where no
  line is longer than the width of the text box. there are
  three kinds: 
     \n    --- a real newline. obviously a line break
     \x00  --- a virtual line break, translates into a space
     \x01  --- a virtual line break, translates to nothing

  then we can have a function like getprevline that returns
  a string and a new pointer into 'before'. */

/* XXX moves cursor home. this is OK for current use,
   but should be documented */
string textbox::get_text() {
  /* go home (to avoid virtual line breaks) */
  while(before) left(false);
  int len = after->length ();

  char * out = (char*)malloc(sizeof(char) * (len + 1));

  /* zero terminate */
  out[len] = 0;

  {
    vallist<char> * aa = after;
    int i = 0;
    while(aa) {
      out[i] = aa->head;
      aa = aa -> next;
      i++;
    }
  }

  string ret = out;
  free(out);
  return ret;
}

void textbox::empty() {
  vallist<char>::diminish(before);
  vallist<char>::diminish(after);
}

void textbox::set_text(string s) {
  /* remove what's there */
  empty();
  before = 0;
  int sl = s.length();

  /* push in reverse order yields in-order list */
  for(int i = sl - 1; i >= 0; i --) {
    after = new vallist<char>(s[i], after);
  }

}

void textbox::size(int & w, int & h) {
  /* text area plus boundary, scroll indicator */
  w = fon->width * (charsw + 3);
  h = fon->height * (charsh + 3) - (fon->height >> 1);
}

void textbox::draw(int posx, int posy, int f) {

  /* draw header and skip */
  fon->draw(posx, posy, question);
  posy += fon->height;

  /* draw outline */
  int ww = fon->width * (charsw + 3);
  int hh = fon->height * (charsh + 2);

  Uint32 color;

  if (f) color = SDL_MapRGBA(screen->format, 220, 220, 180, 255);
  else color   = SDL_MapRGBA(screen->format, 120, 120, 145, 255);

  /* XXX consider filling the inside, too? */
  {
    SDL_Rect dst;

    /* left side */
    dst.x = posx + 2;
    dst.y = posy + 6;
    dst.h = hh - (11 + (fon->height >> 1));
    dst.w = 2;
    SDL_FillRect(screen, &dst, color);

    /* right side */
    dst.x = posx + ww - 2;
    SDL_FillRect(screen, &dst, color);

    /* top */
    dst.x = posx + 2;
    dst.h = 2;
    dst.w = ww - 4;
    SDL_FillRect(screen, &dst, color);

    /* bot */
    dst.y = posy + 1 + hh - (fon->height);
    dst.w = ww - 2;
    SDL_FillRect(screen, &dst, color);
  }

  /* now draw text! */
  
  /* start by going backwards into the 'before'
     list, collecting up lines of text until we
     get to

     (a) the beginning of the text. Then we
     can just draw it in a straightforward way.
     
     (b) n lines, where n is about height/2.
     in this case, we can ignore anything
     preceding these lines, and draw forward
     up to the cursor. (XXX n should be
     calculated in a more clever way, since
     if you type straight, now, the cursor hangs
     halfway through the box.)

     we always draw what occurs after the cursor
     the same way, calculating line-breaks on
     the fly. */

  /* XXX if drawlines == 0? */
  /* changed to 3/4 of window, slightly better */
  int drawlines = (charsh * 3) >> 2;

  /* distinguish (a) and (b): can we get
     at least drawlines lines? */
  
  int count = 0;
  vallist<char> * tmp = before;
  stringlist * blines = 0;

  while(tmp) {
    if (count >= drawlines) break;
    
    stringlist::push(blines, prevline(tmp));
    count++;
  }

  /* now we are in case (a) if !tmp,
     and case (b) otherwise. 

     actually, we treat both cases the
     same way:

     1. draw 'count' partial lines. 
     2. (draw cursor)
     3. draw characters (doing word wrap)
     in order to fill text box or
     exhaust 'after.'
  */

  /* be in text area */
  posx += fon->width;
  posy += fon->height;

  int y = 0;

  /* invariant: count = length(blines) */
  string lastline;
  for(int i = 0; i < count; i ++) {
    lastline = stringpop(blines);
    fon->draw_plain(posx, posy + y * fon->height, lastline);

    /* printf("drew [%s] at %d\n", lastline.c_str(), y); */
    y ++;
  }
  
  if (count) y --;

  /* now y is on the final line, which
     is equal to lastline. Draw the cursor. */

  {

    if (f) color = SDL_MapRGBA(screen->format, 255, 255, 100, 255);
    else color   = SDL_MapRGBA(screen->format, 120, 120, 145, 255);
    SDL_Rect dst;

    /* left side */
    dst.x = posx + fon->sizex_plain(lastline) + 1;
    dst.y = posy + (y * fon->height) - 1;
    dst.h = fon->height + 2;
    dst.w = (fon->width - fon->overlap) - 1;
    SDL_FillRect(screen, &dst, color);
  }

  int x = lastline.length ();
  
  vallist<char> * rest = after;
  /* write characters */
  while(rest && y < charsh) {
    /* see if we can fit this word on the line */
    string w = nextword(rest);

    while (w.length () > 0) {

      if (w.length () + x > (unsigned)charsw) {
        /* wrap! */
          
        if (x == 0) {
	  /* impossible to wrap whole word; split */
	  fon->draw_plain(posx + (x * (fon->width - fon->overlap)),
			  posy + (y * fon->height), w.substr(0, charsw));
	  x = 0;
	  y ++;
	  if (y >= charsh) break;
	  w = w.substr(charsw, w.length () - charsw);
	  continue;
        } else {
	  x = 0;
	  y ++;
	  if (y >= charsh) break;
        }
      } else {

	fon->draw_plain(posx + (x * (fon->width - fon->overlap)),
			posy + (y * fon->height),
			w);
	x += w.length ();
	w = "";
      }
      
    }

    /* deal with whitespace. */
    if (rest) {
      if (rest->head == '\n') {
	/* carriage return */
	x = 0;
	y ++;
      } else x ++;
      /* skip it */
      rest = rest -> next;
    }
  }
}

/* PERF used extensively, has inefficient implementation */
string textbox::prevline(vallist<char> *& bb) {
  string theline;

  /* printf("prevline :"); */
  while(bb) {
    /* printf("%c/%d ", bb->head);*/
    switch(bb->head) {
    case '\n':
    case '\x00':
    case '\x01':
      /* any break will work */
      bb = bb-> next;
      return theline;
    default:
      theline = bb->head + theline;
      break;
    }

    bb = bb-> next;
  }

  return theline;
}

/* leaves aa pointing at the whitespace
   character that follows this word (orelse null) */
string textbox::nextword(vallist<char> *& aa) {
  string theword;

  while (aa) {
    switch(aa->head) {
    case '\x00':
    case '\x01':
      theword += RED "X" "X" "X" POP;
      break;
    case '\n':
    case ' ':
      return theword;
    default:
      theword += aa->head;
      break;
    }
    aa = aa -> next;
  }
  return theword;
}

/* pop the last word from bb. p will be set to the type of
   breaking char that preceded this word (which is also removed
   from bb.) */
string textbox::popword(vallist<char> *& bb, char & p) {
  string out;
  while (bb) {
    char k = vallist<char>::pop(bb, ' ');
    switch(k) {
    case ' ':
    case '\n':
    case '\x00':
    case '\x01':
      p = k;
      return out;
    default:
      out = k + out;
    }
  }
  /* leaves p as is */
  return out;
}

void textbox::goto_beginning() {
  while(before) left(false);
}

void textbox::goto_end() {
  while(after) right(false);
}

inputresult textbox::key(SDL_Event e) {

  int key = e.key.keysym.sym;

  if (!(e.key.keysym.mod & (KMOD_CTRL | KMOD_ALT))) {
    switch(key) {
    case SDLK_TAB:
    case SDLK_ESCAPE:
      return menuitem::key(e);
      
    case SDLK_DOWN:
      down ();
      return inputresult(MR_UPDATED);

    case SDLK_UP:
      up();
      return inputresult(MR_UPDATED);

    case SDLK_BACKSPACE:
      left(true);
      return inputresult(MR_UPDATED);
    case SDLK_LEFT:
      left(false);
      return inputresult(MR_UPDATED);

    case SDLK_DELETE:
      right(true);
      return inputresult(MR_UPDATED);
    case SDLK_RIGHT:
      right(false);
      return inputresult(MR_UPDATED);

    case SDLK_HOME:
      goto_beginning();
      return inputresult(MR_UPDATED);
      
    case SDLK_END:
      goto_end();
      return inputresult(MR_UPDATED);

    case SDLK_KP_ENTER:
    case SDLK_RETURN:
      type((char)'\n');
      return inputresult(MR_UPDATED);

    default: {
      int uc = e.key.keysym.unicode;
      if ((uc & ~0x7F) == 0 && uc >= ' ') {
	type((char)(uc));
	return inputresult(MR_UPDATED);
      } else return inputresult(MR_REJECT);
    }
    }
  } else return inputresult(MR_REJECT);
}

void textbox::right(bool erasing) {
  if (after) {
    char k = vallist<char>::pop(after, ' ');
    if (!erasing) type(k);
  } 
}

void textbox::left(bool erasing) {
  left_noflow(erasing);
  if (before) {
    left_noflow(false);
    right(false);
  }
}

void textbox::left_noflow(bool erasing) {
  while (before) {
    char k = vallist<char>::pop(before, '*');
    if (k == '\x00') {
      k = ' ';
    } else if (k == '\x01') {
      /* skip virtual breaks */
      continue;
    }
    if (!erasing) vallist<char>::push(after, k);
    return ;
  } 
}

void textbox::up() {
  /* find out how many characters back 'up' is. */

  vallist<char> * tmp = before;
  int thisline = countprevline(tmp);
  int prevline = countprevline(tmp);

  int charsback = 
    /* go back to beginning of previous line */
    thisline + prevline + 1 /* break */ +
    /* but then go forward to horizontally match
       our position on this line */
    -(util::minimum(thisline, prevline));

  while (charsback--) left(false);
}

void textbox::down() {
  /* how many chars into this line? */

  vallist<char> * tmp = before;
  int thisline = countprevline(tmp);

  while (after) {
    /* did we reach new line? */
    right(false);
    if (before->head == '\n' ||
	before->head == '\x00' ||
	before->head == '\x01') {
      while (after && thisline--) {
	right(false);
	if (before && (before->head == '\n' ||
		       before->head == '\x00' ||
		       before->head == '\x01')) {
	  /* went off the end of the line */
	  left(false);
	  return;
	}
      }

      return;
    }
  }
  /* got to end; that's fine */
}

/* PERF doesn't need to build string */
int textbox::countprevline(vallist<char> *& bb) {
  string pl = prevline(bb);
  return pl.length ();
}

/* insert a key at the cursor. tricky because
   it needs to maintain the word wrap invariant
   in the 'before' list. */
void textbox::type(char k) {
  vallist<char> * tmp = before;
  string thisline = prevline(tmp);

  /* since we might be adding onto the beginning of an existing word,
     we need to include it in our line length test */
  vallist<char> * tmp2 = after;
  string nword = nextword(tmp2);

  /* XXX if typing a space character -- even if it fits --
     we might split up a long word so that its first half
     can now fit on the previous line:

     here's a line that can support about 8 more chars
     here'sareallylongwordthatcertainlywon'tfit
         ^
	 inserting a space here should move 'here' to prev line. */

  /* printf("type: '%c' thisline '%s' nextword '%s'\n",
     k, thisline.c_str(), nword.c_str()); */

  /* XXX check if we're typing a newline char. 
     it can always fit */
  if (thisline.length() + nword.length () < (unsigned)charsw) {
    /* printf("  ..fits\n"); */
    vallist<char>::push(before, k);
  } else if (k == ' ') {
    /* printf ("  .. no fit adding whitespace\n"); */
    vallist<char>::push(before, '\x00');

  } else {
    /* must wrap. */
    /* get new word */
    char p = 0;
    string ww = popword(before, p) + k;

    /* printf("  .. no fit: lastword '%s'\n", ww.c_str()); */

    if (before) {
      /* not at the very beginning */
      
      /* are we at the beginning of the line? */
      if (p == ' ') {
	/* no -- move to the next line, and recurse! */
	vallist<char>::push(before, '\x00');
	for(unsigned int i = 0; i < ww.length(); i ++) {
	  type(ww[i]);
	}
      } else {
        /* In this case, there's no sense in trying to word
           wrap. We'll put a virtual break if we've ABSOLUTELY
           run out of space. */
	/* put back breaking char */
        vallist<char>::push(before, p);
	addstring(ww);

        if (ww.length() >= (unsigned)charsw) {

  	  /* then virtual break */
	  vallist<char>::push(before, '\x01');
        }
      }
    } else {
      /* if before is empty, we'll put
	 the word here, and split it */

      addstring(ww);

      if (ww.length() >= (unsigned)charsw) {
         /* then virtual break */
         vallist<char>::push(before, '\x01');
      }
    }
  }

}

/* push a whole string onto before */
void textbox::addstring(string s) {
  for(unsigned int i = 0; i < s.length(); i ++) {
    vallist<char>::push(before, s[i]);
  }
}
