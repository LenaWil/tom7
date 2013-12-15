
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

var PHASE_TITLE = 0, PHASE_PLAYING = 1;
var phase = PHASE_TITLE;

var scrollx = 0;

var images = new Images(
  ['eye.png', // XXX
   'font.png',
   'walk1.png',
   'walk2.png',
   'walk3.png',
   'jump.png',
   'blink.png',
   'punch.png',
   'punch2.png',
   'kick.png',
   'kick2.png',
   'ouch.png',
   'stunned.png',
   'title.png',
   'dead.png',
   'blank.png',
   'classroom.png',
   'classroom-mask.png']);

function SetPhase(p) {
  frames = 0;
  // XXX clear other state

  phase = p;
}

var holdingLeft = false, holdingRight = false,
  holdingUp = false, holdingDown = false,
  holdingSpace = false, holdingEnter = false,
  holdingX = false, holdingZ = false;

document.onkeydown = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  switch (e.keyCode) {
    case 8: // BACKSPACE;
    if (DEBUG)
      gang = null;
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
    case 90: // Z
    holdingZ = false;
    break;
    case 88: // X
    holdingX = false;
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

  this.GetFrame = function(idx) {
    var f = idx % this.numframes;
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
var MASK_CLEAR = 0, MASK_CLIP = 1, MASK_LEDGE = 2;
function Room(bg, mask) {
  this.bg = bg;
  this.width = bg.width;
  this.mask_debug = images.Get(mask);
  this.mask = Buf32FromImage(images.Get(mask));
  // ...?
  this.MaskAt = function(x, y) {
    x = Math.round(x);
    y = Math.round(y);

    // Can't leave screen?
    if (x < 0 || y < 0 || x >= this.width || y >= this.height)
      return MASK_CLIP;

    var p = this.mask[this.width * y + x];
    console.log(x + ' ' + y + ': ' + p);
    if ((p >> 24) > 10) {
      // Assuming just magenta and green, resp.
      if (p & 255 > 10) return MASK_CLIP;
      else return MASK_LEDGE;
    } else {
      return MASK_CLEAR;
    }
  };
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
  var punch = EzColor('punch', shirt, pants);
  var punch2 = EzColor('punch2', shirt, pants);
  var kick = EzColor('kick', shirt, pants);
  var kick2 = EzColor('kick2', shirt, pants);
  var dead = EzColor('dead', shirt, pants);
  var ouch = EzColor('ouch', shirt, pants);
  var stunned = EzColor('stunned', shirt, pants);

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
    punch_right: EzFrames([punch, 2, punch2, 30]),
    punch_left: EzFrames([EzFlipHoriz(punch), 2, 
			 EzFlipHoriz(punch2), 30]),
    kick_right: EzFrames([kick, 2, kick2, 30]),
    kick_left: EzFrames([EzFlipHoriz(kick), 2, 
			 EzFlipHoriz(kick2), 30]),
    // For actually dying, can flicker
    ko_right: EzFrames([dead, 1]),
    ko_left: EzFrames([EzFlipHoriz(dead), 1]),

    dead_right: EzFrames([dead, 2, 'blank', 2]),
    dead_left: EzFrames([EzFlipHoriz(dead), 2, 'blank', 2]),

    hurt_right: EzFrames([ouch, 1, stunned, 1]),
    hurt_left: EzFrames([EzFlipHoriz(ouch), 1, 
			 EzFlipHoriz(stunned), 1])
  };
}

function Init() {
  window.rooms = {
    classroom: new Room(Static('classroom.png'),
			'classroom-mask.png')
  };

  window.me = new Human(PersonGraphics(0xFF7FFFFF, 0xFFEC7000));
  window.font = new Font(images.Get('font.png'),
			 FONTW, FONTH, FONTOVERLAP, FONTCHARS);
}

// Sets up the context 
function WarpTo(roomname, x, y) {
  currentroom = rooms[roomname];
  me.x = x;
  me.y = y;
  // Keep velocity?
  me.dx = 0;
  me.dy = 0;

  // Room needs to define a spawn spot or something.
  gang = new Gang(4, 0xFF123456, 0xFF987654);
}

function TitleStep(time) {
  UpdateSong();
  ctx.drawImage(images.Get('title.png'), 0, 0);
  if (holdingEnter) {
    ClearSong();
    WarpTo('classroom', 77, 116);
    SetPhase(PHASE_PLAYING);
  }
}

// XXX crop rectangle version?
function DrawFrame(frame, x, y, opt_fc) {
  ctx.drawImage(frame.GetFrame(arguments.length > 3 ? opt_fc : frames), 
		Math.round(x), Math.round(y));
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

  this.hp = 20;

  this.punching = 0;
  this.kicking = 0;
  this.ko = 0;
  this.hurt = 0;

  // frame counter.
  this.fc = 0;

  this.Depth = function() {
    return this.y;
  }

  this.Draw = function(scrollx) {
    var fr = this.gfx.right;

    var isjump = this.z > 0.01;

    var isrun = Math.abs(this.dx) > 1 || Math.abs(this.dy) > 0.25;

    if (this.ko > 0) {
      // XXX check if really dying
      if (this.hp <= 0) {
	fr = this.facingright ? this.gfx.dead_right : this.gfx.dead_left;
      } else {
	fr = this.facingright ? this.gfx.ko_right : this.gfx.ko_left;
      } 

    } else if (this.hurt > 0) {
      fr = this.facingright ? this.gfx.hurt_right : this.gfx.hurt_left;

    } else {
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

      // XXX kicking, air attacks
      if (this.facingright) {
	if (isjump) {
	  // XXX air attacks
	  fr = this.gfx.jump_right;
	} else {
	  if (this.punching > 0) {
	    fr = this.gfx.punch_right;
	  } else if (this.kicking > 0) {
	    fr = this.gfx.kick_right;
	  } else {
	    fr = isrun ? this.gfx.run_right : this.gfx.right;
	  }
	}
      } else {
	if (isjump) {
	  // XXX air attacks
	  fr = this.gfx.jump_left;
	} else {
	  if (this.punching > 0) {
	    fr = this.gfx.punch_left;
	  } else if (this.kicking > 0) {
	    fr = this.gfx.kick_left;
	  } else {
	    fr = isrun ? this.gfx.run_left : this.gfx.left;
	  }
	}
      }
    }
    DrawFrame(fr, this.x - scrollx - fr.width / 2, this.y - this.z + TOP - fr.height,
	      this.fc);
    this.fc++;
  };

  // XXX objects should also have physics, using some of the same methods
  this.UpdatePhysics = function(objects) {
    var onground = this.z == 0;

    // XX no air attacks implemented. But allow them
    var canattack = this.hurt == 0 && this.ko == 0 && onground;

    if (!canattack) {
      // For example if killed while throwing a punch.
      this.punching = 0;
      this.kicking = 0;

    } else if (this.punching == 0 &&
	       this.kicking == 0) {
      if (this.holdingX) {
	// Depending on air/floor?
	this.punching = PUNCHFRAMES;
	// Need to reset animation offset when starting a
	// non-looping pose like this.
	this.fc = 0;
      } else if (this.holdingZ) {
	this.kicking = KICKFRAMES;
	this.fc = 0;
      }

    } else if (this.punching > 0) {
      this.punching--;

    } else if (this.kicking > 0) {
      this.kicking--;
    }

    if (this.ko > 0) {
      this.ko --;

    } else if (this.hurt > 0) {
      this.hurt --;

    }

    // Kicking makes you stop.
    var canmove = this.ko == 0;
    var canrun = canmove && (this.kicking == 0 || !onground);

    var kick_now = this.kicking == 2;
    var punch_now = this.punching == 2;
    // Dealing damage.
    if (punch_now || kick_now) {
      // Check non-self objects for hit.
      var ax = this.x + (this.facingright ? ATTACKSIZE_X : -ATTACKSIZE_X);
      for (var i = 0; i < objects.length; i++) {
	if (objects[i] != this) {
	  if (Math.abs(objects[i].y - this.y) <= ATTACKSIZE_Y &&
	      Math.abs(objects[i].x - ax) <= HALFPERSON_W) {
	    // Hit! But are we allowed to hit them?
	    // XXX
	    if (objects[i].x < this.x) {
	      objects[i].dx -= 4;
	    } else {
	      objects[i].dx += 4;
	    }

	    if (punch_now) {
	      objects[i].hp -= PUNCH_DAMAGE;
	    } else if (kick_now) {
	      objects[i].hp -= KICK_DAMAGE;
	    }

	    if (Math.random() < 0.1) {
	      objects[i].ko = objects[i].hp <= 0 ? DEADFRAMES : KOFRAMES;
	      objects[i].fc = 0;
	    } else {
	      objects[i].hurt = HURTFRAMES;
	      objects[i].fc = 0;
	    }
	  }
	}
      }
    }

    // XXX being hurt should interfere somewhat?
    
    // Player physics.
    if (canmove && canrun && this.holdingRight) {
      this.dx += onground ? ACCEL_X : AIR_ACCEL_X;
    } else if (canmove && canrun && this.holdingLeft) {
      this.dx -= onground ? ACCEL_X : AIR_ACCEL_X;
    } else {
      if (onground) this.dx *= 0.8;
      if (Math.abs(this.dx) < 0.5) this.dx = 0;
    }

    if (canmove && this.holdingDown) {
      this.dy += onground ? ACCEL_Y : 0;
    } else if (canmove && holdingUp) {
      this.dy -= onground ? ACCEL_Y : 0;
    } else {
      // Always decelerate y, even in air
      this.dy *= 0.6;
      if (Math.abs(this.dy) < 0.5) this.dy = 0;
    }

    if (onground) {
      if (canmove && this.holdingSpace) {
	// XXX this won't work, it's an alias.
	// this.holdingSpace = false;
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

    // x is simple
    if (this.dx != 0) {
      var startmask = currentroom.MaskAt(this.x, this.y);
      // unit dx, either 1 or -1
      var ux = this.dx / Math.abs(this.dx);
      // console.log(ux);

      // As we enter the loop, this.x will be in a valid location.
      for (var i = 0; Math.abs(i) < Math.abs(this.dx); i += ux) {
	var m = currentroom.MaskAt(this.x + ux, this.y);
	console.log(m);
	// XXX actually should allow this from a ledge; then
	// you convert y to z and fall.
	if (m == MASK_CLIP) break;
	// Can't walk onto ledge.
	if (m == MASK_LEDGE && m != startmask) break;
	this.x += ux;
      }
    }

    // y is easy too, though we need to allow converting down
    if (this.dy != 0) {
      var startmask = currentroom.MaskAt(this.x, this.y);
      var uy = this.dy / Math.abs(this.dy);

      for (var i = 0; Math.abs(i) < Math.abs(this.dy); i += uy) {
	var m = currentroom.MaskAt(this.x, this.y + uy);
	console.log(m);
	// XXX actually should allow this from a ledge; then
	// you convert y to z and fall.
	if (m == MASK_CLIP) break;
	// Can't walk onto ledge.
	if (m == MASK_LEDGE && m != startmask) break;
	this.y += uy;
      }
    }
    
    this.z += this.dz;

    // XXX maybe don't need if we use mask? -- or warps only?
    if (this.x < 0) {
      // XXX warp left if we can
      this.x = 0;
      this.dx = 0;
    }
    
    if (this.y > GAMEHEIGHT) {
      this.y = GAMEHEIGHT;
      this.dy = 0;
    } else if (this.y < WALLHEIGHT) {
      // XXX should be possible to stand on that stuff maybe?
      this.y = WALLHEIGHT;
      this.dy = 0;
    }

    debug.innerHTML = this.dx + ' ' + this.dy + ' ' + this.dz +
	' @ ' + this.x + ' ' + this.y + ' ' + this.z +
	(this.punching > 0 ? (' punching ' + this.punching) : '') +
	(this.facingright ? ' >' : ' <');

    if (this.z < 0) {
      this.z = 0;
      this.dz = 0;
    }
  };

}

// TODO: fighting style, hats, and so on.
function Gang(n, shirt, pants) {
  var NATTACKERS = 2;

  // Or get stuff, etc.
  var S_ATTACK = 0, S_CONFRONT = 1; // , S_AVOID = 2;

  this.humans = [];
  var gfx = PersonGraphics(shirt, pants);
  for (var i = 0; i < n; i++) {
    var h = new Human(gfx);
    h.strategy = S_CONFRONT;
    this.humans.push(h);
  }
  
  this.AddObjects = function(l) {
    for (var i = 0; i < this.humans.length; i++) {
      l.push(this.humans[i]);
    }
  };

  this.Reap = function() {
    for (var i = 0; i < this.humans.length; i++) {
      var h = this.humans[i];
      if (h.ko == 1 && h.hp <= 0) {
	// Dead!
	this.humans.splice(i, 1);
	i--;
      }
    }
    
    if (this.humans.length > 0) return this;
    else return null;
  };
  
  this.UpdateStrategies = function() {

    // Maybe change strategies.
    // Nobody attack when I'm on the ground.
    if (me.ko > 0) {
      for (var i = 0; i < this.humans.length; i++) {
	this.humans[i].strategy = S_CONFRONT;
      }
    } else {
      // Are enough people attacking?
      var na = 0;
      for (var i = 0; i < this.humans.length; i++) {
	if (this.humans[i].strategy == S_ATTACK) {
	  na++;
	}
      }

      if (na < NATTACKERS) {
	// Someone becomes an attacker (possibly someone
	// who already was..)
	var i = Math.round(Math.random() * (this.humans.length - 1));
	console.log(na + ' so making #' + i + ' an attacker');
	this.humans[i].strategy = S_ATTACK;
      }
    }

    // Implement strategies.
    for (var i = 0; i < this.humans.length; i++) {
      var human = this.humans[i];
      // Figure out our destination.
      var destx = 0, desty = 0;
      switch (human.strategy) {
	case S_ATTACK:
	// Pick one side or the other of me.
	if (typeof human.attack_right != 'boolean') {
	  human.attack_right = Math.random() > 0.5;
	}
	destx = me.x + (human.attack_right ? ATTACKSIZE_X : -ATTACKSIZE_X);
	desty = me.y;
	break;
	case S_CONFRONT:
	if (!human.confront_vec) {
	  // Pick a random normalized vector.
	  // (It doesn't matter, but maybe this is not uniform)
	  var xx = Math.random() - 0.5, yy = Math.random() - 0.5;
	  var d = Math.sqrt(xx * xx + yy * yy);
	  xx /= d; yy /= d;
	  human.confront_vec = {x: xx, y: yy};
	}
	
	// XXX: This should change based on how the fight is going,
	// I think.
	var confront_dist_x = 100;
	var confront_dist_y = 24;
	var cv = human.confront_vec;
	destx = Math.round(me.x + cv.x * confront_dist_x);
	desty = Math.round(me.x + cv.y * confront_dist_y);

	break;
      }
      
      // XXX snap destx, desty to be within level?
      // physics will do this for us, but it's maybe
      // just smarter AI to only try to get to sensible
      // places?

      var xdist = Math.abs(destx - human.x);


      // allow turning around too
      human.holdingRight = (human.x < destx) && xdist > 16;
      human.holdingLeft = (human.x > destx) && xdist > 16;

      // XXX This doesn't work. Fix it!
      /* 
	var facingme = human.facingRight ? (human.x < me.x) : (human.x > me.x);
      if (!(human.holdingRight ||
	    human.holdingLeft)) {
	if (!facingme) {
	  if (human.x < me.x) {
	    human.holdingRight = true;
	  } else if (human.x > me.x) {
	    human.holdingLeft = true;
	  }
	}
      }
      */

      human.holdingDown = (human.y < desty);
      human.holdingUp = (human.y > desty);

      // When to jump?
      human.holdingSpace = (Math.random() < 0.025);

      // XXX based on strategy. Don't be so crazy active
      // when confronting
      human.holdingX = Math.random() < 0.05;
      human.holdingY = Math.random() < 0.05;
    }
  };

  this.UpdatePhysics = function(objects) {
    for (var i = 0; i < this.humans.length; i++) {
      // not the best strategy
      this.humans[i].UpdatePhysics(objects);
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
  if (scrollx + WIDTH > currentroom.width)
    scrollx = currentroom.width - WIDTH;
  if (scrollx < 0) scrollx = 0;

  var objects = [];
  if (gang) gang.AddObjects(objects);
  objects.push(me);

  me.holdingRight = holdingRight;
  me.holdingLeft = holdingLeft;
  me.holdingUp = holdingUp;
  me.holdingDown = holdingDown;
  me.holdingSpace = holdingSpace;

  me.holdingZ = holdingZ;
  me.holdingX = holdingX;

  me.UpdatePhysics(objects);

  if (gang) {
    gang.UpdateStrategies();
    gang.UpdatePhysics(objects);
    gang = gang.Reap();
  }

  // Redraw everything every frame (!)
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  DrawFrame(currentroom.bg, -scrollx, TOP);
  // XXX no!
  if (DEBUG)
    ctx.drawImage(currentroom.mask_debug, -scrollx, TOP);

  objects.sort(function (a, b) { return b.Depth () < a.Depth(); });
  for (var i = 0; i < objects.length; i++) {
    objects[i].Draw(scrollx);
  }

  // XXX Handle case where I die!

  // XXX real text status
  font.Draw(ctx, 2, 2, 'HP: ' + me.hp);
  font.Draw(ctx, 160, 2, 'arrows/z/x/space');
  font.Draw(ctx, 10, TOP + GAMEHEIGHT,
	    'Me: BARF!!!\n' +
	    ' ... ' + frames);
}

last = 0;
function Step(time) {
  // Throttle to 30 fps or something we
  // should be able to hit on most platforms.
  // Word has it that 'time' may not be supported on Safari, so
  // compute our own.
  var now = (new Date()).getTime();
  var diff = now - last;
  // debug.innerHTML = diff;
  // Don't do more than 30fps.
  // XXX This results in a frame rate of 21 on RIVERCITY, though
  // I can easil get 60, so what gives?
  if (diff < MINFRAMEMS) {
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
  StartSong(overworld);
  window.requestAnimationFrame(Step);
}

images.WhenReady(Start);
