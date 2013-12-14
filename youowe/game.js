
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

var PHASE_TITLE = 0, PHASE_PLAYING = 1;
var phase = PHASE_TITLE;

var scrollx = 0;

var images = new Images(
  ['eye.png', // XXX
   'walk1.png',
   'walk2.png',
   'walk3.png',
   'jump.png',
   'blink.png',
   'title.png',
   'classroom.png']);

function SetPhase(p) {
  frames = 0;
  // XXX clear other state

  phase = p;
}

var holdingLeft = false, holdingRight = false,
  holdingUp = false, holdingDown = false,
  holdingSpace = false, holdingEnter = false;

document.onkeydown = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  switch (e.keyCode) {
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
    // TODO z, x, enter
  } 
  var elt = document.getElementById('key');
  elt && (elt.innerHTML = 'key: ' + e.keyCode);
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
  }
  return false;
}

// The 'f' field must be something that you can ctx.drawImage on,
// so an Image or Canvas.
function Frames(arg) {
  if (arg instanceof Image) {
    // Assume static.
    this.frames = [{f: arg, d: 1}];
  } else {
    // Assume list.
    this.frames = arg;
  }
  
  var ct = 0;
  for (var i = 0; i < this.frames.length; i++) {
    ct += this.frames[i].d;
  }
  this.numframes = ct;

  this.GetFrame = function() {
    var f = frames % this.numframes;
    for (var i = 0; i < this.frames.length; i++) {
      if (f < this.frames[i].d) {
	return this.frames[i].f;
      }
      f -= this.frames[i].d;
    }
    return this.frames[0].f;
  };
  this.height = this.frames[0].f.height;
  this.width = this.frames[0].f.width;
  // alert('frame ' + this.width + 'x' + this.height);
}

function Static(f) { return new Frames(images.Get(f)); }
function Room(bg) {
  this.bg = bg;
  this.width = bg.width;
  // ...?
}

// Assumes a list ['frame', n, 'frame', n] ...
// where frame doesn't even have 'png' on it.
// But it must have been loaded into Images.
// TODO: Pass the same list to EzImages or
// something.
function EzFrames(l) {
  if (l.length % 2 != 0) throw 'bad EzFrames';
  var ll = [];
  for (var i = 0; i < l.length; i += 2) {
    var s = l[i];
    var f = null;
    if (typeof s == 'string') {
      f = images.Get(l[i] + '.png');
    } else if (s instanceof Element) {
      // Assume [canvas] or Image
      f = s;
    }
    ll.push({f: f, d: l[i + 1]});
  }
  return new Frames(ll);
}

// Returns a canvas of the same size with the pixels flipped horizontally
function EzFlipHoriz(img) {
  if (typeof img == 'string') img = images.Get(img + '.png');

  var i32 = Buf32FromImage(img);
  var c = NewCanvas(img.width, img.height);
  var ctx = c.getContext('2d');
  var id = ctx.createImageData(img.width, img.height);
  var buf = new ArrayBuffer(id.data.length);
  // Make two aliases of the data, the second allowing us
  // to write 32-bit pixels.
  var buf8 = new Uint8ClampedArray(buf);
  var buf32 = new Uint32Array(buf);

  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      buf32[y * img.width + x] =
	  i32[y * img.width + (img.width - 1 - x)];
    }
  }
  
  id.data.set(buf8);
  ctx.putImageData(id, 0, 0);
  return c;
}

function EzColor(img, shirt, pants) {
  if (typeof img == 'string') img = images.Get(img + '.png');

  var i32 = Buf32FromImage(img);
  var c = NewCanvas(img.width, img.height);
  var ctx = c.getContext('2d');
  var id = ctx.createImageData(img.width, img.height);
  var buf = new ArrayBuffer(id.data.length);
  // Make two aliases of the data, the second allowing us
  // to write 32-bit pixels.
  var buf8 = new Uint8ClampedArray(buf);
  var buf32 = new Uint32Array(buf);

  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      var p = i32[y * img.width + x];
      if (p == 0xFFFF00EA) {
	p = shirt;
      } else if (p == 0xFFF0FF00) {
	p = pants;
      }
      buf32[y * img.width + x] = p;
    }
  }
  
  id.data.set(buf8);
  ctx.putImageData(id, 0, 0);
  return c;
}

