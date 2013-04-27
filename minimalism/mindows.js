// TODO: Make mouse cursor invisible when it is outside the OS.
// TODO: Cursor doesn't work on mobile safari, but probably could.
// TODO: Minimize
// TODO: Maximize button switches to "restore" when maximized.
// TODO: Menus?

// Mouse position within the OS.
var mousex = 320, mousey = 200;

// Element containing the OS instance.
var os = null;

// Element used for the mouse cursor.
var mouse = null;
var mousestate = 'mouse.png';
// If non-null, the mouse is captured by some
// action, like dragging or resizing.
var capture = null;

// Element used for debugging.
var deb = null;

// List of windows from back to front.
var windows = [];

// Traverse windows from front to back to find
// out what the mouse is pointing at, if anything.
function getPointed() {
  for (var i = windows.length - 1; i >= 0; i--) {
    var win = windows[i];
    if (!win) throw ('win ' + i);
    var inside = win.inside(mousex, mousey);
    if (inside) {
      return inside;
    }
  }

  return null;
}

function osblur() {
  for (var i = 0; i < windows.length; i++) {
    windows[i].blur();
  }
}

function osmousemove(e) {
  var obj = getmouseposwithin(e, os);
  mousex = obj.x;
  mousey = obj.y;

  // Do actions if captured. This is also responsible for
  // setting the mouse state (cursor shape) in that case.
  if (capture) {
    var ins = capture.inside;
    switch (capture.what) {
      case 'press':
        var onit = mousex >= ins.x && mousey > ins.y &&
	  mousex < ins.x + ins.w && mousey < ins.y + ins.h;
        if (ins.down) {
          var newsrc = onit ? ins.down : ins.up;
          if (ins.elt.src != newsrc) {
	    ins.elt.src = newsrc;
	    deb.innerHTML = 'set src to ' + newsrc;
	  }
	}
        break;
      case 'move':
        // This can only be title, currently.
        ins.win.moveto(mousex - ins.gripx, mousey - ins.gripy);
        ins.win.redraw();
        break;
      case 'resize':
	switch (ins.which) {
	  case 'se':
	    mousestate = 'mouse-resize-backslash.png';
	    ins.win.resizeright(mousex - ins.win.x - ins.gripx);
	    ins.win.resizedown(mousey - ins.win.y - ins.gripy);
	    ins.win.redraw();
            break;
	  case 'sw':
	    mousestate = 'mouse-resize-slash.png';
	    ins.win.resizeleft(mousex - ins.gripx);
	    ins.win.resizedown(mousey - ins.win.y - ins.gripy);
	    ins.win.redraw();
            break;
	  case 'nw':
	    mousestate = 'mouse-resize-backslash.png';
	    ins.win.resizeleft(mousex - ins.gripx);
	    ins.win.resizeup(mousey - ins.gripy);
	    ins.win.redraw();
            break;
	  case 'ne':
	    mousestate = 'mouse-resize-slash.png';
	    ins.win.resizeright(mousex - ins.win.x - ins.gripx);
	    ins.win.resizeup(mousey - ins.gripy);
	    ins.win.redraw();
            break;

	  // XXX others!
	  default:;
	}
        break;
      default:;
    }

  } else {
    // Otherwise, mouse state is determined by the position
    // of the mouse.
    
    // Figure out any mouse state changes.
    var inside = getPointed();
    if (inside) {
      switch (inside.what) {
	case 'corner':
	  if (inside.which == 'se' || inside.which == 'nw') {
	    mousestate = 'mouse-resize-backslash.png';
	  } else {
	    mousestate = 'mouse-resize-slash.png';
	  }
	  break;
	default:
	case 'title':
	case 'button':
	case 'win':
	  mousestate = 'mouse.png';
      }
    } else {
      mousestate = 'mouse.png';
    }

  }

  redrawmouse();
}

function osmousedown(e) {
  e = e || window.event;
  osblur();
  var inside = getPointed();
  if (inside) {
    switch (inside.what) {
      case 'menu':
        inside.win.movetofront();
        deb.innerHTML = inside.which.text;
        inside.menu.selected = inside.which;
        redrawos();
        break;
      case 'button':
        capture = { what: 'press', inside: inside };
        osmousemove(e);
        break;
      case 'corner':
        capture = { what: 'resize', inside: inside };
        break;
      case 'title':
        capture = { what: 'move', inside: inside };
        inside.win.movetofront();
        redrawos();
        break;
      case 'win':
        // XXX make active.
        inside.win.movetofront();
        redrawos();
        break;
      default:;
    }
  } else {
    // Clicks on background -- nothing?
  }

}

