
var counter = 0;
var start_time = (new Date()).getTime();


var PHASE_TITLE = 0;
var phase = PHASE_TITLE;

var images = new Images(
  ['eye.png', // XXX
   'walk1.png',
   'walk2.png',
   'walk3.png',
   'title.png',
   'classroom.png']);

function SetPhase(p) {
  frames = 0;
  phase = p;
}

function TitleFrame(time) {
  ctx.drawImage(images.Get('title.png'), 0, 0);
  // XXX handle keys?
}

var frames = 0;
function Frame(time) {
  // XXX here, throttle to 30 fps or something we
  // should be able to hit on most platforms.
  frames++;

  if (phase == PHASE_TITLE) {
    TitleFrame(time);
  } else {

    /*
    // Put pixels
    id.data.set(buf8);
    ctx.putImageData(id, 0, 0);
    */

    for (var i = 0; i < 1000; i++) {
      var x = 0 | ((f * i) % WIDTH);
      var y = 0 | ((f * 31337 + i) % HEIGHT);
      ctx.drawImage(eye, x - 16, y - 16);
    }
    
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
  window.requestAnimationFrame(Frame);
}

function Start() {
  phase = PHASE_TITLE;
  start_time = (new Date()).getTime();
  window.requestAnimationFrame(Frame);
}

images.WhenReady(Start);
