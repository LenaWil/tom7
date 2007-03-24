/* This object automatically rewrites any dynamic text on
   the toplevel whose instance name starts with "instance"
   (the default in the flash editor for blank instance
   names) to apply markup that is more convenient to type
   than html codes. */

import flash.geom.*;
import TextField.StyleSheet;

class Markup extends MovieClip {

  var lastframe    : Number = -1;
  var styles;


  /* substitutions, etc... */

  /* PERF */
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
  
  /* turns strings s of the form
     'aaaaa[src]bbbbb[src]ccccc'
     into
     'aaaaa[sdst]bbbbb[edst]ccccc' */
  public function string_replace_repeats(s, src, sdst, edst) {
    var t = s;
    var parity = false;
    for(var i = 0; i < (t.length - src.length); ) {
      if(t.substr(i, src.length) == src) {
	var rep = parity?edst:sdst;
	t = t.substr(0, i) + rep + t.slice(i + src.length, t.length);
	/* skip destination string */
	i = i + rep.length;
	parity = !parity;
      } else {
	i ++;
      }
    }
    return t;
  }

  public function string_replace_pair(s, src1, src2, dst1, dst2) {
    var t = s;
    var parity = false;
    for(var i = 0; i < (t.length - (parity?src2:src1).length); ) {
      var src = parity?src2:src1;
      if(t.substr(i, src.length) == src) {
	var rep = parity?dst2:dst1;
	t = t.substr(0, i) + rep + t.slice(i + src.length, t.length);
	/* skip destination string */
	i = i + rep.length;
	parity = !parity;
      } else {
	i ++;
      }
    }
    return t;
  }

  public function rewritehtml(t : TextField) {
    // t.styleSheet = styles;
    var s = t.text;
    /* stress */
    s = string_replace(s, "[[", '<font color="#FFFFFF">');
    s = string_replace(s, "]]", '</font>');
    /* def'n */
    s = string_replace(s, "[=", '<font color="#EDF900">');
    s = string_replace(s, "=]", '</font>');
    /* italic (XXX embedding issues) */
    // s = string_replace(s, "[/", '<i>');
    // s = string_replace(s, "/]", '</i>');

    /* ['vars'] */
    s = string_replace_repeats(s, "`",
			       '<font color="#A3A9ED">',
			       '</font>');

    /* bullets */
    s = string_replace_pair(s, "[...]", String.fromCharCode(13),
			    '<textformat leftmargin="90" indent="-30"><font color="#777777">' + String.fromCharCode(183) + '</font><font size="-9">',
			    '</font></textformat><br/>');
    s = string_replace_pair(s, "[..]", String.fromCharCode(13),
			    '<textformat leftmargin="60" indent="-30"><font color="#AAAAAA">' + String.fromCharCode(183) + '</font><font size="-6">',
			    '</font></textformat><br/>');
    s = string_replace_pair(s, "[.]", String.fromCharCode(13),
			    '<textformat leftmargin="30" indent="-30"><font color="#FFFFFF">' + String.fromCharCode(183) + '</font> ', 
			    '</textformat><br/>');
    t.htmlText = s;
    // trace(s);
  }

  public function onLoad() {

    /* don't lookat me. */
    this._visible = false;

    //    styles = new StyleSheet();
    // if (!styles.parseCSS(".test { color : #FF0000; } .one { margin-left : 10px }")) trace("oops can't parse CSS");
    
    /* try to do this as often as possible */
    onEnterFrame();

  }

  public function onEnterFrame() {
    /* look for textareas to rewrite, if this
       isn't the frame we looked at last time */
    if (_root._currentFrame != lastframe) {
      lastframe = _root._currentFrame;

      for (var o in _root) {
	if (_root[o].rewrote_markup == undefined &&
	    _root[o].html && 
	    _root[o]._visible &&
	    o.substr(0, 8) == "instance") {
	  /* then it's a text area. */
	  // _root[o]._alpha = 50;

	  rewritehtml(_root[o]);
	  _root[o].rewrote_markup = true;
	}
      }
    }
  }

}
