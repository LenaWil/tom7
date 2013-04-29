// MUST DO.
// TODO: Solitaire.
// TODO: Recognize when all windows are minimized.
// TODO: Hint (manifesto) text, somewhere.
// TODO: Don't let icons minimize off-screen (confusing path
//       to unintended "solution")

// Apps.
// TODO: Minsweeper
// TODO: Paintbrush
// TODO: Media Player with MIDIs.
// TODO: Editing in legal pad.
// TODO: Control panel with mouse trails.

// Improvements to core idea.
// TODO: "Program Manager" -> "Task Manager"; shows the hierarchy
//       of apps and where they minimize to; could cover:
// TODO: Visually distinguish a "launcher" and a minimized app.
//       (e.g. parens when minimized?)
// TODO: Don't allow dragging of maximized window. It looks like
//       dragon drop itself is maybe just a window in the web page,
//       which could encourage dragging.
// TODO: Remark when winning solitaire. Remark bonus when
//       winning after cheating.

// Icing.
// TODO: Tile
// TODO: All characters is small font -- even necessary?
// TODO: Make mouse cursor invisible when it is outside the OS.
// TODO: Cursor doesn't work on mobile safari, but probably could.
// TODO: Viewport etc. for mobile safari
// TODO: Maximize button switches to "restore" when maximized.


// Mouse position within the OS.
var mousex = 320, mousey = 200;

// Element containing the OS instance.
var oslockout = true;
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

  return mainicons.inside(0, 0, mousex, mousey);
}


function oscarddrop(cards) {
  for (var i = windows.length - 1; i >= 0; i--) {
    var win = windows[i];
    if (win.inbounds(mousex, mousey)) {
      if (win.dropcards) {
	// May be null.
	return win.dropcards(cards, mousex, mousey);
      }
      return null;
    }
  }
  return null;
}

function cascadeall() {
  for (var i = 0; i < windows.length; i++) {
    windows[i].blur();
    windows[i].x = ((i + 1) * 32) % 480;
    windows[i].y = ((i + 1) * 32) % 300;
    windows[i].w = 400;
    windows[i].h = 280;
  }
  osredraw();
}

function tileall() {
  alert('unimplemented');
  osblur();
  osredraw();
}

function osblur() {
  for (var i = 0; i < windows.length; i++) {
    windows[i].blur();
  }
  mainicons.blur();
}

// Traverse screen space to find an iconholder that
// we can drop into. This can be either a window with
// an iconholder, or the toplevel iconholder. It will
// be null if the mouse is currently over an area that
// can't accept icons (though it is always safe to drop
// on that spot on the desktop, it's just under a
// window.)
function getDrop(x, y) {
  // Don't use the 'inside' call; we don't care about
  // whether we're pointing at a menu or another icon
  // or whatever. Just see if we're in bounds and
  // the window has a holder.
  for (var i = windows.length - 1; i >= 0; i--) {
    var win = windows[i];
    if (!win) throw ('win ' + i);
    // var inbounds = win.inbounds(mousex, mousey);
    // XXX also want the coordinates within the holder,
    // I think.
    if (win.inbounds(mousex, mousey)) {
      return win.icons || null;
    }
  }

  // Always can put in the main holder.
  return mainicons;
}

