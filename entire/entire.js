
/* Entire Screen of One Game, made by Tom 7 in a few hours for
   Ludum Dare #31, 7 Dec 2014. */

var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

function XY(x, y) { return '(' + x + ',' + y + ')'; }

FRAMES_UNTIL_BLOCK = 300;
var framesuntilblock = 0;
function Init() {
  // Actually, maybe we should start by spawning a block?
  // framesuntilblock = FRAMES_UNTIL_BLOCK;
  SpawnBlock();
}

function InitYouWin() {
  window.x = 0;
  window.y = 0
  window.c = 0
  window.u = 0;
}

InitYouWin();

function YouWin() {
  // ctx.fillStyle = 'rgba(0, 0, 0, 1)';
  // ctx.fillRect(0, 0, WIDTH, HEIGHT);
  u++;
  for (var i = 0; i < WIDTH * 2; i++) {
    x += u;
    y += x;
    x += 1;
    y += 5;
    x %= WIDTH;
    y %= HEIGHT;

    c += 3;
    c %= 256;

    ctx.fillStyle = 
	'rgba(' + Math.round((x / WIDTH) * 255) + ', ' + 
	Math.round(c) + ', 128, 0.1)';
    ctx.fillRect(x, y, x + 100, y + 100);
  }
}

function Static(x, y, w, h) {
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;
  return this;
}

Static.prototype.x1 = function() { return this.x; }
Static.prototype.x2 = function() { return this.x + this.w; }
Static.prototype.y1 = function() { return this.y; }
Static.prototype.y2 = function() { return this.y + this.h; }
Static.prototype.DebugString = function() {
  return 'Static(' + [this.x, this.y, this.w, this.h].join(',') + ')';
}
Static.prototype.DrawCropped = function(d, osx1, osy1, osx2, osy2,
					sx1, sy1, sx2, sy2,
					fg, bg) {
  // Fortunately, rectangular clipping is easy. We just 
  // use min/max to snap the rectangles into the screen
  // space, which we know.

  var csx1 = Math.max(osx1, sx1);
  var csx2 = Math.min(osx2, sx2);
  var csy1 = Math.max(osy1, sy1);
  var csy2 = Math.min(osy2, sy2);

  ctx.fillStyle = fg;
  ctx.fillRect(csx1, csy1, csx2 - csx1, csy2 - csy1);
};


var staticsquares = [];
(function () {
  for (var i = 0; i < mapsvg.length; i++) {
    // This is imported from map.js, built from the svg file.
    var o = mapsvg[i];
    staticsquares.push(new Static(o.x, o.y, o.w, o.h));
  }
}());

function Dynamic(x, y, w, h, fg, bg, wx, wy, ww, wh) {
  // XXX also needs to know its viewport into the world, and
  // its control attenuation.
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;
  this.fg = fg;
  this.bg = bg;

  this.wx = wx;
  this.wy = wy;
  this.ww = ww;
  this.wh = wh;

  this.dx = 0;
  this.dy = 0;
  return this;
}

