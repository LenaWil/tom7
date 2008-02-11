 var punctuationVersion = " 3 May 2007";
 var punctuationID = 1;
 var punctuationEdits = undefined;
 var punctuationOriginalSummary = undefined;
 var punctuationPageOriginalSummary = undefined;
 var puCONTEXT = 40;

 var puENDASH = 0;
 var puSPELL = 1;
 var puEMDASH = 2;
 var puCOMMA = 3;
 var puPERCENT = 4;
 var puBORN = 5;
 var puLINKSPACE = 6;
 var puDECADE = 7;
 var puPAREN = 8;
 var puXHTML = 9;
 var puREF = 10;
 var puDESCRIPTIONS = new Array("en dash", "spelling", "em dash", "comma", "percent", "born", "link space", "decade", "paren", "xhtml", "ref");
 var puNDESC = 11;

 // TODO:
 // finish percent space
 // http link with double brackets [[http://awesome.com like this]]
 // fake em dashes - like this - are pretty common
 // references before punctuation <ref>references tag style guide</ref>.
 //   also, extra space, or duplicated or missing punctuation (very common!)
 // allow disabling of a specific 'which' for all edits (implement puAllOn/AllOff)
 // when showing changes, need to paint turned-off edits in fade out color, since
 //   this currently only happens to the in-dom version, and not when we reshow changes
 //   after eg. hide or allon/alloff
 // lowercase words in headings that don't appear capitalized in the document anywhere

 function doPunctuation() {
  // alert(document.editform.wpTextbox1.value);
  // document.editform.wpMinoredit.checked = true;
 
  // just need some prominent element to put our messages in. We use the "From Wikipedia" header.
  var e = document.getElementById('siteSub');
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Running autopunctuation...</span>';
 
  // We'll represent the document as a list of chunks, where
  // a chunk can either be raw text (no replacement suggested)
  // or an edit (the suggested replacement text, the reason,
  // the original text, and a flag indicating whether the
  // change has been rejected).
  // start by producing the singleton raw chunk:
  var edits = new puCons(puRaw(document.editform.wpTextbox1.value), undefined);

  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">References...</span>';
  setTimeout(function (){ // refs
  edits = puRefs(edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Spelling...</span>';
  setTimeout(function (){ // spell
  edits = puSpell(edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Born style...</span>';
  setTimeout(function (){ // born
  edits = puBorn(edits);
  
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Em dashes...</span>';
  setTimeout(function (){ // em dash
  edits = puRawMapConcat(puEmDash, edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">En dashes...</span>';
  setTimeout(function (){ // en dash
  edits = puRawMapConcat(puEnDash, edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Commas...</span>';
  setTimeout(function (){ // comma
  edits = puRawMapConcat(puComma, edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Link space...</span>';
  setTimeout(function (){ // linkspace
  edits = puRawMapConcat(puLinkSpace, edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Decade...</span>';
  setTimeout(function (){ // decade
  edits = puRawMapConcat(puDecade, edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">Parens...</span>';
  setTimeout(function (){ // paren
  edits = puRawMapConcat(puParen, edits);
 
  e.innerHTML = '<span style="border : 1px solid #333399; padding : 4px; margin : 4px;">XHTML...</span>';
  setTimeout(function (){ // xhtml
  edits = puXhtml(edits);
 
  punctuationEdits = edits;
  punctuationOriginalSummary = document.editform.wpSummary.value;
 
  document.editform.wpTextbox1.value = puRewrite(edits);
  document.editform.wpSummary.value = puSummary(edits);
 
  // finally, show interface for undos
  e.innerHTML = puShowChanges("", edits);
 
  }, 50); // xhtml
  }, 50); // paren
  }, 50); // decade
  }, 50); // linkspace
  }, 50); // comma
  }, 50); // en dash
  }, 50); // em dash
  }, 50); // born
  }, 50); // spell
  }, 50); // refs
 };

 function puSummary(edits) {
  var counts = new Array();
  for(var i = 0; i < puNDESC; i ++) counts.push (0);
 
  for(var l = edits; l != undefined; l = l.tail) {
    if (!l.head.israw) {
      counts[l.head.what] ++;
      // alert("!" + l.head.what + "(" + puDESCRIPTIONS[l.head.what] + ") = " + counts[l.head.what]);
    }
  }
 
  var s = "";
 
  for(var j = 0; j < puNDESC; j ++) {
    if (counts[j] > 0) {
      if (s != "") s = s + "; ";
      s = s + counts[j] + " " + puDESCRIPTIONS[j];
    }
    // alert("@" + j + ": " + counts[j] + "/" + puDESCRIPTIONS[j] + " -> " + s);
  }
 
  if (s == "") return punctuationOriginalSummary;
  else {
    if (punctuationOriginalSummary == punctuationPageOriginalSummary) {
      // user never did anything except run punctuation, so minor
      document.editform.wpMinoredit.checked = true;
    }
 
    return punctuationOriginalSummary + 
      (punctuationOriginalSummary == "" ? "" : " ") + "(auto: " + s + ")";
  }
 };

 function puKindButtons(edits) {
  var counts = new Array();
  for(var i = 0; i < puNDESC; i ++) counts.push (0);
 
  for(var l = edits; l != undefined; l = l.tail) {
    if (!l.head.israw) {
      counts[l.head.what] ++;
    }
  }
 
  // now for any edit kind we did do, give buttons for them.
  var s = "<table><tr>"
  for(var j = 0; j < puNDESC; j ++) {
    if (counts[j] > 0) {
      s = s +
          '<td><div style="padding : 3px; margin-right: 6px; border : 2px solid #333377; background : #DDDDFF"><b><center>' + 
             counts[j] + " " + puDESCRIPTIONS[j] + '</center></b>' +
          '<br/> <span style="cursor : hand; cursor : pointer;" onClick="puAllOn(' + j + ');">ON</span>&nbsp;' +
                '<span style="cursor : hand; cursor : pointer;" onClick="puAllOff(' + j + ');">OFF</span>&nbsp;' +
                '<span style="cursor : hand; cursor : pointer;" onClick="puAllHide(' + j + ');">HIDE</span>' +
          '</div></td>';
// onClick="puUndo(' + l.head.id +');"
    }
  }
  s = s + '</tr></table>';
  return s;
 };

 function puContextBefore(ol, ne) {
   var s = ol + ne;
   if (s.length < puCONTEXT) return s;
   else return s.substring(s.length - puCONTEXT);
 };

 function puContextAfter(l) {
   var s = "";
   for(var z = l; z != undefined; z = z.tail) {
     if (z.head.israw) s = s + z.head.text;
     else s = s + z.head.rep;
     if (s.length >= puCONTEXT) return s.substr(0, puCONTEXT);
   }
   return s;
 };

 // from a chunk list, give an HTML summary with edit buttons
 // pass in the context c of some previous characters.
 function puShowChanges(c, l) {
   var o = puKindButtons(l);
   o = o + "<br/>";
   while (l != undefined) {
     if (l.head.israw) {
       var nc = puContextBefore(c, l.head.text);
       o = o + '<span style="color:#AAAAAA">(...)</span>';
       c = nc;
     } else if (l.head.hidden) {
       var nc = puContextBefore(c, l.head.rep);
       o = o + '<span style="color:#AAAAAA">(hidden)</span>'
       c = nc;
     } else {
       // XXX hover could select in edit box??
       var nc = puContextBefore(c, l.head.rep);
       var ca = puContextAfter(l.tail);
       o = o + '<br/> (' + puHighlightContext(puEscape(c)) +
               '<span id="puEdit' + l.head.id + '" style="border : 1px solid #FF9999; background : #FFDDDD; cursor : hand; cursor : pointer;"' +
               ' onClick="puUndo(' + l.head.id +');">' +
                 puHighlight(puEscape(l.head.orig)) + "&rarr;" + puHighlight(puEscape(l.head.rep)) + '</span>'
               + puHighlightContext(puEscape(ca)) +
               ') ';
       c = nc;
     }
     l = l.tail;
   }
   return (o + " End");
 };

 // show spaces as light underscores, since many of these involve the deletion/insertion of spaces
 function puHighlight(s) {
   return s.replace(/ /g, '<span style="color:#888888">_</span>');
 };

 function puHighlightContext(s) {
   s = s.replace(/\[/g, '<span style="color:#FF0000">[</span>');
   s = s.replace(/\]/g, '<span style="color:#FF0000">]</span>');
   s = s.replace(/\{/g, '<span style="color:#00FF00">{</span>');
   s = s.replace(/\}/g, '<span style="color:#00FF00">}</span>');
   s = s.replace(/\|/g, '<span style="color:#0000FF">|</span>');
   return s;
 };

 function puEscape(s) {
   var s1 = s.replace(/</g, "&lt;");
   var s2 = s1.replace(/>/g, "&gt;");
   return s2;
 };
 
 // called from generated html; hides (just don't display) all
 // from this kind
 function puAllHide(k) {
    for(var h = punctuationEdits; h != undefined; h = h.tail) {
       if (h.head.what == k) {
         h.head.hidden = true;
       }
    }
    // always keep these up to date (actually this should never need a rewrite, right?)
    // document.editform.wpTextbox1.value = puRewrite(punctuationEdits);
    document.editform.wpSummary.value = puSummary(punctuationEdits);
    var e = document.getElementById('siteSub');
    e.innerHTML = puShowChanges("", punctuationEdits);

    return ;
 };

 // called from generated html above. undoes the specified edit, making
 // the chunk into a raw chunk and rewriting the textarea.
 function puUndo(i) {
    // alert('undo unimplemented for #' + i);
    for(var h = punctuationEdits; h != undefined; h = h.tail) {
       if (h.head.id == i) {
         h.head.text = h.head.orig;
         h.head.israw = true;
 
         // undo edit where it matters         
         document.editform.wpTextbox1.value = puRewrite(punctuationEdits);
         document.editform.wpSummary.value = puSummary(punctuationEdits);
 
         var e = document.getElementById('puEdit' + i);
         e.style.border = "none";
         e.style.opacity = "0.5";
         e.style.filter = "Alpha(Opacity=50)";
         return;
       }
    }
    alert("Oops, can't undo? " + i + " ... " + punctuationEdits);
 };

 // generate the raw text from a chunk list
 function puRewrite(l) {
   var o = "";
   while(l != undefined) {
     if (l.head.israw && l.head.text != undefined) o = o + l.head.text;
     else if (!l.head.israw && l.head.rep != undefined) o = o + l.head.rep;
     else o = o + "???";
     l = l.tail;
   }
   return o;
 };

 // given a function (f : string -> chunk list) and (l : chunk list)
 // build a new list where each raw chunk within l has f applied to
 // it and the result flattened. edit chunks are not modified.
 function puRawMapConcat(f, l) {
   if (l == undefined) return l;
   if (l.head.israw) {
     var nl = f(l.head.text);
     return puAppend(nl, puRawMapConcat(f, l.tail));
   } else return puCons(l.head, puRawMapConcat(f, l.tail));
 };

 function puAppend (l1, l2) {
   if (l1 == undefined) return l2;
   else return puCons(l1.head, puAppend(l1.tail, l2));
 };

 // lists are represented as head/tail cons cells
 // with nil = undefined
 function puCons(h, t) {
   // if they are both raw, then flatten.
   if (t != undefined && t.head.israw && h.israw) {
     var nh = new Object();
     nh.israw = true;
     nh.text = h.text + t.head.text;
     var o = new Object;
     o.head = nh;
     o.tail = t.tail;
     return o;
   } else {
     var o = new Object();
     o.head = h;
     o.tail = t;
     return o;
   }
 }

 function puRaw(s) {
   var o = new Object();
   o.israw = true;
   o.text = s;
   return o;
 };

 // puCleave(small, large)
 // find the next match of small in large.
 // return a two-element array of the
 // string preceding the match, and the string
 // following the match. If there are no matches,
 // return undefined.
 function puCleave(small, large) {
 //   alert("puCleave(" + small + ", " + large + ")");
   for(var i = 0; i < large.length; i ++) {
      if (large.substr(i, small.length) == small) {
         /* match! */
 //         alert("match@ " + i);
         return new Array(large.substr(0, i),
                          large.substring(i + small.length));
      }
   }
   return undefined;
 };

 function puBorn(edits) {
  return puRawMapConcat(puSpellRep("(b. ", "(born ", puBORN), edits);
 };

 function puXhtml(edits) {
  return puRawMapConcat(puSpellRep("<br>", "<br/>", puXHTML), edits);
 };

 function puSpell(edits) {
  edits = puRawMapConcat(puSpellRep("seperat", "separat", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("embarass", "embarrass", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("existance", "existence", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("supercede", "supersede", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("accomodat", "accommodat", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("foreward", "foreword", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("liason", "liaison", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("occassion", "occasion", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("occurrance", "occurrence", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("privelege", "privilege", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("priviledge", "privilege", puSPELL), edits);
  edits = puRawMapConcat(puSpellRep("withold", "withhold", puSPELL), edits);
  return edits;
 };

 function puSpellRep(src, dst, wh) {
   return (function(t) {
             // spelling is kinda slow, and most misspellings never appear at all
             if (t.indexOf(src) == -1) return puCons(puRaw(t), undefined);
             else return puSpellOne (t, src, dst, wh)
           });
 };

 function puSpellOne (t, src, dst, wh) {
   var a = puCleave(src, t);
   if (a == undefined) return puCons(puRaw(t), undefined);
   var subst = puEdit(src, dst, wh);
   return puCons(puRaw(a[0]), puCons(subst, puSpellOne(a[1], src, dst, wh)));
 };

 function puSplitWhiteEnd(s) {
   for(var i = s.length - 1; i >= 0; i --) {
      if (s.charAt(i) != ' '.charAt(0))
         return new Array(s.substr(0, i + 1), s.substring(i + 1));
   }
   // all whitespace!
   return new Array("", s);
 };

 function puSplitWhiteStart(s) {
   for(var i = 0; i < s.length; i ++) {
     if (s.charAt(i) != ' '.charAt(0))
        return new Array(s.substr(0, i), s.substring(i));
   }
   return new Array(s, "");
 };

 // XXX allow decimal places
 function puNumberEnd(s) {
   var n = "";
   for(var i = s.length - 1; i >= 0; i --) {
      if ((s.charCodeAt(i) >= '0'.charCodeAt(0) &&
           s.charCodeAt(i) <= '9'.charCodeAt(0)) ||
           s.charAt(i) == '-')
         n = s.charAt(i) + n;
      // years are often linked
      else if (s.charAt(i) == '[' || s.charAt(i) == ']')
         /* nothing */ ;
      else return n;
   }
   return n;
 };

 // XXX now just takes the next token up to whitespace, ignoring [[brackets]]
 function puNumberStart(s) {
   var n = "";
   for(var i = 0; i < s.length; i ++) {
      if (s.charAt(i) == '[' || s.charAt(i) == ']')
         /* nothing */ ;
      else if (s.charAt(i) != ' ' && s.charAt(i) != '\n')
         n = n + s.charAt(i);
      else return n;
   }
   return n;
 };

 function puEnDash (t) {
   // split on every dash
   var a = puCleave("-", t);
   if (a == undefined) return puCons(puRaw(t), undefined);
 
   // check if dash is preceded by a number and followed by
   // a number.
 
   var bef = puSplitWhiteEnd(a[0]);
   var aft = puSplitWhiteStart(a[1]);
 
   var befn = puNumberEnd(bef[0]);
   var aftn = puNumberStart(aft[1]);
    
   // alert("[" + bef[0] + "][" + bef[1] + "]-[" + aft[0] + "][" + aft[1] + "] .. [" + befn + "]?[" + aftn + "]");

   var befnn = befn * 1;
   var aftnn = aftn * 1;
 
   // exclude ISBNs and certain dates by making sure the number doesn't have dash in it
   if (befn.length > 0 && aftn.length > 0 &&
       puEnDashBefOK(befn) && puEnDashAftOK(aftn) &&
       // ranges are usually lo-hi, but sometimes we see 1987-8
       (isNaN(befnn) || isNaN(aftnn) || befnn <= aftnn
        || (befnn >= 1000 && befnn <= 9999 && aftn <= 99) )) {
     // src has whitespace around dash, replacement does not
     // (note unicode en dash)
     return puCons(puRaw(bef[0]), puCons(puEdit(bef[1] + "-" + aft[0], "?", puENDASH), puEnDash(aft[1])));
   } else {
     // don't match. but if we found dashes to the right, we shouldn't look at those
     // again. (e.g. in ISBN 01-1234-6789, once we look at the first dash and reject it,
     // we don't want to then consider 1234-6789, which looks like a match.)
     var skip = puEnSkip(aft[1]);
     return puCons(puRaw(a[0] + "-" + aft[0] + skip[0]), puEnDash(skip[1]));
   }
 };

 // not in urls!
 function puEnDashBefOK(s) {
   return (s.indexOf('-') == -1 && s.indexOf('http') == -1);
 };

 function puEnDashAftOK(s) {
   // some prefix has to be a number...
   if (s.charCodeAt(0) >= '0'.charCodeAt(0) && s.charCodeAt(0) <= '9'.charCodeAt(0)) {
      // but we should avoid certain stuff...
      return (s.indexOf('-') == -1 && s.indexOf('.htm') == -1 && s.indexOf('.stm') == -1);
   } else {
      // otherwise something special:
      var ss = s.toLowerCase();
      return (
       puStartswith(ss, "january") ||
       puStartswith(ss, "february") ||
       puStartswith(ss, "march") ||
       puStartswith(ss, "april") ||
       puStartswith(ss, "may") ||
       puStartswith(ss, "june") ||
       puStartswith(ss, "july") ||
       puStartswith(ss, "august") ||
       puStartswith(ss, "september") ||
       puStartswith(ss, "october") ||
       puStartswith(ss, "november") ||
       puStartswith(ss, "december") ||
       puStartswith(ss, "today") ||
       puStartswith(ss, "present"));
   }
 };

 function puStartswith(lng, sht) {
    return (lng.indexOf(sht) == 0);
 };

 // after not matching a dash for en dash replacement,
 // split a string into two parts: the first is what we
 // should skip, the rest is what we should look for
 // more dashes within.
 function puEnSkip(s) {
   for(var i = 0; i < s.length; i ++) {
      if ((s.charCodeAt(i) >= '0'.charCodeAt(0) &&
           s.charCodeAt(i) <= '9'.charCodeAt(0)) ||
           s.charAt(i) == '-' ||
           s.charAt(i) == '[' ||
           s.charAt(i) == ']')
        /* nothing */ ;
      else return new Array(s.substr(0, i), s.substring(i));
   }
   return new Array(s, "");
 };

 function puEdit(src, dst, what) {
     var subst = new Object();
     subst.orig = src;
     subst.rep = dst;
     subst.israw = false;
     subst.what = what;
     subst.hidden = false;
     //     alert (src + "&rarr;" + dst);
     punctuationID ++;
     subst.id = punctuationID;
     return subst;
 };

 /* Fix faux em dashes.
    "--"  almost anywhere should almost always be a real em dash (unless there are four or as
          part of an html comment)
    " - " between words should usually be an em dash.
 */
 function puEmDash(t) {
   var a = puCleave("--", t);
   if (a == undefined) return puCons(puRaw(t), undefined);
 
   // must be preceded by a word and followed by a word 
   var bef = puSplitWhiteEnd(a[0]);
   var aft = puSplitWhiteStart(a[1]);
    
   if (aft[1].length > 0 && puEmOKChar(aft[1].charAt(0)) &&
       bef[0].length > 0 && puEmOKChar(bef[0].charAt(bef[0].length - 1))) {
     return puCons(puRaw(bef[0]), 
                   puCons(puEdit(bef[1] + "--" + aft[0], "?", puEMDASH),
                          puEmDash(aft[1])));
   } else {
     /* not an em dash. */
     return puCons(puRaw(a[0] + "--"), puEmDash(a[1]));
   }
 };

 function puEmOKChar(c) {
   //   alert ("check char: [" + c + "]");
   if (c == '>' || c == '!' || c == '<' || c == '-' || c == '|') return false;
   else return true;
 };

 function puIsDigit(c) {
    return (c.charCodeAt(0) >= '0'.charCodeAt(0) && c.charCodeAt(0) <= '9'.charCodeAt(0));
 };

 // 1980's to 1980s ([[Wikipedia:Manual of Style (dates and numbers)]])
 // note this isn't always a mistake:
 // "1981 was a cold year compared to 1980's record temperatures" would be okay
 // so some context awareness is appropriate (but it is almost always wrong)
 function puDecade(t) {
   var a = puCleave("0's", t);
   if (a == undefined) return puCons(puRaw(t), undefined);
 
   if (// date before? (only do it for 4 digit dates)
       (a[0].length >= 4 && 
        puIsDigit(a[0].charAt(a[0].length - 1)) &&
        puIsDigit(a[0].charAt(a[0].length - 2)) &&
        puIsDigit(a[0].charAt(a[0].length - 3)) &&
       !puIsDigit(a[0].charAt(a[0].length - 4))) &&

       // safe to correct?
       a[1].length > 0 && puDecadeOKChar(a[1].charAt(0))) {
 
     return puCons(puRaw(a[0]), 
                   puCons(puEdit("0's", "0s", puDECADE),
                          puDecade(a[1])));
   } else {
     /* no problem. */
     return puCons(puRaw(a[0] + "0's"), puDecade(a[1]));
   }
 };

 function puDecadeOKChar(c) {
   // should be the end of a word
   if (c == '\n' || c == ' ' || c == ',' || c == '.' ||
       c == '&' || c == '?' || c == '-' || c == '?' ||
       // text in tables?
       c == '|' || c == '\t' || c == '<' || c == ')' ||
       c == ';' || c == '!' || c == "'" || c == ':' ||
       c == '/' 
       ) return true;
   else return false;
 };

function puRefPuncChar(c) {
  return (c == '.' || c == ';' || c == ',' || c == '?' ||
	  c == '!' || c == ':');
}

 // space before/around(parentheses )
 // closing parens are basically the same as commas below.
 function puParen(t) {
   var a = puCleave(")", t);
   if (a == undefined) return puCons(puRaw(t), undefined);
 
   // must be preceded by a word and followed by a word 
   var bef = puSplitWhiteEnd(a[0]);
   var aft = puSplitWhiteStart(a[1]);
 
   // alert('paren: [' + bef[0] + '][' + bef[1] + ']***[' + aft[0] + '][' + aft[1] + ']');
     
   if (// needs correction?
       (bef[1].length > 0 || aft[0].length == 0) &&
       // safe to correct?
       aft[1].length > 0 && puRParenOKChar(aft[1].charAt(0)) &&
       bef[0].length > 0 && puRParenOKChar(bef[0].charAt(bef[0].length - 1))) {

     return puCons(puRaw(bef[0]), 
                   puCons(puEdit(bef[1] + ")" + aft[0], ") ", puPAREN),
                          puParen(aft[1])));
   } else {
     /* no problem. */
     return puCons(puRaw(a[0] + ")"), puParen(a[1]));
   }
 };

 // XXX perhaps should be okay-on-right and okay-on-left; this may be too conservative
 function puRParenOKChar(c) {
   if (c == ")" || c == "(" || c == '|' ||
       // otherwise we undo our linkspace fix ;)
       c == ']' ||
       // title markup
       c == '=' ||
       // sometimes people do &nbsp;
       c == '&' ||
       // quotes, obviously
       c == '"' || c == '?' || c == '?' || c == "'" ||
       // History of Russia (1900-1950)#World War II
       c == "#" ||
       // other stuff
       c == '\n' || c == ':' || c == ';' || c == '.' || c == '-' || c == '?' || c == ',' || 
       c == '}' || '{' || c == '<') return false;
   else return true;
 };

 // TODO: very important to filter out URL hits, since comma appears in lots of news URLs
 function puComma(t) {
   var a = puCleave(",", t);
   if (a == undefined) return puCons(puRaw(t), undefined);
 
   // must be preceded by a word and followed by a word 
   var bef = puSplitWhiteEnd(a[0]);
   var aft = puSplitWhiteStart(a[1]);
 
   // alert('comma: [' + bef[0] + '][' + bef[1] + ']***[' + aft[0] + '][' + aft[1] + ']');
     
   if (// needs correction?
       (bef[1].length > 0 || aft[0].length == 0) &&
       // safe to correct?
       aft[1].length > 0 && puCommaOKChar(aft[1].charAt(0)) &&
       bef[0].length > 0 && puCommaOKChar(bef[0].charAt(bef[0].length - 1))) {
     // alert('fix!');
     return puCons(puRaw(bef[0]), 
                   puCons(puEdit(bef[1] + "," + aft[0], ", ", puCOMMA),
                          puComma(aft[1])));
   } else {
     /* no problem. */
     return puCons(puRaw(a[0] + ","), puComma(a[1]));
   }
 };

 function puLinkSpace(t) {
   var a = puCleave(" ]]", t);
   if (a == undefined) return puCons(puRaw(t), undefined);
 
   // maybe multiple spaces...
   var bef = puSplitWhiteEnd(a[0]);
 
   // alert('linkspace: [' + bef[0] + '][' + bef[1] + ']***[' + aft[0] + '][' + aft[1] + ']');
 
   // filter out the common idiom <nowiki>[[Category:United States| ]]</nowiki>
   if (a[0].length > 0 && a[0].charAt(a[0].length - 1) != '|') {
     return puCons(puRaw(bef[0]), 
                   puCons(puEdit(bef[1] + " ]]", "]]", puLINKSPACE),
                          puLinkSpace(a[1])));
   } else {
     return puCons(puRaw(a[0] + " ]]"), puLinkSpace(a[1]));
   }
 };

 /// XXX not hooked up -- did I finish implementing this?
 // between number and %, remove space.
 function puPercent(t) {
   var a = puCleave("%", t);
   if (a == undefined) return puCons(puRaw(t), undefined);
 
   // must be preceded by a word and followed by a word 
   var bef = puSplitWhiteEnd(a[0]);
   var aft = puSplitWhiteStart(a[1]);
 
   // alert('pct: [' + bef[0] + '][' + bef[1] + ']***[' + aft[0] + '][' + aft[1] + ']');
     
   if (// needs correction?
       (bef[1].length > 0 || aft[0].length == 0) &&
       // safe to correct?
       aft[1].length > 0 && puPercentBeforeChar(aft[1].charAt(0)) &&
       bef[0].length > 0 && puPercentAfterChar(bef[0].charAt(bef[0].length - 1))) {
     // alert('fix!');
     return puCons(puRaw(bef[0]), 
                   puCons(puEdit(bef[1] + "%" + aft[0], "% ", puPERCENT),
                          puPercent(aft[1])));
   } else {
     /* no problem. */
     return puCons(puRaw(a[0] + "%"), puPercent(a[1]));
   }
 };

 function puCommaOKChar(c) {
   // definitely not inside numbers
   if ((c.charCodeAt(0) >= '0'.charCodeAt(0) && c.charCodeAt(0) <= '9'.charCodeAt(0)) ||
       // text in tables?
       c == '|' ||
       // quotes, obviously
       c == '"' || c == '?' || c == '?' || c == "'" ||
       c == '\n' || c == '&' || c == ',' || 
       // ref tags
       c == '{' || c == '<') return false;
   else return true;
 };


 // for references, we want to find the ref tags, but
 // they can appear in several common forms:
 // <ref>...</ref>
 // <ref name="first">...</ref>
 // <ref name="reused" />
 // this function returns a three-element array consisting of
 // [the text before the first ref tag, the ref tag, the text following]
 // (or it returns undefined if there are no ref tags to be found)
 function puGetRef(t) {
   var m = '<ref';
   for(var i = 0; i < t.length; i ++) {
     if (t.substr(i, m.length) == m) {
       // now, decide what kind of ref
       // appearance this is. keep looking
       // at characters until we see 
       // > (bracketing)
       // or
       // /> (unitary)
       for(var j = i + m.length; j < t.length; j ++) {
         if (t.charAt(j) == '/') {
           
         } else if (t.charAt(j) == '>') {
           // found bracketing ref tag.
           // so now eat until </ref> is
           // encountered.
           var rest = t.substr(j + 1, t.length - (j + 1));

           var a = puCleave('</ref>', rest);
           if (a == undefined) {
             // XXX warn: unclosed ref tag??
             return undefined;
           }

           var rt = t.substr(i, j - i) + a[0] + '</ref>';
           var bef = t.substr(0, i);
           var aft = a[1];
           alert("REF. bef: [" + bef + "]\n" +
                 "rt: [" + rt + "]\n" +
                 "aft: [" + aft + "]\n");
           return undefined;
         }
       }
     }
   }
   // none found...
   return undefined;
 };


 function puRef(t) {
   // XXX unimplemented
   puGetRef(t);

   return puCons(puRaw(t), undefined);
 };

 // install it..
 addOnloadHook(function() {
  // not on talk pages...
  if (document.title.indexOf("talk:") != -1) {
     return;
  }
  if (document.title.indexOf("Editing ") != -1) {
  addOnloadHook(addPunctuation);
  }
 });

 function addPunctuation() {
   // need to see later if user has done any editing...
   punctuationPageOriginalSummary = document.editform.wpSummary.value;
   addTab("javascript:doPunctuation()", "punctuation", "ca-punctuation", "Punctuation", "");
   akeytt();
 };
