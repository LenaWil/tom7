
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

// XXX not using audio yet
var audiocontext = null;

var resources = new Resources(
  ['font.png',
   'well.png',
   'north.png',
   'east.png',
   'south.png',
   'west.png',
   'rotate.png',
   'greenhome.png',
   'purphome.png',
   'greenpiecens.png',
   'purppiecens.png',
   'greenpiecewe.png',
   'purppiecewe.png',
   'rivernw.png',
   'riverse.png',
   'riverns.png',
   'riverwe.png',
   'barnns.png',
   'barnwe.png',
   'dirt.png'],
  [], null);

var angle = { ns: {}, we: {} };

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

function Tile(frames, ns, we) {
  this.frames = (typeof frames === 'string') ? Static(frames) : frames;
  this.ns = ns;
  this.we = we;
}

function Control(frames, x, y) {
  this.frames = frames;
  this.x = x;
  this.y = y;

  this.w = frames.width;
  this.h = frames.height;

  this.Contains = function(xx, yy) {
    return xx >= this.x && yy >= this.y &&
	(xx < this.x + this.w) &&
	(yy < this.y + this.h);
  };
}

function State() {
  // Contents of each cell.
  this.board = [];
  // Whose turn it is?
  this.greenturn = true;
  this.greenx = 0;
  this.greeny = 0;
  this.purpx = BOARDW - 1;
  this.purpy = BOARDW - 1;

  for (var y = 0; y < BOARDH; y++) {
    for (var x = 0; x < BOARDW; x++) {
      var i = y * BOARDW + x;
      this.board[i] = { t: tiles.dirt, barn: null };
      if (x == 0 && y == 0) {
	this.board[i].t = tiles.greenhome;
	this.board[i].barn = angle.we;
      } else if (x == BOARDW - 1 && y == BOARDH - 1) {
	this.board[i].t = tiles.purphome;
	this.board[i].barn = angle.we;
      } else if (x >= 3 && y == 1) {
	this.board[i].t = tiles.riverwe;
      } else if (x <= 1 && y == 3) {
	this.board[i].t = tiles.riverwe;
      } else if (x == 2 && y == 2) {
	this.board[i].t = tiles.riverns;
      } else if (x == 2 && y == 1) {
	this.board[i].t = tiles.riverse;
      } else if (x == 2 && y == 3) {
	this.board[i].t = tiles.rivernw;
      }
    }
  }

  // What phase in the turn is it? 
  this.GetPhase = function() {

  };
}

// For a second playthrough...
function InitGame() {
  window.tiles = {
    dirt: new Tile('dirt.png', true, true),
    well: new Tile('well.png', true, true),
    riverns: new Tile('riverns.png', true, false),
    riverwe: new Tile('riverwe.png', false, true),
    rivernw: new Tile('rivernw.png', false, false),
    riverse: new Tile('riverse.png', false, false),
    greenhome: new Tile('greenhome.png', true, true),
    purphome: new Tile('purphome.png', true, true)
  };

  window.barnns = Static('barnns.png');
  window.barnwe = Static('barnwe.png');
  window.greenpiecens = Static('greenpiecens.png');
  window.purppiecens = Static('purppiecens.png');
  window.greenpiecewe = Static('greenpiecewe.png');
  window.purppiecewe = Static('purppiecewe.png');

  window.northbutton = Static('north.png');
  window.eastbutton = Static('east.png');
  window.southbutton = Static('south.png');
  window.westbutton = Static('west.png');
  window.rotatebutton = Static('rotate.png');

  window.northctrl = new Control(northbutton, CTRLX, CTRLY);
  window.eastctrl = new Control(eastbutton, CTRLX + 20, CTRLY);
  window.southctrl = new Control(southbutton, CTRLX + 20, CTRLY + 16);
  window.westctrl = new Control(westbutton, CTRLX, CTRLY + 16);

  window.rotatectrl = new Control(rotatebutton, CTRLX + 5, CTRLY + 34);
  window.controls = [northctrl, eastctrl, southctrl, westctrl,
		     rotatectrl];

  state = new State();

  console.log(state.board.length);
  for (var i = 0; i < BOARDW * BOARDH; i++) {
    if (state.board[i].t.ns && Math.random() < 0.15) {
      state.board[i].barn = angle.ns;
    } else if (state.board[i].t.we && Math.random() < 0.15) {
      state.board[i].barn = angle.we;
    }
  }

  console.log('initialized game');
}

function GameStep() {
  ClearScreen();

  var board = state.board;
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
    var ugp = false, upp = false;

    // Barn next.
    if (cell.barn) {
      DrawFrame((cell.barn == angle.ns) ? barnns : barnwe,
		BOARDX + px - TILEOX,
		BOARDY + py - TILEOY);

      // Only can have a piece if there's a barn
      // here.

      if (x == state.greenx && y == state.greeny) {
	DrawFrame((cell.barn == angle.ns) ? greenpiecens : greenpiecewe,
		  BOARDX + px - TILEOX,
		  BOARDY + py - TILEOY);
      } else if (x == state.purpx && y == state.purpy) {
	DrawFrame((cell.barn == angle.ns) ? purppiecens : purppiecewe,
		  BOARDX + px - TILEOX,
		  BOARDY + py - TILEOY);
      }
    }
  }

  for (var o in controls) {
    var ctrl = controls[o];
    DrawFrame(ctrl.frames, ctrl.x, ctrl.y);
  }

  // Controls.
  // XXX: Highlight if mouse is hovering and legal!
}

function CanvasClick(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);

  for (var o in controls) {
    var ctrl = controls[o];
    if (ctrl.Contains(x, y)) {
      // XXX
    }
  }
  // HERE...
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
  // console.log('XXX one frame');
  window.requestAnimationFrame(Step);
}

function Start() {
  Init();
  InitGame();

  bigcanvas.canvas.onclick = CanvasClick;

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