function osmouseup(e) {
  e = e || window.event;

  if (capture) {
    var ins = capture.inside;
    switch (capture.what) {
    case 'press':
      if (ins.up) {
	ins.elt.src = ins.up;
	deb.innerHTML = ('src up: ' + ins.up);
      }
      var onit = mousex >= ins.x && mousey > ins.y &&
	  mousex < ins.x + ins.w && mousey < ins.y + ins.h;
      if (onit && ins.action) {
	// Do the action.
	ins.action(ins);
      }
      break;
    }
  }

  capture = null;
}

function redrawmouse() {
  if (mouse.src != mousestate) {
    mouse.src = mousestate;
  }

  mouse.style.top = px(mousey);
  mouse.style.left = px(mousex);
  // XXX set cursor style.

/*  
  deb.innerHTML = '';
  TEXT(mousex + ' ' + mousey + ' / ' +
       os.offsetTop, deb);
*/
}

function initos(elt) {
  os = elt;

  os.onmousemove = osmousemove;
  os.onmousedown = osmousedown;
  os.onmouseup = osmouseup;

  mouse = IMG('mouse', os);
  mouse.src = 'mouse.png';
  redrawmouse();
  redrawos();
}

// XXX to OS object?
function redrawos() {
  for (var i = 0; i < windows.length; i++) {
    windows[i].div.style.zIndex = WINDOWZ + i;
    windows[i].redraw();
  }
}

var CHARS = [];
(function() {
  for (var i = 0; i < FONTCHARS.length; i++) {
    var c = FONTCHARS.charCodeAt(i);
    if (c >= 0 && c < 128) {
      CHARS[c] = i;
    }
  }
})();

function rendertext(text, elt, font) {
  for (var i = 0; i < text.length; i++) {
    var c = text.charCodeAt(i);
    if (c >= 0 && c < 128) {
      var d = DIV('ch', elt);
      d.style.cssFloat = 'left';
      d.style.width = px(FONTW);
      d.style.height = px(FONTH);
      d.style.marginLeft = '-' + FONTOVERLAP + 'px';
      d.style.backgroundImage = 'url(' + font + '.png)';
      d.style.backgroundPosition = (CHARS[c] * -FONTW) + 'px 0px';
    }
  }
}

function Win(x, y, w, h, title) {
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;
  this.title = title || '';

  // TODO: "modal"

  this.div = DIV('win', os);
  windows.push(this);

  this.redraw();
}

Win.prototype.blur = function() {
  if (this.menu) {
    this.menu.selected = null;
    // TODO: Undo popouts too.
  }
}

Win.prototype.maximizetoolx = function() {
  return this.w - TOOL - BORDER + 1;
}

Win.prototype.minimizetoolx = function() {
  return this.w - (TOOL * 2) - BORDER + 1 + 1;
}

Win.prototype.domaximize = function() {
  this.x = 0;
  this.y = 0;
  this.w = OSWIDTH;
  this.h = OSHEIGHT;
  this.movetofront();
  redrawos();
}

