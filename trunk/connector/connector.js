
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

// XXX pump up the jams!
var audiocontext = null;

var resources = new Resources(
  ['font.png',
   'board.png',
   'connectors.png'],
  [], null);


var board = null;
function Init() {
  window.font = new Font(resources.Get('font.png'),
			 FONTW, FONTH, FONTOVERLAP, FONTCHARS);
  console.log(resources.Get('connectors.png'));
  window.connectorspx = Buf32FromImage(resources.Get('connectors.png'));
  window.connectorswidth = resources.Get('connectors.png').width;
  window.boardbg = Static('board.png');
}

function ConnectorGraphic(x, y) {
  if (!window.connectorspx) throw 'init';
  return ExtractBuf32(window.connectorspx,
		      window.connectorswidth,
		      BOARDSTARTX + x * TILESIZE,
		      BOARDSTARTY + y * TILESIZE,
		      TILESIZE, TILESIZE);
}

// 'Enumeration' of connector heads.
// Pass unmated x,y (board) coordinates of graphic (facing right),
// then mated x,y coordinates,
// then string containing the name of its mate.
function Head(ux, uy, mx, my, m) {
  this.unmated = [ConnectorGraphic(ux, uy)];
  this.mated = [ConnectorGraphic(mx, my)];
  if (m) this.mate_property = m;
}

// Heads can refer to each other; tie the property names to actual
// head objects.
function TieHeads() {
  for (var o in window.heads) {
    var head = window.heads[o];
    if (head.mate_property && window.heads[head.mate_property]) {
      head.mate = window.heads[head.mate_property];
    }
  }
}


// var RCA_RED_MALE = new Head

function InitGame() {
  window.heads = {
    rca_red_m: new Head(6, 3, 6, 2, 'rca_red_f'),
    rca_red_f: new Head(7, 3, 7, 2, 'rca_red_m')
  };

  TieHeads();

  board = [];
  for (var i = 0; i < TILESW * TILESH; i++) {
    board[i] = null;
  }

  console.log('initialized game');
}

function GameStep() {
  // ClearScreen();
  DrawFrame(window.boardbg, 0, 0);

}

function CanvasClick(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);

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