Dynamic.prototype.x1 = function() { return this.x; }
Dynamic.prototype.x2 = function() { return this.x + this.w; }
Dynamic.prototype.y1 = function() { return this.y; }
Dynamic.prototype.y2 = function() { return this.y + this.h; }
Dynamic.prototype.DebugString = function() {
  return 'Dynamic(' + [this.x, this.y, this.w, this.h].join(',') + ')';
}
Dynamic.prototype.DrawCropped = function(d,
					 osx1, osy1, osx2, osy2,
					 sx1, sy1, sx2, sy2,
					 fg, bg) {
  var wx = this.wx;
  var wy = this.wy;
  var ww = this.ww;
  var wh = this.wh;

  var osw = (osx2 - osx1) || 1;
  var osh = (osy2 - osy1) || 1;

  if (isNaN(wx) || isNaN(wy) ||
      isNaN(osx1) || isNaN(osy1)) {
    console.log([wx, wy, osx1, osy1].join(' '));
    throw 'Nanzies';
  }

  // cx/cy are the cropped screen coordinates.
  // We crop like anything, and the world ratio will stay the same
  // for the inner drawing. However, if we've chopped from the
  // top or left, then we need to pan the world to compensate.
  var cx1 = osx1;
  if (sx1 > osx1) {
    cx1 = sx1;
    // Horizontal fraction of block lost.
    var sf = (sx1 - osx1) / osw;
    // Shift left edge over and reduce width of world window.
    wx += ww * sf;
    ww -= ww * sf;
  }

  var cy1 = osy1;
  if (sy1 > osy1) {
    cy1 = sy1;
    var sf = (sy1 - osy1) / osh;
    wy += wh * sf;
    wh -= wh * sf;
  }

  // Same can happen here, but we only shrink the width/height
  // in that case; the viewport doesn't shift.
  var cx2 = osx2;
  if (osx2 > sx2) {
    cx2 = sx2;
    // Fraction of block that's outside clip rectangle.
    var sf = (osx2 - sx2) / osw;
    ww -= ww * sf;
  }

  var cy2 = osy2;
  if (osy2 > sy2) {
    cy2 = sy2;
    // Fraction of block that's outside clip rectangle.
    var sf = (osy2 - sy2) / osh;
    wh -= wh * sf;
  }

  // We've become smaller than a pixel, which is the ultimate fate
  // of singularities.
  if ((cx2 - cx1) <= 1 &&
      (cy2 - cy1) <= 1) {
    ctx.fillStyle = '#FF0000';
    ctx.fillRect(cx1, cy1, 1, 1);
    return;
  }

  if (d > 25) {
    console.log('"infinite" recursion? ' +
		' os: ' + [osx1, osy1, osx2, osy2].join(',') +
		' s: ' + [sx1, sy1, sx2, sy2].join(',') +
		' cs: ' + [cx1, cy1, cx2, cy2].join(',') +
		' fg bg: ' + [fg, bg].join(','));

    ctx.fillStyle = '#000000';
    ctx.fillRect(cx1, cy1, cx2 - cx1, cy2 - cy1);
    return;
  }

  // console.log('rec drawworld: ' + newscale);
  DrawWorld(d + 1,
	    this.fg, this.bg,
	    cx1, cy1, cx2, cy2,
	    wx, wy, ww, wh);
};

function ScrollToFit(
  // Current world coordinates -- we don't scroll unless we need to.
  wx, wy,
  // Size of view; can't change here.
  ww, wh,
  // Object with x/y/etc.
  obj) {

  var x1 = obj.x1();  
  var x2 = obj.x2();
  var ow = x2 - x1;

  var y1 = obj.y1();
  var y2 = obj.y2();
  var oh = y2 - y1;
  
  // Sometimes the object will be the entirety of the screen. Need
  // to compute margin dynamically in that case...
  var XMARGIN =
      Math.min(0.33 * ww,
	       (ww - ow) * 0.5);
  var YMARGIN =
      Math.min(0.33 * wh,
	       (wh - oh) * 0.5);

  if (x1 < wx + XMARGIN) {
    wx = x1 - XMARGIN;
    // console.log(ww + ' ' + XMARGIN + ' off left edge: now ' + wx);
  } else if (x2 > (wx + ww) - XMARGIN) {
    // console.log('over by ' + (x2 - ((wx + ww) - XMARGIN)));
    wx += (x2 - ((wx + ww) - XMARGIN));
    // console.log(ww + ' ' + XMARGIN + ' off right edge: now ' + wx);
  }

  if (y1 < wy + YMARGIN) {
    wy = y1 - YMARGIN;
    // console.log(ww + ' ' + YMARGIN + ' off left edge: now ' + wy);
  } else if (y2 > (wy + wh) - YMARGIN) {
    // console.log('over by ' + (y2 - ((wy + ww) - YMARGIN)));
    wy += (y2 - ((wy + wh) - YMARGIN));
    // console.log(ww + ' ' + YMARGIN + ' off right edge: now ' + wy);
  }

  return { x: wx, y: wy };
}

var dynamicobjects = [
  // new Dynamic(215, 525, 24, 24, '#00FF00', '#333333'),
  // new Dynamic(100, 575, 24, 24, '#FFCC00', '#556622')
];

