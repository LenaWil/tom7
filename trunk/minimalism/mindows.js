// TODO: Make mouse cursor invisible when it is outside the OS.
// TODO: Cursor doesn't work on mobile safari, but probably could.

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

function osmousemove(e) {
  var obj = getmouseposwithin(e, os);
  mousex = obj.x;
  mousey = obj.y;

  // Do actions if captured. This is also responsible for
  // setting the mouse state (cursor shape) in that case.
  if (capture) {
    switch (capture.what) {
      case 'resize':
        var ins = capture.inside;
	switch (ins.which) {
	  case 'se':
	    mousestate = 'mouse-resize-backslash.png';
	    ins.win.setwidth(mousex - ins.win.x - ins.gripx);
	    ins.win.setheight(mousey - ins.win.y - ins.gripy);
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
  var inside = getPointed();
  if (inside) {
    switch (inside.what) {
      case 'corner':
        capture = { what: 'resize', inside: inside };
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
  // XXX some captures may need to process this event?
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

function Win(x, y, w, h) {
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;

  // TODO: "modal"

  this.div = DIV('win', os);
  this.redraw();

  windows.push(this);
}

Win.prototype.inside = function(x, y) {
  var ins = x >= this.x && y >= this.y &&
    x < (this.x + this.w) && y < (this.y + this.h);
  if (!ins) return null;

  // We know we're inside.

  // XXX check buttons BEFORE corners.

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

  // XXX check title AFTER corners


  return { what: 'win', win: this };
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

Win.prototype.setwidth = function(w) {
  w = Math.max(w, MINWIDTH);
  this.w = w;
};

Win.prototype.setheight = function(h) {
  h = Math.max(h, MINHEIGHT);
  this.h = h;
};

// Assuming the metrics are set (x,y,w,h),
// places the window in the DOM and
// draws its borders.
Win.prototype.redraw = function() {
  var d = this.div;
  d.innerHTML = '';
  d.style.left = this.x + 'px';
  d.style.top = this.y + 'px';
  d.style.width = this.w + 'px';
  d.style.height = this.h + 'px';

  // Add menu bar.
  this.title = DIV('title', this.div);
  this.title.style.width = px(this.w);
  this.title.style.height = px(TITLE);
  this.title.style.top = px(BORDER);
  this.title.style.left = 0;
  this.title.style.background = "url('title.png')";
  this.title.style.backgroundRepeat = 'repeat-x';

  TEXT('Program Manager', this.title);

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
  this.maximize.style.left = px(this.w - TOOL - BORDER + 1);
  this.maximize.style.top = px(BORDER - 1);

  this.minimize = IMG('abs', this.div);
  this.minimize.src = 'minimize.png';
  this.minimize.style.left = px(this.w - (TOOL * 2) - BORDER + 1 + 1);
  this.minimize.style.top = px(BORDER - 1);

};
