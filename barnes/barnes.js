
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

// XXX not using audio yet
var audiocontext = null;

var resources = new Resources(
  ['font.png',
   'well.png',
   'rivernw.png',
   'riverse.png',
   'riverns.png',
   'riverwe.png',
   'barnns.png',
   'barnwe.png',
   'dirt.png'],
  [], null);


var draworder = [];
function Init() {
  window.font = new Font(resources.Get('font.png'),
			 FONTW, FONTH, FONTOVERLAP, FONTCHARS);
  draworder = [];
  for (var y = 0; y < BOARDH; y++) {
    for (var x = 0; x < BOARDW; x++) {
      var px = x * EASTX + y * SOUTHX;
      var py = x * EASTY + y * SOUTHY;
      draworder.push({ x: x, y: y, px: px, py: py });
    }
  }

  draworder.sort(function (a, b) {
    return a.py - b.py;
  });
  
  for (var i = 0; i < draworder.length; i++) {
    var c = draworder[i];
    console.log('' + c.x + '/' + c.y);
  }
}

function Tile(frames, ns, ew) {
  this.frames = (typeof frames === 'string') ? Static(frames) : frames;
  this.ns = ns;
  this.ew = ew;
}

var board = [];

// For a second playthrough...
function InitGame() {
  window.tiles = {
    dirt: new Tile('dirt.png', true, true),
    well: new Tile('well.png', true, true),
    riverns: new Tile('riverns.png', true, false),
    riverwe: new Tile('riverwe.png', false, true),
    rivernw: new Tile('rivernw.png', false, false),
    riverse: new Tile('riverse.png', false, false)
  };

  window.barnns = Static('barnns.png');
  window.barnwe = Static('barnwe.png');

  board = [];
  for (var y = 0; y < BOARDH; y++) {
    for (var x = 0; x < BOARDW; x++) {
      var i = y * BOARDW + x;
      board[i] =
	  { t: tiles.dirt };
      if (x == 0 && y == 0) {
	board[i].t = tiles.well;
      } else if (x == BOARDW - 1 && y == BOARDH - 1) {
	board[i].t = tiles.well;
      } else if (x >= 3 && y == 1) {
	board[i].t = tiles.riverwe;
      } else if (x <= 1 && y == 3) {
	board[i].t = tiles.riverwe;
      } else if (x == 2 && y == 2) {
	board[i].t = tiles.riverns;
      } else if (x == 2 && y == 1) {
	board[i].t = tiles.riverse;
      } else if (x == 2 && y == 3) {
	board[i].t = tiles.rivernw;
      }
    }
  }


  console.log('initialized game');
}

function GameStep() {
  // XXX draw back-to-front 'z'??
  for (var i = 0; i < draworder.length; i++) {
    var x = draworder[i].x;
    var y = draworder[i].y;
    var cell = board[y * BOARDW + x];
    // XXX Board offset...
    var px = x * EASTX + y * SOUTHX;
    var py = x * EASTY + y * SOUTHY;
    // console.log('' + x + ',' + y + ': ' +
    // px + ',' + py);
    DrawFrame(cell.t.frames,
	      BOARDX + px - TILEOX,
	      BOARDY + py - TILEOY);
    var r = 1.0; // Math.random();
    if (r < 0.2) {
      DrawFrame(barnns, 
		BOARDX + px - TILEOX,
		BOARDY + py - TILEOY);
    } else if (r < 0.4) {
      DrawFrame(barnwe,
		BOARDX + px - TILEOX,
		BOARDY + py - TILEOY);
    }
  }
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
  // I can easily get 60, so what gives?
  if (diff < MINFRAMEMS) {
    skipped++;
    window.requestAnimationFrame(Step);
    return;
  }
  last = now;

  frames++;
  if (frames > 1000000) frames = 0;

  GameStep();

  /*
  switch (phase) {
  case PHASE_PLAYING:
    PlayingStep();
    break;
  case PHASE_CUTSCENE:
    CutSceneStep();
    break;
  case PHASE_TITLE:
    TitleStep();
    break;
  }
  */

  // process music in any state
  // UpdateSong();

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
  console.log('XXX one frame');
  //  window.requestAnimationFrame(Step);
}

function Start() {
  Init();
  InitGame();

  /*
  cutscene = cutscenes.intro;
  after_cutscene = function () {
    WarpTo('fishroom', 77, 116);
    SetPhase(PHASE_PLAYING);
    ClearText();
    textpages = ['Time to tend to my debts.'];
  };
  SetPhase(PHASE_CUTSCENE);
  */
  
  // XXX not this!
  // WarpTo('beach', 77, 116);
  // SetPhase(PHASE_PLAYING);

  start_time = (new Date()).getTime();
  window.requestAnimationFrame(Step);
}

resources.WhenReady(Start);
