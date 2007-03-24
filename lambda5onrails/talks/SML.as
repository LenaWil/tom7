
/* XXXX need to support comment colors! */
import flash.geom.*;

class SML extends MovieClip {

  var tightness : Number = 0.57;
  var xheight : Number = 1.0;
  var xheightstretch : Number = 1.58;

  var lastframe    : Number = -1;
  var deletelist   : Array = [];

  var defaultcolor : ColorTransform = undefined;
  var keywordcolor : ColorTransform = undefined;
  var emphcolor    : ColorTransform = undefined;
  var capcolor     : ColorTransform = undefined;
  var punctcolor   : ColorTransform = undefined;
  var stringcolor  : ColorTransform = undefined;

  var extracolor1  : ColorTransform = undefined;
  var extracolor2  : ColorTransform = undefined;

  /* XXX wrong for non-US letters */
  public function is_separator(c) {
    if (c >= 65 && c <= 90 ||
	c >= 97 && c <= 122) return false;
    else return true;
  }

  public function is_punctuation(c) {
    return (is_separator(c));
  }

  /* substitutions, etc... */

  /* at least one of src or dest must be non-empty */
  public function string_replace(s, src, dst) {
    var t = s;
    for(var i = 0; i < (t.length - src.length); ) {
      if(t.substr(i, src.length) == src) {
	t = t.substr(0, i) + dst + t.slice(i + src.length, t.length);
	/* skip destination string */
	i = i + dst.length;
      } else {
	i ++;
      }
    }
    return t;
  }

  public function substitute(s) {
    // var re = new RegExp("[>][=]");
    // s.replace(">=", String.fromCharCode(8805));

    /* math lessthan, etc */
    // 25CB: Cir
    s = string_replace(s, ">=", String.fromCharCode(8805));
    s = string_replace(s, "<=", String.fromCharCode(8804));
    s = string_replace(s, "'a", String.fromCharCode(945));
    s = string_replace(s, "'b", String.fromCharCode(946));
    s = string_replace(s, "'c", String.fromCharCode(947));
    s = string_replace(s, "[]", String.fromCharCode(9633));
    /* maybe interferes with empty record */
    s = string_replace(s, "{}", String.fromCharCode(9752));
    /* maybe interferes with SML not-equal operator */
    s = string_replace(s, "<>", String.fromCharCode(9671));

    s = string_replace(s, "->", String.fromCharCode(8594));
    s = string_replace(s, "=>", String.fromCharCode(8658));

    return s;
  }

  public function isemph(s) {
    return (s == "spawn" ||
	    s == "join" ||
	    s == "wait" ||
	    s == "waitall" ||
	    s == "sync" ||
	    s == "syncall" ||
	    s == "submit");
  }

  public function iskeyword(s) {
    return (s == "from" ||
	    s == "extern" ||
	    s == "mobile" ||
	    s == "world" ||
	    s == "valid" ||
	    s == "select" ||
	    s == "into" ||
	    s == "insert" ||
	    s == "put" ||
	    s == "localhost" ||
	    s == "get" ||
	    s == "fn" ||
	    s == "if" ||
	    s == "then" ||
	    s == "else" ||
	    s == "fun" ||
	    s == "let" ||
	    s == "in" ||
	    s == "val" ||
	    s == "type" ||

	    s == "end");
  }

  public function is_capital(c) {
    return (c >= 65 && c <= 90);
  }

