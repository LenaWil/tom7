
var counter = 0;
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
  alert('frame ' + this.width + 'x' + this.height);
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
    ll.push({f: images.Get(l[i] + '.png'), d: l[i + 1]});
  }
  return new Frames(ll);
}

function Init() {
  window.rooms = {
    classroom: new Room(Static('classroom.png'))
  };

  // XXX need to face left, right, recolor
  window.run_right = EzFrames(['walk1', 3, 'walk2', 2, 'walk3', 3,
			'walk2', 2]);

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
  DrawFrame(run_right, mex - scrollx, mey + TOP - run_right.height);
}

function Step(time) {
  // XXX here, throttle to 30 fps or something we
  // should be able to hit on most platforms.
  frames++;
  if (frames > 1000000) frames = 0;

  if (phase == PHASE_TITLE) {
    TitleStep(time);
  } else if (phase == PHASE_PLAYING) {
    PlayingStep(time);
    

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
	'' + counter + ' (' + (counter / sec).toFixed(2) + ' fps)';
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
