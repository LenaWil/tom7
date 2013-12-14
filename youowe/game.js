
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

var PHASE_TITLE = 0, PHASE_PLAYING = 1;
var phase = PHASE_TITLE;

var mex = 0, mey = 0;

var images = new Images(
  ['eye.png', // XXX
   'walk1.png',
   'walk2.png',
   'walk3.png',
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
function FlipHoriz(img) {
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

function EzFlip(f) {
  if (typeof f == 'string') f = images.Get(f + '.png');
  return FlipHoriz(f);
}

function PersonGraphics(shirt, pants) {
  return {
    run_right: EzFrames(['walk1', 3, 'walk2', 2, 'walk3', 3,
			 'walk2', 2]),
    right: EzFrames(['walk2', 4 * 30, 'blink', 2]),
    left: EzFrames([EzFlip('walk2'), 4 * 30, 
		    EzFlip('blink'), 2])
  };
}

function Init() {
  window.rooms = {
    classroom: new Room(Static('classroom.png'))
  };

  // XXX need to face left, right, recolor
  window.me_gfx = PersonGraphics(0xFFFFFFFF, 0xFFEC7000);

}

// Sets up the context 
function WarpTo(roomname, x, y) {
  currentroom = roomname;
  mex = x;
  mey = y;
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
  ctx.drawImage(frame.GetFrame(), x, y);
}

function PlayingStep(time) {
  // XXX Compute scrollx...
  scrollx = 0;

  // Redraw everything every frame (!)
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  DrawFrame(rooms[currentroom].bg, -scrollx, TOP);

  // XXX Draw me (x, y + TOP)

  // DrawFrame(me_gfx.run_right, mex - scrollx, mey + TOP - run_right.height);
  DrawFrame(me_gfx.left, mex - scrollx, mey + TOP - ME_HEIGHT);
}

last = 0;
function Step(time) {
  // XXX here, throttle to 30 fps or something we
  // should be able to hit on most platforms.
  
  // Word has it that 'time' may not be supported on Safari, so
  // compute our own.
  var now = (new Date()).getTime();
  var diff = now - last;
  debug.innerHTML = diff;
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