Win.prototype.inside = function(x, y) {
  var ins = x >= this.x && y >= this.y &&
    x < (this.x + this.w) && y < (this.y + this.h);
  if (!ins) return null;

  // We know we're inside.

  // Check buttons BEFORE corners.
  if (x > this.x + this.maximizetoolx() &&
      x < (this.x + this.maximizetoolx() + TOOL) &&
      y < (this.y + BORDER + TOOL)) {
    return { what: 'button', which: 'maximize', win: this,
	     elt: this.maximize,
	     down: 'maximize-down.png',
	     up: 'maximize.png',
	     x: this.x + this.maximizetoolx(),
	     y: this.y + BORDER,
	     w: TOOL, h: TOOL,
	     action: function(ins) {
	       ins.win.domaximize();
	     } };
  }

  if (x > this.x + this.minimizetoolx() &&
      x < (this.x + this.minimizetoolx() + TOOL) &&
      y < (this.y + BORDER + TOOL)) {
    return { what: 'button', which: 'minimize', win: this,
	     elt: this.minimize,
	     down: 'minimize-down.png',
	     up: 'minimize.png',
	     x: this.x + this.minimizetoolx(),
	     y: this.y + BORDER,
	     w: TOOL, h: TOOL };
  }

  // Corner objects include the name of the corner
  // plus the grip offset, so that we can behave as
  // though the mouse is pointing EXACTLY at the corner
  // during resizing, even though the grabbable area is
  // more than one pixel.
  if (x > (this.x + this.w - CORNER) &&
      y > (this.y + this.h - CORNER)) {
    return { what: 'corner', which: 'se', win: this,
	     gripx: x - (this.x + this.w),
	     gripy: y - (this.y + this.h) };
  } else if (x < (this.x + CORNER) &&
             y > (this.y + this.h - CORNER)) {
    return { what: 'corner', which: 'sw', win: this,
	     gripx: x - this.x,
	     gripy: y - (this.y + this.h) };
  } else if (x < (this.x + CORNER) &&
             y < (this.y + CORNER)) {
    return { what: 'corner', which: 'nw', win: this,
	     gripx: x - this.x,
	     gripy: y - this.y };
  } else if (x > (this.x + this.w - CORNER) &&
             y < (this.y + CORNER)) {
    return { what: 'corner', which: 'ne', win: this,
	     gripx: x - (this.x + this.w),
	     gripy: y - this.y };
  }

  // Check title AFTER corners
  if (y < this.y + TITLE) {
    return { what: 'title', win: this,
	     gripx: x - this.x,
	     gripy: y - this.y };
  }

  // Check menu.
  if (this.menu) {
    for (var i = 0; i < this.menu.length; i++) {
      var met = this.menu[i].metrics;
      if (x >= met.x &&
	  y >= met.y &&
	  x < (met.x + met.w) &&
	  y < (met.y + met.h)) {
	deb.innerHTML = 'over menu';
	return { what: 'menu', win: this,
		 menu: this.menu,
		 which: this.menu[i] };
      }
    }
  }

  return { what: 'win', win: this };
}

// Returns {x, y, w, h} for an Element, where
// 0,0 is the top-left of the OS.
function getosmetrics(elt) {
  var eltr = elt.getBoundingClientRect();
  var osr = os.getBoundingClientRect();
  var x = eltr.left - osr.left;
  var y = eltr.top - osr.top;
  return { x: x,
	   y: y,
	   w: (eltr.right - eltr.left),
	   h: (eltr.bottom - eltr.top) };
}

Win.prototype.movetofront = function() {
  var nwins = [];
  for (var i = 0; i < windows.length; i++) {
    if (windows[i] != this) {
      nwins.push(windows[i]);
    }
  }
  nwins.push(this);
  windows = nwins;
};

// Resize from the top edge without moving the bottom.
Win.prototype.resizeup = function(y) {
  // How much the window "increases" (could be negative increase)
  // in height.
  var growth = this.y - y;
  var newheight = this.h + growth;
  if (newheight < MINHEIGHT) {
    growth += (MINHEIGHT - newheight);
    newheight = MINHEIGHT;
  }
  this.y -= growth;
  this.h += growth;
};

// Resize from the left edge without moving the right.
Win.prototype.resizeleft = function(x) {
  // How much the window "increases" (could be negative increase)
  // in width.
  var growth = this.x - x;
  var newwidth = this.w + growth;
  deb.innerHTML = 'growth: ' + growth + ' nw: ' + newwidth;
  if (newwidth < MINWIDTH) {
    growth += (MINWIDTH - newwidth);
    newwidth = MINWIDTH;
  }
  this.x -= growth;
  this.w += growth;
};

Win.prototype.resizeright = function(w) {
  w = Math.max(w, MINWIDTH);
  this.w = w;
};

Win.prototype.resizedown = function(h) {
  h = Math.max(h, MINHEIGHT);
  this.h = h;
};

Win.prototype.moveto = function(x, y) {
  this.x = x;
  this.y = y;
}