function DrawWorld(
  // Depth, mainly for debugging..
  d,
  // Foreground and background colors.
  fg, bg,
  // Screen coordinates. We do need to do our own clipping.
  sx1, sy1, sx2, sy2,
  // Viewport into world.
  wx1, wy1, ww, wh) {

  var sw = sx2 - sx1;
  var sh = sy2 - sy1;

  if (sw <= 0 || sh <= 0) {
    return;
  }

  var wx2 = wx1 + ww;
  var wy2 = wy1 + wh;

  if (isNaN(wh) || wh == 0) {
    // HERE prolly zero
    console.log([sx1, sy1, sx2, sy2]);
    throw ('aha! ' + wh + ' at depth ' + d);
  }

  // Coordinate transforms.
  var wxtosx = function(wx) {
    var wo = wx - wx1;
    var wf = wo / ww;
    return Math.round(sx1 + sw * wf);
  };

  var wytosy = function(wy) {
    var wo = wy - wy1;
    var wf = wo / wh;
    return Math.round(sy1 + sh * wf);
  };

  // var wx2 = wxtosx(sx2);
  // var wy2 = wytosy(sy2);

  var DO = function(obj) {
    // console.log('on screen? ' + XY(sx1, sy1) + ' to ' + XY(sx2, sy2));
    // console.log(obj.DebugString());
    
    // First, discard the object if it's completely 
    // outside our screen rectangle. We do all clipping
    // in screen coordinates, because we don't want
    // anything poking in/out one pixel on our nice
    // rectangles.
    var osx1 = wxtosx(obj.x1());
    if (osx1 > sx2) return;
    var osx2 = wxtosx(obj.x2());
    if (osx2 < sx1) return;
    var osy1 = wytosy(obj.y1());
    if (isNaN(osy1)) throw osy1;
    if (osy1 > sy2) return;
    var osy2 = wytosy(obj.y2());
    if (osy2 < sy1) return;

    // Objects only need to know where to draw themselves
    // on the screen, as well as the crop rectangle.
    obj.DrawCropped(d + 1, osx1, osy1, osx2, osy2,
		    sx1, sy1, sx2, sy2,
		    fg, bg);
  };

  // Start by drawing the background color in the entire
  // rectangle.
  ctx.fillStyle = bg;
  ctx.fillRect(sx1, sy1, sx2 - sx1, sy2 - sy1);

  for (var o in staticsquares) DO(staticsquares[o]);
  // And dynamic objects...
  for (var o in dynamicobjects) DO(dynamicobjects[o]);
}

var xpos = 0;
var ypos = 500;
var wpos = WIDTH / 3;
var hpos = HEIGHT / 3;
var scale = 1; // 3.0;
function Draw() {
  // Scroll each block to fit the one inside it.
  for (var i = 1; i < dynamicobjects.length; i++) {
    var inner = dynamicobjects[i - 1];
    var outer = dynamicobjects[i];
    var v = ScrollToFit(outer.wx, outer.wy,
			outer.ww, outer.wh,
			inner);
    outer.wx = v.x;
    outer.wy = v.y;
  }

  // Now, scroll the screen to fit the last object.
  var cur = dynamicobjects[dynamicobjects.length - 1];
  if (!holdingShift) {
    var view = ScrollToFit(xpos, ypos, 
			   wpos, hpos,
			   cur);
    xpos = view.x;
    ypos = view.y;
  }

  // And draw the world to fit the screen.
  DrawWorld(0, '#FFFFFF', '#0000FF',
	    0, 0, WIDTH, HEIGHT,
	    xpos, ypos, wpos, hpos);
}

function DumpPos() {
  console.log('var xpos = ', xpos, ', ypos = ', ypos, 
	      /* ', scale = ', scale, */
	      ';');
}

function move1DClip(obj, pos, dpos, f) {
  var newpos = pos + dpos;

  // XXX probably should check invariant since it can probably 
  // be violated in rare cases (fp issues).
  if (f(obj, newpos)) {

    // invariant: pos is good, newpos is bad
    // XXX EPSILON?
    while (Math.abs(newpos - pos) > .01) {
      var mid = (newpos + pos) / 2;
      if (f(obj, mid)) {
        newpos = mid;
      } else {
        pos = mid;
      }
    }

    return { pos : pos, dpos : 0 };
  } else {
    return { pos : newpos, dpos : dpos };
  }
}