  public function drawtext(clip, s, x, y) {
    // trace(s);
    s = substitute(s);
    var stringmode = false;
    var extra : Number = 0;

    var cx = x;
    /* registration in bottom left */
    var cy = y + xheight;
    var clr = defaultcolor;

    /* single-character properties hold tab stops
       (x coordinates) */
    var tabs = new Object();

    for(var i = 0; i < s.length; i ++) {
      var code : Number = s.charCodeAt(i);
      /* override other color choices */

      /* non breaking space or something? */
      if (code == 160) code = 32;
      if (code == 10) code = 13;
      if (code == 13) {
	/* newline */
	// could get from "letter_88"? 
	cy += xheight;
	cx = x;

	continue;

      } else if (code == 34) {
	/* string mode */
	stringmode = !stringmode;
	// trace("string time! " + stringmode);

	/* backslash for escapes */
      } else if (code == 92) {

	/* trailing backslash ignored */
	if (i == (s.length - 1)) break;

	i ++;
	/* Gamma */
	if (s.charCodeAt(i) == "G".charCodeAt(0)) code = 915;
	/* vdash */
	else if (s.charCodeAt(i) == "v".charCodeAt(0)) code = 8866;

	else if (s.charCodeAt(i) == "@".charCodeAt(0)) {
	  i ++;
	  if (i == (s.length - 1)) break;
	  /* set tab stop */
	  tabs[s.charAt(i)] = cx;
	  continue;
	}

	else if (s.charCodeAt(i) == ">".charCodeAt(0)) {
	  i ++;
	  if (i == (s.length - 1)) break;
	  /* go to tab stop */
	  cx = tabs[s.charAt(i)];
	  continue;
	}
	
	/* override with client/server color */
	else if (s.charCodeAt(i) == "c".charCodeAt(0)) {
	  extra = 1;
	  continue;
	} else if (s.charCodeAt(i) == "s".charCodeAt(0)) {
	  extra = 2;
	  continue;
	}
	
	else if (s.charCodeAt(i) == ")".charCodeAt(0)) {
	  extra = 0;
	  continue;
	}

      } 
	
      var d = clip.getNextHighestDepth();
      // trace("letter_" + code + " ...  " + d);
      var m = clip.attachMovie("letter_" + code, "l" + d,
			       d, {_x : cx, _y : cy});

      deletelist.push(m);

      /* apply style */
      if (m == undefined) {
	trace("oops: " + code);
      }
	
      if (i == 0 || 
	  /* space, nbspace, or newline? */
	  is_separator(s.charCodeAt(i - 1)) ||
	  is_separator(s.charCodeAt(i))) {
	  
	/* beginning of word. check if it's a keyword */
	var w = "";
	var j = i;
	while (j < s.length && 
	       !is_separator(s.charCodeAt(j))) {
	  w = w + s.charAt(j);
	  j ++;
	}

	if (iskeyword(w)) {
	  clr = keywordcolor;
	} else if (isemph(w)) {
	  clr = emphcolor;
	} else if (is_capital(code)) {
	  clr = capcolor;
	} else if (is_punctuation(code)) { 
	  clr = punctcolor;
	} else {
	  clr = defaultcolor; 
	}
      }

      /* override because in string */
      if (stringmode || code == 34) clr = stringcolor;

      /* override extra */
      if (extra == 1) clr = extracolor1;
      if (extra == 2) clr = extracolor2;

      if (clr != undefined) {
	m.transform.colorTransform = clr;
      }

      /* XXX kerning... */
      if (m != undefined)
	cx += (m._width * tightness);
    }
  }

  public function onLoad() {

    /* don't lookat me. */
    this._visible = false;

    var x = this.attachMovie("letter_88", "deleteme",
			     this.getNextHighestDepth());
    
    xheight = x._height * xheightstretch;
    x._visible = false;

    /* XXX detach it too */

    /*
      var clr = new ColorTransform(0,0,0,0,0,0,0,0);
      clr.alphaOffset = 255;
      clr.redOffset = 255;
      m.transform.colorTransform = clr;
    */

    defaultcolor = new ColorTransform(0,0,0,0,0,0,0,0);
    defaultcolor.alphaMultiplier = 1.0;
    defaultcolor.rgb = 0xB3BED7;

    keywordcolor = new ColorTransform(0,0,0,0,0,0,0,0);
    keywordcolor.alphaMultiplier = 1.0;
    keywordcolor.rgb = 0xECFF60; // 0xE0E7A0;

    emphcolor = new ColorTransform(0,0,0,0,0,0,0,0);
    emphcolor.alphaMultiplier = 1.0;
    emphcolor.rgb = 0x5CABF8;

    capcolor = new ColorTransform(0,0,0,0,0,0,0,0);
    capcolor.alphaMultiplier = 1.0;
    capcolor.rgb = 0x95A7EA;

    punctcolor = new ColorTransform(0,0,0,0,0,0,0,0);
    punctcolor.alphaMultiplier = 0.8;
    punctcolor.rgb = 0x939FAA;

    stringcolor = new ColorTransform(0,0,0,0,0,0,0,0);
    stringcolor.alphaMultiplier = 1.0;
    stringcolor.rgb = 0x9FF0A9;
    
    extracolor1 = new ColorTransform(0,0,0,0,0,0,0,0);
    extracolor1.alphaMultiplier = 1.0;
    extracolor1.rgb = 0xF90000;

    extracolor2 = new ColorTransform(0,0,0,0,0,0,0,0);
    extracolor2.alphaMultiplier = 1.0;
    extracolor2.rgb = 0x00F91F;

    //      drawstring("awesome");

  }

  public function onEnterFrame() {
    /* look for textareas to rewrite.
       
       PERF should avoid looking every frame!
    */
    if (_root._currentFrame != lastframe) {
      lastframe = _root._currentFrame;

      /* delete anything we've added... */
      for(var i = 0; i < deletelist.length; i ++) {
	deletelist[i].removeMovieClip();
      }

      deletelist = [];

      for (var o in _root) {
	if (_root[o].text != undefined && 
	    _root[o]._visible &&
	    o.substr(0, 3) == "SML") {
	  /* then it's a text area. */
	  /* make sure it doesn't show as-is, and that we don't
	     try to rewrite it again */
	  _root[o]._visible = false;

	  drawtext(_root, _root[o].text, _root[o]._x, _root[o]._y);
	}
      }
    }
  }

}