// Assuming the metrics are set (x,y,w,h),
// places the window in the DOM and
// draws its borders.
Win.prototype.redraw = function() {
  var active = windows.length > 0 && 
      this == windows[windows.length - 1];

  var d = this.div;
  d.innerHTML = '';
  d.style.left = this.x + 'px';
  d.style.top = this.y + 'px';
  d.style.width = this.w + 'px';
  d.style.height = this.h + 'px';

  // Add title bar.
  this.titleelt = DIV('title', this.div);
  this.titleelt.style.width = px(this.w);
  this.titleelt.style.height = px(TITLE);
  this.titleelt.style.top = px(BORDER);
  this.titleelt.style.left = 0;
  if (active) {
    this.titleelt.style.background = "url('title.png')";
  } else {
    this.titleelt.style.background = "url('title-inactive.png')";
  }
  this.titleelt.style.backgroundRepeat = 'repeat-x';

  //TEXT(this.title, this.titleelt);
  this.titletext = DIV('titletext', this.titleelt);
  rendertext(this.title, this.titletext, 'fontwhite');

  // Add menu bar.
  if (this.menu) {
    deb.innerHTML = 'there\'s a menu.';
    this.menuelt = DIV('menu', this.div);
    this.menuelt.style.width = px(this.w);
    this.menuelt.style.height = px(MENU);
    this.menuelt.style.left = 0;
    this.menuelt.style.top = px(TITLE + BORDER);

    // Top-level menu items.
    for (var i = 0; i < this.menu.length; i++) {
      var menuitem = DIV('menuitem', this.menuelt);
      this.menu[i].elt = menuitem;
      if (this.menu[i] == this.menu.selected) {
	// Make menuitem selected color.
	menuitem.style.background = BLUE;
	rendertext(this.menu[i].text, menuitem, 'fontwhite');
      } else {
	rendertext(this.menu[i].text, menuitem, 'fontblack');
      }

      // Has to happen after the item has been completely placed.
      var metrics = getosmetrics(menuitem);
      this.menu[i].metrics = metrics;
      /*
      deb.innerHTML = 'x: ' + metrics.x + ' y: ' + metrics.y +
	  ' w: ' + metrics.w + ' h: ' + metrics.h;
      */
    }
  }

  // Add borders and corners.

  this.west = DIV('border', this.div);
  this.west.style.width = px(BORDER);
  this.west.style.height = px(this.h);
  this.west.style.left = 0;
  this.west.style.top = 0;
  this.west.style.background = "url('border-vert.png')";
  this.west.style.backgroundRepeat = 'repeat-y';

  this.east = DIV('border', this.div);
  this.east.style.width = px(BORDER);
  this.east.style.height = px(this.h);
  this.east.style.left = px(this.w - BORDER);
  this.east.style.top = 0;
  this.east.style.background = "url('border-vert.png')";
  this.east.style.backgroundRepeat = 'repeat-y';

  this.north = DIV('border', this.div);
  this.north.style.width = px(this.w);
  this.north.style.height = px(BORDER);
  this.north.style.left = 0;
  this.north.style.top = 0;
  this.north.style.background = "url('border-horiz.png')";
  this.north.style.backgroundRepeat = 'repeat-x';

  this.south = DIV('border', this.div);
  this.south.style.width = px(this.w);
  this.south.style.height = px(BORDER);
  this.south.style.left = 0;
  this.south.style.top = px(this.h - BORDER);
  this.south.style.background = "url('border-horiz.png')";
  this.south.style.backgroundRepeat = 'repeat-x';

  this.nw = IMG('abs', this.div);
  this.nw.src = 'corner-nw.png';
  this.nw.style.left = 0;
  this.nw.style.top = 0;

  this.ne = IMG('abs', this.div);
  this.ne.src = 'corner-ne.png';
  this.ne.style.left = px(this.w - CORNER);
  this.ne.style.top = 0;

  this.sw = IMG('abs', this.div);
  this.sw.src = 'corner-sw.png';
  this.sw.style.left = 0;
  this.sw.style.top = px(this.h - CORNER);

  this.se = IMG('abs', this.div);
  this.se.src = 'corner-se.png';
  this.se.style.left = px(this.w - CORNER);
  this.se.style.top = px(this.h - CORNER);

  this.maximize = IMG('abs', this.div);
  this.maximize.src = 'maximize.png';
  this.maximize.style.left = px(this.maximizetoolx());
  this.maximize.style.top = px(BORDER - 1);

  this.minimize = IMG('abs', this.div);
  this.minimize.src = 'minimize.png';
  this.minimize.style.left = px(this.minimizetoolx());
  this.minimize.style.top = px(BORDER - 1);
};


function setupgame() {
 var win = new Win(10, 10, 320, 200, 'Accessories');
 win.menu = [
   { text: 'File',
     children: [ { text: 'New...' },
		 { text: 'Open...' },
		 { text: 'Exit Mindows' }]
   },
   { text: 'Help',
     children: [ { text: 'Contents' },
	         { text: 'About Mindows' }]
   }
 ];

 var win2 = new Win(80, 80, 400, 180, 'Program Manager');
}