function PersonGraphics(shirt, pants) {
  var walk1 = EzColor('walk1', shirt, pants);
  var walk2 = EzColor('walk2', shirt, pants);
  var walk3 = EzColor('walk3', shirt, pants);
  var blink = EzColor('blink', shirt, pants);
  var jump = EzColor('jump', shirt, pants);

  return {
    run_right: EzFrames([walk1, 3, walk2, 2, walk3, 3, walk2, 2]),
    run_left: EzFrames([EzFlipHoriz(walk1), 3, 
			EzFlipHoriz(walk2), 2, 
			EzFlipHoriz(walk3), 3, 
			EzFlipHoriz(walk2), 2]),
    right: EzFrames([walk2, 4 * 30, blink, 2]),
    left: EzFrames([EzFlipHoriz(walk2), 4 * 30, 
		    EzFlipHoriz(blink), 2]),
    jump_right: EzFrames([jump, 1]),
    jump_left: EzFrames([EzFlipHoriz(jump), 1]),
  };
}

function Init() {
  window.rooms = {
    classroom: new Room(Static('classroom.png'))
  };

  window.me = new Human(PersonGraphics(0xFF7FFFFF, 0xFFEC7000));
}

// Sets up the context 
function WarpTo(roomname, x, y) {
  currentroom = roomname;
  me.x = x;
  me.y = y;
  // Keep velocity?
  me.dx = 0;
  me.dy = 0;
}

function TitleStep(time) {
  ctx.drawImage(images.Get('title.png'), 0, 0);
  if (holdingEnter) {
    WarpTo('classroom', 77, 116);
    SetPhase(PHASE_PLAYING);
  }
}

// XXX crop rectangle version?
function DrawFrame(frame, x, y) {
  ctx.drawImage(frame.GetFrame(), Math.round(x), Math.round(y));
}

function Human(gfx) {
  this.gfx = gfx;
  this.x = WIDTH / 2;
  this.y = GAMEHEIGHT / 2;
  // 0 is floor
  this.z = 0;
  this.dx = 0;
  this.dy = 0;
  this.dz = 0;
  this.facingright = true;

  this.Draw = function(scrollx) {
    var fr = this.gfx.right;

    var isjump = this.z > 0.01;

    var isrun = Math.abs(this.dx) > 1 || Math.abs(this.dy) > 0.25;

    // Turn the player around.
    // XXX Also should happen when standing still and first
    // tapping, right? Maybe useful to be able to back up.
    if (!isjump && isrun) {
      // Maybe shouldn't be updating this state in drawing...
      if (this.dx > 1) {
	this.facingright = true;
      } else if (this.dx < -1) {
	this.facingright = false;
      }
    }

    // XXX punching, & so on
    if (this.facingright) {
      if (isjump) {
	fr = this.gfx.jump_right;
      } else {
	fr = isrun ? this.gfx.run_right : this.gfx.right;
      }
    } else {
      if (isjump) {
	fr = this.gfx.jump_left;
      } else {
	fr = isrun ? this.gfx.run_left : this.gfx.left;
      }
    }

    DrawFrame(fr, this.x - scrollx, this.y - this.z + TOP - fr.height);
  };

  // XXX objects should also have physics, using same methods
  this.UpdatePhysics = function() {
    var onground = this.z == 0;

    // Player physics.
    if (this.holdingRight) {
      this.dx += onground ? ACCEL_X : AIR_ACCEL_X;
    } else if (this.holdingLeft) {
      this.dx -= onground ? ACCEL_X : AIR_ACCEL_X;
    } else {
      if (onground) this.dx *= 0.8;
      if (Math.abs(this.dx) < 0.5) this.dx = 0;
    }

    if (this.holdingDown) {
      this.dy += onground ? ACCEL_Y : 0;
    } else if (holdingUp) {
      this.dy -= onground ? ACCEL_Y : 0;
    } else {
      // Always decelerate y, even in air
      this.dy *= 0.6;
      if (Math.abs(this.dy) < 0.5) this.dy = 0;
    }

    if (onground) {
      if (holdingSpace) {
	holdingSpace = false;
	this.dz += JUMP_IMPULSE;
      }
    } else {
      this.dz -= GRAVITY;
    }
    if (Math.abs(this.dz) < 0.01) this.dz = 0;

    if (this.dx > TERMINAL_X) this.dx = TERMINAL_X;
    else if (this.dx < -TERMINAL_X) this.dx = -TERMINAL_X;

    if (this.dy > TERMINAL_Y) this.dy = TERMINAL_Y;
    else if (this.dy < -TERMINAL_Y) this.dy = -TERMINAL_Y;

    if (this.dz > TERMINAL_Z) this.dz = TERMINAL_Z;
    else if (this.dz < -TERMINAL_Z) this.dz = -TERMINAL_Z;

    // XXX collisions.
    this.x += this.dx;
    this.y += this.dy;
    this.z += this.dz;

    if (this.x < 0) {
      // XXX warp left if we can
      this.x = 0;
      this.dx = 0;
    }
    
    if (this.y > GAMEHEIGHT - 1) {
      this.y = GAMEHEIGHT;
      this.dy = 0;
    } else if (this.y < WALLHEIGHT) {
      // XXX should be possible to stand on that stuff maybe?
      this.y = WALLHEIGHT;
      this.dy = 0;
    }


    debug.innerHTML = this.dx + ' ' + this.dy + ' ' + this.dz;

    if (this.z < 0) {
      this.z = 0;
      this.dz = 0;
    }
  };
}