function osmousemove(e) {
  if (oslockout) return;

  e = e || window.event;

  // XXX doesn't work on mobile safari if zoomed, maybe
  // this is not the right way.
  // XXX doesn't work on regular browsers if scrolled!
  var elt = document.getElementById('oscont');
  // XXX use clientrectangle?
  var origx = elt.offsetLeft, origy = elt.offsetTop;
  
  mousex = e.clientX - origx;
  mousey = e.clientY - origy;

  // Do actions if captured. This is also responsible for
  // setting the mouse state (cursor shape) in that case.
  if (capture) {
    var ins = capture.inside;
    switch (capture.what) {
    case 'movestack':
      // nothing to do.
      osredraw();
      break;
    case 'drag':
      var drop = getDrop(mousex, mousey);
      mousestate = 'mouse.png';
      if (drop) {
	deb.innerHTML = 'drop target';

	if (drop == ins.holder) {
	  // Normal behavior -- dragging from a holder to
	  // itself.
	  ins.entry.x = (mousex - ins.basex) - ins.gripx;
	  ins.entry.y = (mousey - ins.basey) - ins.gripy;
	} else {
	  // TODO: Bring the drop target to the front?
	  // Only if we drop in it?
	  mousestate = 'mouse-drop.png';
	  // TODO: Would be nice to highlight the drop target
	}

      } else {
	// XXX set NO cursor; can't drag into this window
	// (ok to drag to desktop under it)
	mousestate = 'mouse-no.png';
	deb.innerHTML = 'no drop target';

	// It would be okay to move it (within the same
	// iconholder, but this makes it very easy to
	// drag icons into places outside the visible
	// part of the window.)
	// ins.entry.x = (mousex - ins.basex) - ins.gripx;
	// ins.entry.y = (mousey - ins.basey) - ins.gripy;
      }

      osredraw();
      break;
    case 'press':
      // deb.innerHTML = 
      // '' + mousex + ' ' + ins.x + ' ' + mousey +  ' ' + ins.y;
      var onit = mousex >= ins.x && mousey > ins.y &&
	  mousex < ins.x + ins.w && mousey < ins.y + ins.h;
      if (ins.down) {
        var newsrc = onit ? ins.down : ins.up;
        if (ins.elt.src != newsrc) {
	  ins.elt.src = newsrc;
	  // deb.innerHTML = '' + onit + ' set src to ' + newsrc;
	}
      }
      break;
    case 'move':
      // This can only be title, currently.
      ins.win.moveto(mousex - ins.gripx, mousey - ins.gripy);
      // ins.win.redraw(os);
      osredraw();
      break;
    case 'resize':
      switch (ins.which) {
      case 'se':
	mousestate = 'mouse-resize-backslash.png';
	ins.win.resizeright(mousex - ins.win.x - ins.gripx);
	ins.win.resizedown(mousey - ins.win.y - ins.gripy);
	// ins.win.redraw(os);
	osredraw();
	break;
      case 'sw':
	mousestate = 'mouse-resize-slash.png';
	ins.win.resizeleft(mousex - ins.gripx);
	ins.win.resizedown(mousey - ins.win.y - ins.gripy);
	// ins.win.redraw(os);
	osredraw();
	break;
      case 'nw':
	mousestate = 'mouse-resize-backslash.png';
	ins.win.resizeleft(mousex - ins.gripx);
	ins.win.resizeup(mousey - ins.gripy);
	// ins.win.redraw(os);
	osredraw();
	break;
      case 'ne':
	mousestate = 'mouse-resize-slash.png';
	ins.win.resizeright(mousex - ins.win.x - ins.gripx);
	ins.win.resizeup(mousey - ins.gripy);
	// ins.win.redraw(os);
	osredraw();
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
      case 'childmenu':
	var menu = inside.menu;
	var child = inside.child;
	menu.selected = child;
	// alert( 'mousemove over child');
	osredraw(); // PERF Just menu?
	break;
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
  if (oslockout) return;
  e = e || window.event;

  // Something is weird (like user left surface and came
  // back) if we get a mousedown event while we are in
  // capture. So simulate a mouseup before the mousedown.
  if (capture != null) {
    osmouseup(e);
    capture = null;
  }

  var inside = getPointed();
  if (inside) {
    deb.innerHTML = inside.what;
    switch (inside.what) {
    case 'stack':
      osblur();
      var grab = inside.grab;
      // Do the action.
      grab.take();

      deb.innerHTML = ('GRABBED ' + grab.cards.join('-'));
      capture = { what: 'movestack',
		  cards: grab.cards,
		  inside: inside };

      osmousemove(e);
      break;
    case 'click':
      osblur();
      inside.action();
      break;
    case 'icon':
      osblur();
      inside.holder.selected = inside.entry;
      var now = getMillis();
      if (inside.entry.lastclick && 
	  (now - inside.entry.lastclick) < DOUBLECLICKMS) {
	inside.holder.activate(inside.entry);
      } else {
	inside.entry.lastclick = now;
	capture = { what: 'drag', inside: inside };
	osmousemove(e);
      }
      break;
    case 'menu':
      inside.win.movetofront();
      inside.menu.selected = inside.which;
      // capture = { what: 'clickmenu', inside: inside };
      osredraw();
      break;
    case 'childmenu':
      deb.innerHTML = 'mousedown on child';
      // Note, not the same type as above, so make sure we
      // only depend on shared fields?
      // capture = { what: 'clickmenu', inside: inside };
      osmousemove(e);
      break;
    case 'button':
      osblur();
      capture = { what: 'press', inside: inside };
      // inside.win.movetofront();
      osmousemove(e);
      break;
    case 'corner':
      osblur();
      capture = { what: 'resize', inside: inside };
      break;
    case 'title':
      osblur();
      capture = { what: 'move', inside: inside };
      inside.win.movetofront();
      osredraw();
      break;
    case 'win':
      osblur();
      inside.win.movetofront();
      osredraw();
      break;
    default:;
    }
  } else {
    // Clicks on background -- nothing?
    deb.innerHTML = 'background click';
    osblur();
    osredraw();
  }
}

function osmouseup(e) {
  if (oslockout) return;
  e = e || window.event;

  if (capture) {
    var ins = capture.inside;
    switch (capture.what) {
    case 'movestack':
      var grab = ins.grab;

      // XXX allow legal drops, of course!
      var drop = oscarddrop(grab.cards);
      if (drop) {
	drop();
      } else {
	grab.undo();
      }
      // Need to do this before redraw because of
      // exceptional behavior.
      capture = null;

      osredraw();
      /*
      deb.innerHTML = ('GRABBED ' + grab.cards.join('-'));
      capture = { what: 'movestack',
		  cards: grab.cards,
		  inside: inside };
      */
      break;

    case 'drag':

      // Only have something to do if there's a drop and
      // it's different from the current container.
      var drop = getDrop(mousex, mousey);
      if (drop && drop != ins.holder) {
	deb.innerHTML = 'drag & drop';
	
	// TODO
	ins.holder.removeentry(ins.entry);
	// Might be nice to give placement hint.
	drop.place(ins.entry.icon);
      }

      osredraw();
      break;

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

  var inside = getPointed();
  if (inside) {
    switch (inside.what) {
    case 'childmenu':
      osblur();
      if (inside.child.fn) inside.child.fn();
      osredraw();
    default:
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
}

function initos(elt) {
  os = elt;

  // Always placed at 0,0.
  mainicons = new IconHolder(OSWIDTH, OSHEIGHT, true);

  var sp = document.getElementById('spaceball');

  sp.onmousemove = osmousemove;
  sp.onmousedown = osmousedown;
  sp.onmouseup = osmouseup;
  oslockout = false;

  osredraw();
}

// XXX to OS object?
function osredraw() {
  os.innerHTML = '';

  mouse = IMG('mouse', os);
  mouse.src = 'mouse.png';
  redrawmouse();

  mainicons.redraw(os, 0, 0);
  for (var i = 0; i < windows.length; i++) {
    windows[i].redraw(os);
    windows[i].div.style.zIndex = WINDOWZ + i;
  }

  // Exceptional rendering.
  //
  // SPOILER ALERT!
  //
  // Allows cards to be dragged from one window to another.
  if (capture && capture.what == 'movestack') {
    var grab = capture.inside.grab;
    // HERE
    var x = mousex - grab.gripx;
    var y = mousey - grab.gripy;
    for (var i = 0; i < grab.cards.length; i++) {
      var c = rendercardfront(x, y, grab.cards[i], os);
      c.style.zIndex = 7000;
      y += SHOWY;
    }
  }
}

function makeRender(FONTCHARS, FONTW, FONTH, FONTOVERLAP) {
  var CHARS = [];
  for (var i = 0; i < FONTCHARS.length; i++) {
    var c = FONTCHARS.charCodeAt(i);
    if (c >= 0 && c < 128) {
      CHARS[c] = i;
    }
  }

  return function(text, elt, font) {
    for (var i = 0; i < text.length; i++) {
      var c = text.charCodeAt(i);
      if (c >= 0 && c < 128) {
	var d = DIV('ch', elt);
	d.style.cssFloat = 'left';
	d.style.width = px(FONTW);
	d.style.height = px(FONTH);
	d.style.marginLeft = '-' + FONTOVERLAP + 'px';
	d.style.backgroundImage = 'url(' + font + '.png)';
	d.style.backgroundPosition = (CHARS[c] * - FONTW) + 'px 0px';
      }
    }
  };
}

var rendertext = makeRender(FONTCHARS, FONTW, FONTH, FONTOVERLAP);
var rendersmalltext = makeRender(FONTCHARS, SMALLFONTW, SMALLFONTH,
				 SMALLFONTOVERLAP);
// TODO: small text

function Win(x, y, w, h, title) {
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;
  this.title = title || '';
  this.icon = 'genericicon.png';

  // TODO: "modal"

  windows.push(this);

  this.redraw(os);
}

Win.prototype.blur = function() {
  if (this.menu) {
    this.menu.selected = null;
    // TODO: Undo popouts too.
  }

  if (this.icons) {
    this.icons.selected = null;
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
  osredraw();
}

function removefromwindows(win) {
  // Remove window from list.
  var nwin = [];
  for (var i = 0; i < windows.length; i++) {
    if (windows[i] != win) {
      nwin.push(windows[i]);
    }
  }
  windows = nwin;
}

Win.prototype.dominimize = function() {
  removefromwindows(this);

  this.blur();
  this.detach();
  var that = this;
  var icon = new Icon(this.icon,
		      this.title,
		      function() {
			windows.push(that);
			return that;
		      },
		      // Not an app.
		      false);
  icon.win = this;
  
  var target = this.minimizationtarget || mainicons;
  target.place(icon);
  osredraw();
};

// If app is true, the icon is not removed when
// the app is launched.
function Icon(graphic, title, launcher, app) {
  this.graphic = graphic;
  this.title = title;
  this.launcher = launcher;
  this.win = null;
  this.app = app;
}

// Space that can hold icons, of size w,h. It can
// be resized. Uses relative coordinate system.
function IconHolder(w, h, main) {
  this.w = w;
  this.h = h;
  this.icons = [];
  this.main = main;
}

// Currently no way to replace it.
IconHolder.prototype.detach = function() {
  this.div.parentElement.removeChild(this.div);
  this.icons = [];
};

IconHolder.prototype.activate = function(entry) {
  // Filter it out of the list, if this is the main
  // iconholder. The main one is minimized programs.
  if (!entry.icon.app) {
    this.removeentry(entry);
  }
  
  entry.icon.launcher();
  osredraw();
}

IconHolder.prototype.blur = function() {
  this.selected = null;
}

IconHolder.prototype.redraw = function(parent, x, y) {
  this.div = DIV('iconholder', parent); // ?
  this.div.innerHTML = '';
  this.div.style.left = px(x);
  this.div.style.top = px(y);
  this.div.style.width = px(this.w);
  this.div.style.height = px(this.h);
  for (var i = 0; i < this.icons.length; i++) {
    var entry = this.icons[i];
    var item = DIV('icon', this.div);
    item.style.left = px(entry.x);
    item.style.top = px(entry.y);
    var img = IMG('icon', item);
    img.src = entry.icon.graphic;
    img.style.marginLeft = px(Math.floor((ICONW - 32) / 2));
    
    // If selected, use other font.
    // If selected, make background.
    var caption = DIV('iconcaption', item);
    if (entry == this.selected) {
      caption.style.backgroundColor = BLUE;
      rendersmalltext(entry.icon.title, caption, 'smallfontwhite');
    } else {
      if (this.main) {
	rendersmalltext(entry.icon.title, caption, 'smallfontwhite');
      } else {
	rendersmalltext(entry.icon.title, caption, 'smallfontblack');
      }
    }
  }
};

IconHolder.prototype.removeentry = function(entry) {
  if (this.selected == entry) this.selected = null;
  var nicons = [];
  for (var i = 0; i < this.icons.length; i++) {
    if (this.icons[i] != entry) {
      nicons.push(this.icons[i]);
    }
  }
  this.icons = nicons;
}

IconHolder.prototype.place = function(icon) {
  // If we're placing a minimized window, then
  // the window gets its minimization target
  // set to this holder. Then, if it's minimized
  // again, it goes back to here.
  //
  // SPOILER ALERT!
  //
  // This can create a cycles, which is a "bug"
  // but the "point" of this "game".
  if (icon.win) {
    icon.win.minimizationtarget = this;
  }

  // XXX use more than one row!
  if (this.main) {
    this.icons.push({ x: this.icons.length * 90, 
		      y: this.h - 90,
		      icon: icon });
  } else {
    this.icons.push({ x: this.icons.length * 90,
		      y: 10,
		      icon: icon });
  }
};

// Arguments need to be relative to the iconholder, which always
// believes it is at 0, 0.
IconHolder.prototype.inside = function(basex, basey, x, y) {
  // XXX Icon holders should just fill the whole window. There's
  // no point in this width/height stuff.
  // var ins = x >= 0 && y >= 0 && x < this.w && y < this.h;
  // if (!ins) return null;

  for (var i = 0; i < this.icons.length; i++) {
    var entry = this.icons[i];
    // deb.innerHTML = 'ex ' + entry.x + ' ey ' + entry.y +
    // ' tx ' + x + ' ty ' + y;
    if (x >= entry.x && y >= entry.y &&
	x < (entry.x + ICONW) && y < (entry.y + ICONH)) {
      // deb.innerHTML = ' IN IT.';
      // TODO base and grip could be merged, I think.
      return { what: 'icon', holder: this,
	       entry: entry, 
	       basex: basex, basey: basey,
	       gripx: x - entry.x, gripy: y - entry.y };
    }
  }

  return null;
};

Win.prototype.detach = function() {
  this.div.parentNode.removeChild(this.div);
};

// shouldn't be necessary any more?
Win.prototype.reattach = function() {
  os.appendChild(this.div);
};

Win.prototype.inbounds = function(x, y) {
  return x >= this.x && y >= this.y &&
    x < (this.x + this.w) && y < (this.y + this.h);
};

Win.prototype.inside = function(x, y) {
  if (!this.inbounds(x, y)) return null;

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
	     w: TOOL, h: TOOL,
	     action: function(ins) {
	       ins.win.dominimize();
	     } };
  }

  // Corner objects include the name of the corner
  // plus the grip offset, so that we can behave as
  // though the mouse is pointing EXACTLY at the corner
  // during resizing, even though the grabbable area is
  // more than one pixel.
  if (!this.fixed) {
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

    if (this.menu.selected) {
      var sel = this.menu.selected;
      for (var i = 0; i < sel.children.length; i++) {
	var child = sel.children[i];
	var met = child.metrics;
	// deb.innerHTML = objstring(child);
	if (x >= met.x &&
	    y >= met.y &&
	    x < (met.x + met.w) &&
	    y < (met.y + met.h)) {
	  // deb.innerHTML = 'over child ' + child.text;
	  return { what: 'childmenu', 
		   win: this,
		   menu: sel,
		   child: child };
	}
      }
    }
  }

  if (this.icons) {
    var ins = this.icons.inside(this.x + WINICONSX,
				this.y + WINICONSY,
				x - WINICONSX - this.x, 
				y - WINICONSY - this.y);
    if (ins) return ins;
  }

  // Check last, since e.g. menus overlap contents.
  if (this.insidecontents) {
    var ins = this.insidecontents(x, y);
    if (ins) {
      this.movetofront();
      return ins;
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
  removefromwindows(this);
  windows.push(this);
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
Win.prototype.redraw = function(parent) {
  var active = windows.length > 0 && 
      this == windows[windows.length - 1];

  var d = DIV('win', parent);
  this.div = d;
  d.innerHTML = '';
  d.style.left = this.x + 'px';
  d.style.top = this.y + 'px';
  d.style.width = this.w + 'px';
  d.style.height = this.h + 'px';

  if (this.backgroundimage) {
    d.style.backgroundImage = 'url(' + this.backgroundimage + ')';
  }

  // Do this first so that it doesn't go above decorations.
  if (this.drawcontents) {
    this.drawcontents();
  }

  if (this.icons) {
    // XXX might not have menu
    this.icons.redraw(d, WINICONSX, WINICONSY);
  }

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

	// And draw the child menu.
	var itemr = menuitem.getBoundingClientRect();
	var winr = this.div.getBoundingClientRect();
	var childbox = DIV('childmenu', this.div);
        childbox.style.top = px(itemr.top - winr.top + MENU);
	childbox.style.left = px(itemr.left - winr.left);
	childbox.style.height = MENU * this.menu[i].children.length;

	var maxwidth = 0;
	for (var j = 0; j < this.menu[i].children.length; j++) {
	  if (j > 0) BR('', childbox);
	    
	  var child = this.menu[i].children[j];
	  var childelt = DIV('childoption', childbox);
	  childelt.style.height = MENU;
	  childelt.style.cssFloat = 'left';
	  child.elt = childelt;
	  // if (this.menu[i].selected) alert('SEL');
	  if (child == this.menu[i].selected) {
	    childelt.style.background = BLUE;
	    rendertext(child.text, childelt, 'fontwhite');
	  } else {
	    rendertext(child.text, childelt, 'fontblack');
	  }

	  var metrics = getosmetrics(childelt);
	  child.metrics = metrics;
	  maxwidth = Math.max(metrics.w, maxwidth);
	  // TEXT(objstring(metrics), child.elt);
	}

	// Set every child's width to the width of the bounding
	// box, which is the max.

	// Sloppy.
	maxwidth -= CHILDPADDING;

	for (var j = 0; j < this.menu[i].children.length; j++) {
	  var child = this.menu[i].children[j];
	  child.elt.style.width = px(maxwidth);
	  child.metrics.w = maxwidth;
	}

      } else {
	rendertext(this.menu[i].text, menuitem, 'fontblack');
	this.menu[i].selected = null;
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

function centeredmodalwindow(title, cw, ch) {
  var totalw = cw + BORDER * 2;
  // XXX ok button!
  var totalh = ch + BORDER * 2 + TITLE + OKBUTTON;
  var win = new Win(Math.floor((OSWIDTH - totalw) / 2),
		    Math.floor((OSHEIGHT - totalh) / 2),
		    totalw, totalh,
		    title);
  win.modal = true;
  return win;
}

function aboutmindows() {
  var win = centeredmodalwindow('About Mindows', 300, 308);
  win.drawcontents = function() {
    var d = win.div;
    var i = IMG('abs', d);
    i.src = 'about-mindows.png';
    i.style.top = px(BORDER + TITLE);
    i.style.left = px(BORDER);

    var ok = IMG('abs', d);
    ok.src = 'ok.png';
    ok.style.left = px(OKBUTTONX);
    ok.style.top = px(OKBUTTONY);

    win.insidecontents = function(x, y) {
      var rx = x - win.x;
      var ry = y - win.y;
      // Can't click button if you can't see it.
      if (!win.inbounds(x, y)) {
	return null;
      }
      
      deb.innerHTML = rx + ' ' + ry + ' ' +
	  OKBUTTONX + ' ' + OKBUTTONY;
      if (rx >= OKBUTTONX && ry >= OKBUTTONY &&
	  rx < OKBUTTONX + OKBUTTONW &&
	  ry < OKBUTTONY + OKBUTTONH) {
	return { what: 'button', which: 'ok',
		 win: win,
		 elt: ok,
		 down: 'ok-down.png',
		 up: 'ok.png',
		 x: this.x + OKBUTTONX,
		 y: this.y + OKBUTTONY,
		 w: OKBUTTONW, h: OKBUTTONH,
		 action: function(ins) {
		   removefromwindows(win);
		   osredraw();
		 } };
      }

      return null;
    };
  };
}

function legalpadapp() {
  var win = new Win(50, 10, 300, 400, "Legal Pad");
  win.menu = [
    { text: 'File',
      children: [ { text: 'New',
		    fn: function() {
		      win.legalese = [];
		      win.line = 0;
		      win.cursor = 0;
		    } },
		  { text: 'Open...' },
		  { text: 'Exit Legal Pad',
		    fn: function() {
		      removefromwindows(win);
		      osredraw();
		    } }]
    }
  ];

  win.legalese = ['This is my attempt to make',
		  'a sort of notepad in min7.',
		  'The idea is to avoid all the tricky',
		  'stuff by foisting it on the user!'];
  // On the nth line.
  win.line = 0;
  // After the nth character.
  win.cursor = 0;
  win.drawcontents = function() {
    var d = win.div;
    var cont = DIV('legalese', d);
    for (var i = 0; i < win.legalese.length; i++) {
      BR('', d);
      // XXX consider using helpline
      var line = DIV('legalline', cont);
      rendertext(win.legalese[i], line, 'fontblack');
    }
  };
  win.key = function(e) {
    // XXX
    // TODO: editing. Or kill legalpad.
  };
}

function helpviewer() {
  var win = new Win(50, 10, 360, 400, "Help");
  win.menu = [
    { text: 'File',
      children: [ { text: 'Exit Help',
		    fn: function() {
		      removefromwindows(win);
		      osredraw();
		    } }]
    }
  ];

  win.pages = [
    ['Welcome to Mindows 7!',
     '',
     'Use the arrow buttons at the top',
     'of this window to navigate the',
     'help pages.',
     ''],

    ['What\'s new in Mindows 7?',
     '',
     'ENHANCED MINIMIZATION.',
     '',
     'As you know, Mindows has supported ',
     'minimization since version 1. However, ',
     'in Mindows 7, minimization has never ',
     'been so powerful. Now you can drag ',
     'a minimized window into another window, ',
     'to keep things tidy. It even remembers ',
     'where you put it, so that every time ',
     'you minimize again, it goes back into ',
     'that same window--even if it\'s minimized ',
     'too!'],

    ['',
     'POWERFUL ENTERPRISE FEATURES.',
     '',
     'Your company will be back on top ',
     'with these powerful capabilities ',
     'for business. Take minutes on the go ',
     'with Legal Pad, share a compute with ',
     'your workgroup, or send the ',
     'accounting department packing after ',
     'you see what Excess Spreadsheets ',
     'can do!*',
     '',
     '',
     '* Sold separately.'],

    ['',
     'SPOTLIGHT ON PERFORMANCE.',
     '',
     'Mindows 7 has been fine-tuned for ',
     'lightning-fast performance and memory ',
     'usage. With a high-end computer it is ',
     'even possible to run more than one game ',
     'at once--even multiple copies of the ',
     'same game!'],
  ];

  var prevx = BORDER + 2;
  var prevy = BORDER * 2 + TITLE + MENU;

  var nextx = BORDER + 2 + NEXTPREVW - 1;
  var nexty = BORDER * 2 + TITLE + MENU;

  // On the nth page
  win.page = 0;
  win.drawcontents = function() {
    if (win.page < 0) win.page = 0;
    if (win.page >= win.pages.length) win.page = win.pages.length - 1;
    var d = win.div;

    var prev = IMG('abs', d);
    prev.src = 'prev.png';
    prev.style.left = px(prevx);
    prev.style.top = px(prevy);

    var next = IMG('abs', d);
    next.src = 'next.png';
    next.style.left = px(nextx);
    next.style.top = px(nexty);
    
    var cont = DIV('pagedhelp', d);
    for (var i = 0; i < win.pages[win.page].length; i++) {
      BR('clear', d);
      var text = win.pages[win.page][i];
      var line = DIV('helpline', cont);
      rendertext(text, line, 'fontblack');
    }

    win.insidecontents = function(x, y) {
      if (x >= this.x + prevx && y >= this.y + prevy &&
	  x <= this.x + prevx + NEXTPREVW &&
	  y <= this.y + prevy + NEXTPREVH) {
	return { what: 'button', which: 'prev',
		 win: win,
		 elt: prev,
		 down: 'prev-down.png',
		 up: 'prev.png',
		 x: this.x + prevx,
		 y: this.y + prevy,
		 w: NEXTPREVW, h: NEXTPREVH,
		 action: function(ins) {
		   win.page--;
		   osredraw();
		 } };
      } else if (x >= this.x + nextx && y >= this.y + nexty &&
		 x <= this.x + nextx + NEXTPREVW &&
		 y <= this.y + nexty + NEXTPREVH) {
	return { what: 'button', which: 'next',
		 win: win,
		 elt: next,
		 down: 'next-down.png',
		 up: 'next.png',
		 x: this.x + nextx,
		 y: this.y + nexty,
		 w: NEXTPREVW, h: NEXTPREVH,
		 action: function(ins) {
		   win.page++;
		   osredraw();
		 } };
      }
    };
  };

}

function exitmindows() {
  for (var i = 0; i < windows.length; i++) {
    windows[i].detach();
  }
  windows = [];

  mainicons.detach();
  mouse.parentElement.removeChild(mouse);
  mouse = null;
  os.innerHTML = '';

  oslockout = true;

  // Now do the restart animation.
  settimeoutk(
    100, function() {
      var dos = IMG('abs', os);
      dos.src = 'dosprompt.gif';
      dos.style.left = 0;
      dos.style.top = 0;
      settimeoutk(
	2000, function() {
	  dos.parentElement.removeChild(dos);
	  
	  // XXX first, splash screen.

	  // XXX then, mouse.
	  settimeoutk(
	    600, function() {
	      initos(document.getElementById('os'));
	      setupwindows();
	      // Must redraw after setupwindows!
	      osredraw();
	    });
	});
    });
}

// Cards are just represented as numbers.
function cardsuit(n) {
  return n % NSUITS;
}
function cardrank(n) {
  return Math.floor(n / NSUITS);
}

function rendercardfront(x, y, n, elt) {
  var card = DIV('card', elt);
  card.style.top = px(y);
  card.style.left = px(x);
  var cimg = IMG('abs', card);
  cimg.src = 'card.png';
  var s = cardsuit(n);
  var r = cardrank(n);

  // XXX bottom right too
  var ctext = DIV('', card);
  ctext.style.position = 'absolute';
  ctext.style.zindex = 1;
  ctext.style.left = px(3);
  ctext.style.top = px(2);

  if (s == 0) {
    rendertext('' + r + SKULL, ctext, 'fontblack');
  } else {
    rendertext('' + r + HEART, ctext, 'fontred');
  }

  // XXX symbol in center, or many symbols
  // in center.

  return card;
}


function dragondrop() {
  var win = new Win(40, 40, 560, 400, "Dragon Drop");

  win.backgroundimage = 'darkgreen.png';

  // Game state.
  var back = 0;
  var NBACKS = 2;
  var backs = ['dragon.png', 'tartanic.png']

  // Don't modify.
  var allcards = [];
  for (var i = 0; i < NSUITS * NRANKS; i++) {
    allcards.push(i);
  }

  // Two "places" (one for each suit)... a list of the
  // cards, where the end is the top.
  var placeheart = [];
  var placeskull = [];

  // A single "draw" pile. This is a list, with the
  // end being the next cards to show.
  var drawpile = [];
  var wastepile = [];

  // Exactly 4 work piles.
  var NPILES = 4;
  var workpiles = [];
  var revealed = [];
  // Necessary?
  for (var i = 0; i < NPILES; i++) {
    workpiles.push([]);
    revealed.push([]);
  }

  function redeal() {
    placeheart = [];
    placeskull = []
    drawpile = allcards.slice(0);
    shuffle(drawpile);
    workpiles = [];
    revealed = [];
    wastepile = [];
    for (var i = 0; i < NPILES; i++) {
      var a = [];
      for (var c = 0; c < i; c++) {
	a.push(drawpile.pop());
      }
      workpiles.push(a);
      revealed.push([drawpile.pop()]);

      // XXX NO! FIXME DO NOT SUBMIT
      /*
      var l = workpiles.length - 1;
      if (workpiles[l].length > 0)
	revealed[l].push(workpiles[l].pop());
	*/
    }
  }

  redeal();
  
  // Makes and returns an element at x,y
  // that shows a face-down card.
  function cardback(x, y) {
    var card = DIV('card', win.div);
    card.style.top = px(y);
    card.style.left = px(x);
    IMG('abs', card).src = 'card.png';
    IMG('abs', card).src = backs[back];
    return card;
  }

  var cardfront = function(x, y, n) {
    return rendercardfront(x, y, n, win.div);
  }

  // Cycle cards into the waste, or redeal.
  function dodraw() {
    // deb.innerHTML = objstring(drawpile) + '/' + objstring(wastepile);

    if (drawpile.length == 0) {
      while (wastepile.length > 0) {
	drawpile.push(wastepile.pop());
      }
      return;
    }
    
    // Note, might even be empty (then nothing
    // happens).
    var num = Math.min(3, drawpile.length);
    for (var i = 0; i < num; i++) {
      wastepile.push(drawpile.pop());
    }
  }

  win.drawcontents = function() {
    var d = win.div;

    // Clickable action areas.
    var actions = [];
    // A grabbable stack. This includes
    // cards in the waste (and could include the
    // holders, though not yet), which are always
    // single-card stacks.
    // Contains a list of functions that tell you
    // whether the grab succeeded, by returning
    // a record of a bunch of things about the grab.
    var stacks = [];

    // Places where dropping is possible.
    var drops = [];

    // Always draw card holders.
    // XXX if they have cards on, then can skip this
    // XXX draw these as skull/heart holders.

    if (placeheart.length == 0) {
      var phelt = IMG('abs', d);
      phelt.src = 'placeace.png';
      phelt.style.left = px(PLACEHEARTX);
      phelt.style.top = px(PLACEY);
    } else {
      cardfront(PLACEHEARTX, PLACEY, 
		placeheart[placeheart.length - 1]);
    }

    if (placeskull.length == 0) {
      var pselt = IMG('abs', d);
      pselt.src = 'placeace.png';
      pselt.style.left = px(PLACESKULLX);
      pselt.style.top = px(PLACEY);
    } else {
      cardfront(PLACESKULLX, PLACEY, 
		placeskull[placeskull.length - 1]);
    }

    function holderdrophandler(x, y, holder) {
      return function(cards, rx, ry) {
	if (rx >= x && ry >= y &&
	    rx < x + CARDW && ry < y + CARDH) {
	  // Only drop a single card at a time.
	  if (cards.length != 1) return null;
	  // On an empty holder, only an ace.
	  if (holder.length == 0) {
	    if (cardrank(cards[0]) != 0) return null;
	    return function() {
	      holder.push(cards[0]);
	    };
	  } else {
	    var topcard = holder[holder.length - 1];
	    // Only same suit.
	    if (cardsuit(topcard) != cardsuit(cards[0])) return null;
	    if (cardrank(topcard) != cardrank(cards[0]) - 1) return null;
	    // OK!
	    return function() {
	      holder.push(cards[0]);
	    };
	  }
	}
	return null;
      };
    }
      
    drops.push(holderdrophandler(PLACEHEARTX, PLACEY, placeheart));
    drops.push(holderdrophandler(PLACESKULLX, PLACEY, placeskull));

    // deb.innerHTML = objstring(workpiles) + '/' + objstring(revealed);

    // Draw drawpile.
    if (drawpile.length > 0) {
      var dpelt = cardback(DRAWPILEX, DRAWPILEY);
    } else {
      var reload = IMG('abs', win.div);
      reload.src = 'reload.png';
      reload.style.left = px(DRAWPILEX);
      reload.style.top = px(DRAWPILEY);
    }

    // You can always click on the draw pile or recycle symbol.
    actions.push(function(rx, ry) {
      // Draw pile.
      if (rx >= DRAWPILEX &&
	  ry >= DRAWPILEY &&
	  rx < DRAWPILEX + CARDW &&
	  ry < DRAWPILEY + CARDH) {
	return { what: 'click',
		 action: function(ins) {
		   dodraw();
		   osredraw();
		 } };
      }
      return null;
    });

    (function() {
      for (var p = 0; p < NPILES; p++) {
	var x = DRAWPILEX + (p * (CARDW + CARDSPACE));
	var y = WORKY;
	// Draw the workpile, literally as face-down cards.
	// If workpile and revealed are both empty,
	// draw a 7-holder.

	var workpile = workpiles[p];
	var rev = revealed[p];

	if (workpile.length == 0 && rev.length == 0) {
	  var k = IMG('abs', win.div);
	  k.src = 'placeseven.png';
	  k.style.left = px(x);
	  k.style.top = px(y);
	}

	for (var i = 0; i < workpile.length; i++) {
	  cardback(x, y);
	  y += BLINDY;
	}

	var grabhandler = function(x, y, height, width, rev, idx) {
	  return function(rx, ry) {
	    if (rx >= x && ry >= y &&
		rx < x + width && ry < y + height) {
	      // Clicked in the area. Need to know how
	      var oldrev = rev.slice(0);
	      return { 
		// offset within the card that we clicked.
		gripx: rx - x,
		gripy: ry - y,
		// Grabbing removes these cards.
		take: function() {
		  rev.splice(idx);
		},
		// It is understood that undoing drops the
		// cards being held; they just need to be
		// put back.
		undo: function() {
		  replacecontents(rev, oldrev);
		},
		// The cards to take.
		cards: rev.slice(idx),
	      };
	    }
	    return null;
	  };
	};

	for (var i = 0; i < rev.length; i++) {
	  // Height of grabbable area.
	  var height = (i == rev.length - 1) ? CARDH : SHOWY;
	  var width = CARDW;

	  stacks.push(grabhandler(x, y, height, width, rev, i));

	  cardfront(x, y, rev[i]);
	  y += SHOWY;
	}

	function revealeddrophandler(x, y, rev) {
	  return function(cards, rx, ry) {
	    if (rx >= x && ry >= y &&
		rx < x + CARDW && ry < y + CARDH) {
	      if (rev.length == 0) return null;
	      var topcard = rev[rev.length - 1];
	      // Only DIFFERENT suit.
	      if (cardsuit(topcard) == cardsuit(cards[0])) return null;
	      if (cardrank(topcard) != cardrank(cards[0]) + 1) return null;
	      // OK!
	      return function() {
		for (var i = 0; i < cards.length; i++) {
		  rev.push(cards[i]);
		}
	      };
	    }
	    return null;
	  };
	}

	function emptydrophandler(x, y, rev) {
	  return function(cards, rx, ry) {
	    if (rx >= x && ry >= y &&
		rx < x + CARDW && ry < y + CARDH) {
	      if (rev.length != 0) return null;

	      if (cardrank(cards[0]) != NRANKS - 1) return null;
	      // OK!
	      return function() {
		for (var i = 0; i < cards.length; i++) {
		  rev.push(cards[i]);
		}
	      };
	    }
	    return null;
	  };
	}

	if (rev.length > 0) {
	  drops.push(revealeddrophandler(x, y, rev));
	} else {
	  // if workpile is also empty, allow drop of
	  // max rank.
	  if (workpile.length == 0) {
	    drops.push(emptydrophandler(x, y, rev));
	  }
	}

	function flipcardhandler(x, y, workpile, rev) {
	  return function(rx, ry) {
	    if (rx >= x && ry >= y &&
		rx < x + CARDW && ry < y + CARDH) {
	      return { what: 'click',
		       action: function() {
			 if (workpile.length == 0)
			   throw 'precondition';
			 rev.push(workpile.pop());
			 osredraw();
		       } 
		     };
	    }
	    return null;
	  };
	}

	// Action to click workpiles to flip top card.
	if (rev.length == 0 && workpile.length > 0) {
	  actions.push(flipcardhandler(x, y, workpile, rev));
	}
      }
    })();

    // Now, the waste. We only show the last three cards,
    // if any.
    (function() {
      var wstart = Math.max(0, wastepile.length - 3);
      var x = WASTEX;
      var y = WASTEY;

      var wastegrabhandler = function(x, y) {
	return function(rx, ry) {
	  if (rx >= x && ry >= y &&
	      rx < x + CARDW && ry < y + CARDH) {
	    // Clicked in the area. Need to know how
	    var oldwaste = wastepile.slice(0);
	    return {
	      // offset within the card that we clicked.
	      gripx: rx - x,
	      gripy: ry - y,
	      // Grabbing removes these cards.
	      take: function() {
		wastepile.pop();
	      },
	      // It is understood that undoing drops the
	      // cards being held; they just need to be
	      // put back.
	      undo: function() {
		replacecontents(wastepile, oldwaste);
	      },
	      // The cards to take.
	      cards: [wastepile[wastepile.length -1]],
	    };
	  }
	  return null;
	};
      };

      for (var i = wstart; i < wastepile.length; i++) {
	cardfront(x, y, wastepile[i]);
	if (i == wastepile.length - 1) {
	  stacks.push(wastegrabhandler(x, y));
	}
	x += SHOWX;
      }
    })();

    win.dropcards = function(cards, x, y) {
      // Only capture drops if they actually overlap the
      // window (even if we have something good in that
      // logical spot).
      if (x < this.x || y < this.y ||
	  x >= this.x + this.w || y > this.y + this.h) {
	return null;
      }
      
      // Relative to window.
      var rx = x - this.x;
      var ry = y - this.y;

      for (var i = 0; i < drops.length; i++) {
	var drop = drops[i](cards, rx, ry);
	if (drop) return drop;
      }
      return null;
    };

    win.insidecontents = function(x, y) {
      // Relative to window.
      var rx = x - this.x;
      var ry = y - this.y;

      for (var i = 0; i < actions.length; i++) {
	var ins = actions[i](rx, ry);
	if (ins) return ins;
      }

      for (var i = 0; i < stacks.length; i++) {
	var obj = stacks[i](rx, ry);
	if (obj) {
	  // deb.innerHTML = objstring(obj.cards);
	  return { what: 'stack',
		   win: win,
		   grab: obj };
	}
      }

      return null;
    };
  };

  win.menu = [
    { text: 'File',
      children: [ 
	{ text: 'Restart',
	  fn: function() {
	    redeal();
	  } },
	{ text: 'Change Cards',
	  fn: function() {
	    back++;
	    back %= NBACKS;
	    osredraw();
	  } }
	// Don't allow exiting, because it makes the
	// first "puzzle" too obvious.
/*
         ,{ text: 'Exit Dragon Drop',
	  fn: function() {
	    removefromwindows(win);
	    osredraw();
	  } }
*/
      ]
    }
  ];
}

function randzerotounder(n) {
  var x = Math.floor(Math.random() * n);
  if (x >= n) return 0;
  return x;
}

function minsweeper() {
  var win = new Win(75, 40, 368, 368 - 80, "Minsweeper");
  win.fixed = true;

  var WIDTH = 18;
  var HEIGHT = 12;

  var cells = {};

  var HIDDEN = 0;
  var HIDDENBOMB = 1;
  var EMPTY = 2;
  var NEARBY = 3;
  var BOMB = 4;
  var NBOMBS = 12;

  function restart() {
    for (var y = 0; y < HEIGHT; y++) {
      for (var x = 0; x < WIDTH; x++) {
	cells[[x, y]] = HIDDEN;
      }
    }

    for (var i = 0; i < NBOMBS; i++) {
      var y = randzerotounder(HEIGHT);
      var x = randzerotounder(WIDTH);
      // deb.innerHTML = x + ' - ' + y;
      cells[[x, y]] = HIDDENBOMB;
    }
  }

  restart();

  function getgraphic(c, nhidden, bombrevealed) {
    switch(c) {
    case HIDDENBOMB:
      if (nhidden == 0 || bombrevealed) {
	return 'minecell-bombhere.png';
      } else {
	return 'minecell.png';
      }
      // FALLTHROUGH.
    case HIDDEN:
      return 'minecell.png';
      break;
    case EMPTY:
      return 'minecell-empty.png';
      break;
    case NEARBY:
      return 'minecell-nearby.png';
      break;
    default:
    case BOMB:
      return 'minecell-bomb.png';
    }
  }

  win.drawcontents = function() {
    var d = win.div;

    var elts = {};

    var bombrevealed = false;
    var nhidden = 0;
    for (var y = 0; y < HEIGHT; y++) {
      for (var x = 0; x < WIDTH; x++) {
	var c = cells[[x, y]];
	if (c == HIDDEN) nhidden++;
	if (c == BOMB) bombrevealed = true;
      }
    }

    deb.innerHTML = '' + nhidden;

    for (var y = 0; y < HEIGHT; y++) {
      for (var x = 0; x < WIDTH; x++) {
	var c = cells[[x, y]];
	var cimg = IMG('abs', d);
	elts[[x,y]] = cimg;
	cimg.style.left = px(x * CELL + GRIDX);
	cimg.style.top = px(y * CELL + GRIDY);
	cimg.src = getgraphic(c, nhidden, bombrevealed);
      }
    }

    function floodfill(startx, starty) {
      var todo = [{x: startx, y: starty}];

      while (todo.length > 0) {
	var now = todo.pop();
	var x = now.x, y = now.y;
	if (cells[[x, y]] != HIDDEN) continue;

	// See if there are any bombs around us.
	var hasbomb = false;
	var qq = [];
	for (var dy = -1; dy <= 1; dy++) {
	  for (var dx = -1; dx <= 1; dx++) {
	    var tx = x + dx, ty = y + dy;
	    if (tx >= 0 && ty >= 0 &&
		tx < WIDTH && ty <= HEIGHT) {
	      var c = cells[[tx, ty]];
	      if (c == HIDDEN) qq.push({x: tx, y: ty});
	      hasbomb = hasbomb ||
		  cells[[tx, ty]] == HIDDENBOMB ||
		  cells[[tx, ty]] == BOMB;
	    }
	  }
	}

	if (hasbomb) {
	  cells[[x, y]] = NEARBY;
	} else {
	  cells[[x, y]] = EMPTY;
	  for (var i = 0; i < qq.length; i++) {
	    todo.push(qq[i]);
	  }
	}
      }
    }

    function click(x, y) {
      if (x < 0 || y < 0 || x >= WIDTH || y >= HEIGHT)
	throw 'precondition';

      var c = cells[[x, y]];
      if (c == HIDDENBOMB) {
	cells[[x, y]] = BOMB;
      } else if (c == HIDDEN) {
	floodfill(x, y);
      }
      // alert('click ' + c);
    }

    win.insidecontents = function(x, y) {
      var rx = x - (this.x + GRIDX);
      var ry = y - (this.y + GRIDY);

      // Dead!
      if (bombrevealed)
	return null;
      
      if (rx < 0 || ry < 0 || 
	  rx >= (WIDTH * CELL) ||
	  ry >= (HEIGHT * CELL))
	return null;

      var cx = Math.floor(rx / CELL);
      var cy = Math.floor(ry / CELL);

      var c = cells[[cx, cy]];
      var elt = elts[[cx, cy]];
      var up = getgraphic(c, nhidden, bombrevealed);

      var down = (c == HIDDEN ||
		  c == HIDDENBOMB) ? 'minecell-down.png' : up;

      // would be bug
      if (!elt) return null;

      // deb.innerHTML = '' + cx + ' ' + cy;
      return { what: 'button', which: 'ms',
	       win: win,
	       elt: elt,
	       down: down,
	       up: up,
	       x: this.x + cx * CELL + GRIDX,
	       y: this.y + cy * CELL + GRIDY,
	       w: CELL, h: CELL,
	       action: function(ins) {
		 click(cx, cy);
		 osredraw();
	       }
	     };
    };
  };

  win.menu = [
    { text: 'File',
      children: [ 
	{ text: 'Restart',
	  fn: function() {
	    restart();
	  } },
        { text: 'Exit Minsweeper',
	  fn: function() {
	    removefromwindows(win);
	    osredraw();
	  } }
      ]
    }
  ];
}

function setupwindows() {
  var accessories = new Win(10, 10, 320, 200, 'Accessories');
  accessories.icons = new IconHolder(300, 180, false);
  var about = new Icon('genericicon.png',
		       '    About',
		       function() {
			 aboutmindows();
		       },
		       true);
  var legalpad = new Icon('legalpad.png',
			  '   Legal Pad',
			  function() {
			    legalpadapp();
			  },
			  true);
  accessories.icons.place(about);
  accessories.icons.place(legalpad);

  // XXX what is "in" the program manager? Task list?
  var pgm = new Win(80, 80, 400, 180, 'Program Manager');
  pgm.backgroundimage = 'litegrey.png';
  pgm.menu = [
    { text: 'File',
      children: [ { text: 'New...' },
		  { text: 'Open...' },
		  { text: 'Exit Mindows',
		    fn: exitmindows }]
    },
    { text: 'Window',
      children: [ { text: 'Cascade',
		    fn: cascadeall },
		  { text: 'Tile',
		    fn: tileall }]
    },
    { text: 'Help',
      children: [ { text: 'Release Notes',
		    fn: helpviewer },
		  { text: 'About Mindows',
		    fn: aboutmindows }]
    }
  ];

  var games = new Win(120, 220, 420, 130, 'Games');
  games.icons = new IconHolder(300, 180, false);

  var dragicon = new Icon('cardicon.png',
			    '  Dragon Drop',
			    function() {
			      dragondrop();
			    },
			    true);

  var mineicon = new Icon('mineicon.png',
			  '   Minsweeper',
			    function() {
			      minsweeper();
			    },
			    true);

  games.icons.place(dragicon);
  games.icons.place(mineicon);

  // XXX after adding menu, must redraw. Maybe should have
  // setmenu call.
}

function setupgame() {
  setupwindows();
  // XXX also solitaire in front.
}
