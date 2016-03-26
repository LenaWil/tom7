
var frames = 0;

function Init() {
  bufb = new ArrayBuffer(id.data.length);
  bufb8 = new Uint8ClampedArray(bufb);
  bufb32 = new Uint32Array(bufb);
}

var theta = 0;

// These are 0xAABBGGRR.

var EMPTY = 0x00000000;
var FRONTIER = 0xFF004400;
var CORE = 0xFF00FFFF;
var SUBSTRATE = 0xFF003333;

var PADDLE = 0xFF0000FF;
    
var PI2 = Math.PI * 2;
function Physics() {
  if (holdingLeft) theta -= (Math.PI / 20);
  else if (holdingRight) theta += (Math.PI / 20);
  theta = (PI2 + theta) % PI2;

  var inAngle = function(rads) {
    rads = (PI2 + rads) % PI2;
    var tmin = (PI2 + theta - Math.PI / 8) % PI2;
    var tmax = (PI2 + theta + Math.PI / 8) % PI2;
    // console.log('' + tmin + ' < ' + rads + ' < ' + tmax);
    if (tmin < tmax) {
      return rads >= tmin && rads <= tmax;
    } else {
      return rads >= tmin || rads <= tmax;
    }
  };
  
  //  inAngle(0, true);

  var src32, dst32, src8, dst8;
  if (frames % 2) {
    src32 = buf32;
    src8 = buf8;
    dst32 = bufb32;
    dst8 = bufb8;
  } else {
    src32 = bufb32;
    src8 = bufb8;
    dst32 = buf32;
    dst8 = buf8;
  }
  
  for (var y = 0; y < HEIGHT; y++) {
    for (var x = 0; x < WIDTH; x++) {
      var a = 0, b = 0, c = 0, d = 0, e = 0, f = 0, g = 0, h = 0;
      // a b c
      // d   e
      // f g h
      
      if (y > 0) {
	x > 0 && (a = src32[x - 1 + (y - 1) * WIDTH]);
	b = src32[x + 0 + (y - 1) * WIDTH];
	x < WIDTH - 1 && (c = src32[x + 1 + (y - 1) * WIDTH]);
      }

      x > 0 && (d = src32[x - 1 + y * WIDTH]);
      x < WIDTH - 1 && (e = src32[x + 1 + y * WIDTH]);

      if (y < HEIGHT - 1) {
	x > 0 && (f = src32[x - 1 + (y + 1) * WIDTH]);
	g = src32[x + 0 + (y + 1) * WIDTH];
	x < WIDTH - 1 && (h = src32[x + 1 + (y + 1) * WIDTH]);
      }

      var distsq = (x - WIDTH / 2) * (x - WIDTH / 2) +
	(y - WIDTH / 2) * (y - WIDTH / 2);

      if (distsq > 30 * 30 && distsq < 40 * 40 && 
	  inAngle(Math.atan2(y - HEIGHT / 2, x - WIDTH / 2))) {
	dst32[x + y * WIDTH] = PADDLE;
      } else if (frames < 10 && x > 60 && x < 70 && y > 60 && y < 70) {
	dst32[x + y * WIDTH] = 0xFFFF00FF;
      } else {

	var ct = !!a + !!b + !!c +
		 !!d +       !!e +
		 !!f + !!g + !!h;

	if (ct > 2 && ct < 7) {
	  var i = ct - 2;
	  dst32[x + y * WIDTH] = [0xFF00FFFF, 0xFF00DDDD,
				  0xFF00BBBB, 0xFF008888][i];
	} else {
	  dst32[x + y * WIDTH] = 0x00000000;
	}
      }
    }
  }
}

function Draw() {
  /*
  for (var y = frames % HEIGHT; y < HEIGHT; y++) {
    for (var x = 0; x < WIDTH; x++) {
      buf32[x + y * WIDTH] = ((x + frames) % 2) ? 0xFF00FFFF :
	0x00FFFFFF;
    }
  }
  */

  id.data.set((frames % 2) ? bufb8 : buf8);
  ctx.putImageData(id, 0, 0);

  // On every frame, flip to 4x canvas
  bigcanvas.Draw4x(ctx);
}

var last = 0;
var skipped = 0;
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

Start();