function DoPhysics(rank, obj) {

  var PointBlocked = function(x, y, w) {
    var Test = function(b) {
      if (b == obj) return false;
      return x >= b.x1() && x <= b.x2() &&
             y >= b.y1() && y <= b.y2();
    };

    for (var o in dynamicobjects) 
      if (Test(dynamicobjects[o]))
	return true;
    for (var o in staticsquares) 
      if (Test(staticsquares[o]))
	return true;
  };

  var WidthBlocked = function(x, y, w) {
    return PointBlocked(x, y) || PointBlocked(x + w, y) ||
	PointBlocked(x + (w * 0.5), y);
  };

  var HeightBlocked = function(x, y, h) {
    return PointBlocked(x, y) || PointBlocked(x, y + h) ||
      PointBlocked(x, y + (h / 2));
  };

  var CORNER = 0;
  // PERF these already need to capture obj to run widthblocked,
  // so don't bother passing it as a parameter too.
  var BlockedUp = function(obj, newy) {
    var yes = WidthBlocked(obj.x + obj.w * CORNER,
			   newy,
			   obj.w * (1 - 2 * CORNER));
    // XXX Probably unused?
    // collision_up = collision_up || yes;
    return yes;
  };

  var BlockedDown = function(obj, newy) {
    var yes = WidthBlocked(obj.x + obj.w * CORNER,
			   newy + obj.h,
			   obj.w * (1 - 2 * CORNER));
    // collision_down = collision_down || yes;
    return yes;
  };

  var BlockedLeft = function(obj, newx) {
    var yes = HeightBlocked(newx, 
                            obj.y + obj.h * CORNER, 
                            obj.h * (1 - 2 * CORNER));
    // collision_left = collision_left || yes;
    return yes;
  };

  var BlockedRight = function(obj, newx) {
    var yes = HeightBlocked(newx + obj.w, 
                            obj.y + obj.h * CORNER, 
                            obj.h * (1 - 2 * CORNER));
    // collision_right = collision_right || yes;
    return yes;
  };

  var att = 1 / (1 + rank);

  var oy = move1DClip(obj,
		      obj.y, obj.dy * att,
		      (obj.dy < 0) ? BlockedUp : BlockedDown);
  obj.y = oy.pos;
  obj.dy = oy.dpos / att;

  // Now x:
  var ox = move1DClip(obj, obj.x, obj.dx * att,
		      (obj.dx < 0) ? BlockedLeft : BlockedRight);
  obj.x = ox.pos;
  obj.dx = ox.dpos / att;

  // The effect of physics needs to be determined by the depth
  // of the block... TODO!
  var C = {
    accel: 3,
    decel_ground: 0.95,
    decel_air: 0.05,
    jump_impulse: 11.8,
    gravity: 1.0,
    terminal_velocity: 9,
    maxspeed: 5.9
  };

  var GROUND_SLOP = 2.0;
  var OnTheGround = function() {
    // XXX just used blockeddown?
    // in the starting arrangement you can't jump with the left guy.
    return WidthBlocked(obj.x + obj.w * 0.1,
                        obj.y + obj.h + GROUND_SLOP,
                        obj.w * 0.8);
  };


  var otg = OnTheGround();

  if (otg && holdingSpace) {
    obj.dy = -C.jump_impulse;
  }

  if (holdingRight) {
    obj.dx += C.accel * att;
    if (obj.dx > C.maxspeed) obj.dx = C.maxspeed;
  } else if (holdingLeft) {
    obj.dx -= C.accel * att;
    if (obj.dx < -C.maxspeed) obj.dx = -C.maxspeed;
  } else {
    // If not holding either direction,
    // slow down and stop (quickly)
    if (otg) {
      // On the ground, slow to a stop very quickly
      if (obj.dx > C.decel_ground) obj.dx -= C.decel_ground * att;
      else if (obj.dx < -C.decel_ground) obj.dx += C.decel_ground * att;
      else obj.dx = 0;
    } else {
      // In the air, not so much.
      if (obj.dx > C.decel_air) obj.dx -= C.decel_air * att;
      else if (obj.dx < -C.decel_air) obj.dx += C.decel_air * att;
      else obj.dx = 0;
    }
  }

  if (otg) {

  } else {
    obj.dy += C.gravity * att;
    if (obj.dy > C.terminal_velocity / att) {
      // console.log('term');
      obj.dy = C.terminal_velocity;
    }
  }

}

function ZoomOut() {
  var amount = 0.004 * wpos;
  xpos -= amount;
  ypos -= amount;
  wpos += 2 * amount;
  hpos += 2 * amount;
}

function ZoomIn() {
  var amount = 0.005 * wpos;
  xpos += amount;
  ypos += amount;
  wpos -= 2 * amount;
  hpos -= 2 * amount;
}

function Physics() {
  if (holdingShift) {
    if (holdingLeft) xpos -= 5;
    else if (holdingRight) xpos += 5;
    if (holdingUp) ypos -= 5;
    else if (holdingDown) ypos += 5;
    if (holdingPlus) ZoomIn();
    else if (holdingMinus) ZoomOut();
    return;
  }
  
  // Count, maybe generate new block.
  if (framesuntilblock == 0) {
    SpawnBlock();
  } else {
    framesuntilblock--;
    // Zoom out a little.
    ZoomOut();
  }

  for (var i = 0; i < dynamicobjects.length; i++) {
    var rank = (dynamicobjects.length - 1) - i;
    DoPhysics(rank, dynamicobjects[i]);
  }
}

