
#include "escapex.h"
#include "chunks.h"
#include "util.h"

chunk::chunk(uint k, int ii) : type(CT_INT), key(k), i(ii) {}
chunk::chunk(uint k, bool bb) : type(CT_BOOL), key(k), i(bb) {}
chunk::chunk(uint k, string ss) : type(CT_STRING), key(k), i(0), s(ss) {}

string chunk::tostring() {
  /* key and type first, then data.
     the size of string data must be deduced from some other 
     source. */
  // printf("tostring(%p): key %d, type %d, i %d, b %d, s %");

  string res = sizes((int)key) + sizes((int)type);
  switch (type) {
  case CT_BOOL:
  case CT_INT: return res + sizes(i);
  case CT_STRING: return res + s;
  default:;
  }
  abort();
}

chunk * chunk::fromstring(string s) {
  /* no type field */
  if (s.length() < 8) return 0;
  unsigned int idx = 0;
  unsigned int key = (unsigned int)shout(4, s, idx);
  chunktype ty = (chunktype)shout(4, s, idx);

  switch(ty) {
  case CT_BOOL:
    if (s.length() < 12) return 0;
    else return new chunk(key, (bool)shout(4, s, idx));
  case CT_INT: 
    if (s.length() < 12) return 0;
    else return new chunk(key, (int)shout(4, s, idx));
  case CT_STRING:
    return new chunk(key, (string)s.substr(8, s.length() - 8));
  default: return 0;
  }
}

chunks * chunks::create() {
  chunks * ch = new chunks();
  if (!ch) return 0;
  ch->data = 0;
  return ch;
}

void chunks::destroy() {
  while(data) {
    delete(ptrlist<chunk>::pop(data));
  }
  delete this;
}

chunk * chunks::get(uint k) {
  ptrlist<chunk> * tmp = data;
  for(;tmp; tmp = tmp -> next)
    if (tmp->head->key == k) return tmp->head;
  return 0;
}

int chunks::sort(chunk * l, chunk * r) {
  return l->key - r->key;
}

string chunks::tostring() {
  string op; /*  = sizes(data->length()); */

  /* sort so that we change the player file less often */
  ptrlist<chunk>::sort(chunks::sort, data);

  /*
  {
  printf ("prepass\n");
  for(ptrlist<chunk> * tmp = data; tmp; tmp = tmp -> next) {
    printf("    tmp is %p next is %p key: ", tmp, tmp -> next);
    printf("    .. %d\n", tmp->head->key);
  }
  }
  */

  /* 
  printf("chunk tostring:\n");
  printf("data: %p\n", data); */
  for(ptrlist<chunk> * tmp = data; tmp; tmp = tmp -> next) {
    /*
      printf("    tmp is %p next is %p key: ", tmp, tmp -> next);
      printf("    .. %d\n", tmp->head->key);
    */
    string it = tmp->head->tostring();
    op = op + sizes(it.length()) + it;
  }

  return op;
}

/* exhausts the input string */
chunks * chunks::fromstring(string s) {
  uint idx = 0;
  ptrlist<chunk> * dat = 0;

  while (idx < s.length()) {
    int len = shout(4, s, idx);
    /* XXX cleanup */
    if (idx + len > s.length()) {
      printf("bad length\n");
      return 0;
    }
    string ch = s.substr(idx, len); idx += len;
    chunk * c = chunk::fromstring(ch);
    /* XXX cleanup  */
    if (!c) {
      printf("bad c\n");
      return 0;
    }
    ptrlist<chunk>::push(dat, c);
  }

  chunks * ck = new chunks();
  if (!ck) return 0;

  ck->data = dat;
  
  return ck;
}

void chunks::insert(chunk * insme) {
  for(ptrlist<chunk> * tmp = data;
      tmp; tmp = tmp -> next) {

    if (insme->key == tmp->head->key) {
      delete tmp->head;
      tmp->head = insme;
      return;
    }
  }

  /* not found */
  ptrlist<chunk>::push(data, insme);
}