function PlayingStep(time) {
  // XXX once we start scrolling, scroll ahead of
  // where the player's going
  if (me.x < scrollx + 75) scrollx = me.x - 75;
  else if (me.x > scrollx + WIDTH - 125)
    scrollx = me.x - WIDTH + 125;

  // Snap scrollx to background extent
  // XXX if room width is smaller than screen, center.
  if (scrollx + WIDTH > rooms[currentroom].width)
    scrollx = rooms[currentroom].width - WIDTH;
  if (scrollx < 0) scrollx = 0;

  me.holdingRight = holdingRight;
  me.holdingLeft = holdingLeft;
  me.holdingUp = holdingUp;
  me.holdingDown = holdingDown;
  me.holdingSpace = holdingSpace;

  me.UpdatePhysics();

  // Redraw everything every frame (!)
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  DrawFrame(rooms[currentroom].bg, -scrollx, TOP);

  // XXX Draw me (x, y + TOP)

  // DrawFrame(me_gfx.run_right, mex - scrollx, mey + TOP - run_right.height);
  me.Draw(scrollx);
}

last = 0;
function Step(time) {
  // XXX here, throttle to 30 fps or something we
  // should be able to hit on most platforms.
  
  // Word has it that 'time' may not be supported on Safari, so
  // compute our own.
  var now = (new Date()).getTime();
  var diff = now - last;
  // debug.innerHTML = diff;
  // Don't do more than 30fps.
  if (diff < (33.34)) {
    skipped++;
    window.requestAnimationFrame(Step);
    return;
  }
  last = now;
  

  frames++;
  if (frames > 1000000) frames = 0;

  if (phase == PHASE_TITLE) {
    TitleStep();
  } else if (phase == PHASE_PLAYING) {
    PlayingStep();
    

    /*
    // Put pixels
    id.data.set(buf8);
    ctx.putImageData(id, 0, 0);
    */
    /*
    for (var i = 0; i < 1000; i++) {
      var x = 0 | ((f * i) % WIDTH);
      var y = 0 | ((f * 31337 + i) % HEIGHT);
      ctx.drawImage(eye, x - 16, y - 16);
    }
    */
    
    // ...
  }

  // XXX process music


  // On every frame, flip to 4x canvas
  bigcanvas.Draw4x(ctx);

  if (DEBUG) {
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
  phase = PHASE_TITLE;
  start_time = (new Date()).getTime();
  window.requestAnimationFrame(Step);
}

images.WhenReady(Start);