// XXX more colors, including FG changes...
var nextcolor = 0;
var COLORS = [
  '#00FF00',
  '#FF0000',
  '#000077',
  '#777700',
  '#FF00FF',
  '#00FFFF'
];

function SpawnBlock() {
  // Put a viewport into the world with whatever our current
  // view is.
  dynamicobjects.push(
    new Dynamic(48, 12, 24, 24, '#FFFFFF', COLORS[nextcolor],
		xpos, ypos,
		wpos, hpos));
  // And then look exactly at the block.
  xpos = 48;
  ypos = 12;
  wpos = 24;
  hpos = 24;
  // scale = WIDTH / 24;

  nextcolor++;
  nextcolor %= COLORS.length;
  console.log('spawned! now ' + dynamicobjects.length);
  framesuntilblock = FRAMES_UNTIL_BLOCK;
}

last = 0;
function Step(time) {
  // Throttle to 30 fps or something we
  // should be able to hit on most platforms.
  // Word has it that 'time' may not be supported on Safari, so
  // compute our own. (TODO: use performance.now probably)
  var now = (new Date()).getTime();
  var diff = now - last;
  // debug.innerHTML = diff;
  // Don't do more than 30fps.
  if (diff < MINFRAMEMS) {
    skipped++;
    window.requestAnimationFrame(Step);
    return;
  }
  last = now;

  frames++;
  if (frames > 1000000) frames = 0;

  Physics();

  Draw();

  if (false && DEBUG) {
    counter++;
    var sec = ((new Date()).getTime() - start_time) / 1000;
    document.getElementById('counter').innerHTML =
        'skipped ' + skipped + ' drew ' +
        counter + ' (' + (counter / sec).toFixed(2) + ' fps)';
  }

  // And continue the loop...
  window.requestAnimationFrame(Step);
}

function Start() {
  Init();

  window.requestAnimationFrame(Step);
}

var holdingShift = false,
  holdingLeft = false, holdingRight = false,
  holdingUp = false, holdingDown = false,
  holdingSpace = false, holdingEnter = false,
  holdingX = false, holdingZ = false,
  holdingPlus = false, holdingMinus = false;

document.onkeydown = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  switch (e.keyCode) {
    case 9:  // tab?
    // CHEATS
    // if (true || DEBUG)
    // textpages = [];
    // XXX CHEAT
    SpawnBlock();

    break;
    case 27: // ESC
    if (true || DEBUG) {
      document.body.innerHTML =
	  '<b style="color:#fff;font-size:40px">(SILENCED. ' +
          'RELOAD TO PLAY)</b>';
      Step = function() { };
      // n.b. javascript keeps running...
    }
    case 8: // BACKSPACE
    if (DEBUG) {
      gang = null;
    }
    break;
    case 37: // LEFT
    holdingLeft = true;
    break;
    case 38: // UP
    holdingUp = true;
    break;
    case 39: // RIGHT
    holdingRight = true;
    break;
    case 40: // DOWN
    holdingDown = true;
    break;
    case 32: // SPACE
    holdingSpace = true;
    break;
    case 13: // ENTER
    holdingEnter = true;
    break;
    case 90: // Z
    holdingZ = true;
    break;
    case 88: // X
    holdingX = true;
    break;
    case 187: // +/=
    holdingPlus = true;
    break;
    case 189: // -/_
    holdingMinus = true;
    break;
    case 16: // shift
    holdingShift = true;
    break;
    default:
    // console.log(e.keyCode);
  } 
  // var elt = document.getElementById('key');
  // elt && (elt.innerHTML = 'key: ' + e.keyCode);
  return false;
}

document.onkeyup = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  switch (e.keyCode) {
    case 37: // LEFT
    holdingLeft = false;
    break;
    case 38: // UP
    holdingUp = false;
    break;
    case 39: // RIGHT
    holdingRight = false;
    break;
    case 40: // DOWN
    holdingDown = false;
    break;
    case 32: // SPACE
    holdingSpace = false;
    break;
    case 13: // ENTER
    holdingEnter = false;
    break;
    case 90: // Z
    holdingZ = false;
    break;
    case 88: // X
    holdingX = false;
    break;
    case 187: // +/=
    holdingPlus = false;
    break;
    case 189: // -/_
    holdingMinus = false;
    break;
    case 16:
    holdingShift = false;
    break;
  }
  return false;
}

// resources.WhenReady(Start);
Start();

