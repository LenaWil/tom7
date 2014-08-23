
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

function XY(x, y) { return '(' + x + ',' + y + ')'; }

function Init() {
  window.font = new Font(resources.Get('font.png'),
                         FONTW, FONTH, FONTOVERLAP, FONTCHARS);
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
function Head(ux, uy, mx, my, graphic_facing, m) {
  if (!(graphic_facing == LEFT || graphic_facing == RIGHT))
    throw 'can only face LEFT or RIGHT in connectors.png';
  var ug = ConnectorGraphic(ux, uy);
  var mg = ConnectorGraphic(mx, my);

  // Make them face to the right by default.
  if (graphic_facing == LEFT) {
    ug = FlipHoriz(ug);
    mg = FlipHoriz(mg);
  }

  var ur = ug;
  var mr = mg;

  var ul = FlipHoriz(ur);
  var ml = FlipHoriz(mr);

  var ud = RotateCCW(ul);
  var md = RotateCCW(ml);

  var uu = RotateCCW(ur);
  var mu = RotateCCW(mr);

  // Assuming the order UP DOWN LEFT RIGHT.
  this.unmated = [new Frames(uu), new Frames(ud),
                  new Frames(ul), new Frames(ur)];
  this.mated = [new Frames(mu), new Frames(md),
                new Frames(ml), new Frames(mr)];
  if (m) this.mate_property = m;
  return this;
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
    rca_red_m: new Head(6, 3, 6, 2, RIGHT, 'rca_red_f'),
    rca_red_f: new Head(7, 3, 7, 2, LEFT,  'rca_red_m')
  };

  TieHeads();

  window.items = [];

  /*
  board = [];
  for (var i = 0; i < TILESW * TILESH; i++) {
    board[i] = null;
  }
  */

  console.log('initialized game');
}

/*
function GetBoard(x, y) {
  return board[y * TILESW + x];
}
*/

function Cell() {
  return this;
}

function CellHead(prop, facing) {
  var cell = new Cell;
  cell.type = CELL_HEAD;
  cell.head = window.heads[prop];
  if (!cell.head) throw ('no head ' + prop);
  cell.facing = facing;
  return cell;
}

function Item() {
  // XXX obviously, configurable
  this.width = 2;
  this.height = 1;
  this.shape = [CellHead('rca_red_m', LEFT),
                CellHead('rca_red_f', RIGHT)];
  return this;
}

Item.prototype.GetCell = function (x, y) {
  return this.shape[y * this.width + x];
};

Item.prototype.GetCellByGlobal = function(bx, by) {
  if (!this.onboard) return null;

  // In object's local coordinates,
  var lx = bx - this.boardx;
  var ly = by - this.boardy;

  if (lx >= 0 && lx < this.width &&
      ly >= 0 && ly < this.height)
    return this.GetCell(lx, ly);
};

// Index of item that contains this position. There can
// be at most one.
function GetItemAt(boardx, boardy) {
  // PERF use "cells" index; this linear scan is obviously
  // not efficient!
  for (var o in window.items) {
    var item = window.items[o];
    var cell = item.GetCellByGlobal(boardx, boardy);
    if (cell) return item;
  }

  return null;
}

// Does the cell at x,y contain a head, which is currently
// mated?
function IsMated(x, y) {
  var item = GetItemAt(x, y);
  if (!item) return false;
  var cell = item.GetCellByGlobal(x, y);
  if (!cell || cell.type != CELL_HEAD) return false;

  var mx = x, my = y;
  switch (cell.facing) {
    case UP: my--; break;
    case DOWN: my++; break;
    case LEFT: mx--; break;
    case RIGHT: mx++; break;
    default: throw 'not facing?';
  }
  if (mx < 0 || mx >= TILESW ||
      my < 0 || my >= TILESH)
    return false;

  // console.log(XY(x, y) + ' - ' + XY(mx, my));
  var mitem = GetItemAt(mx, my);
  // No self mates, right?
  if (!mitem) return false
  if (mitem == item) {
    // console.log('self mate');
    return false;
}

  var mcell = mitem.GetCellByGlobal(mx, my);
  if (!mcell || mcell.type != CELL_HEAD) return false;

  // XXX test compatibility...
  return true;
}

function Draw() {
  // ClearScreen();
  DrawFrame(window.boardbg, 0, 0);
  for (var y = 0; y < TILESH; y++) {
    for (var x = 0; x < TILESW; x++) {
      var item = GetItemAt(x, y);
      if (item != null) {
        var cell = item.GetCellByGlobal(x, y);
        if (!cell) throw 'bug';
        if (cell.type == CELL_HEAD) {
	  // PERF
          // XXX draw as mated, if mated.
          var frame = IsMated(x, y) ? 
	      cell.head.mated[cell.facing] :
	      cell.head.unmated[cell.facing];
          DrawFrame(frame,
                    BOARDSTARTX + x * TILESIZE,
                    BOARDSTARTY + y * TILESIZE);
        } else {
          // Other types, e.g. wires...
        }
      }
    }
  }

  // Draw floating item.

  // Draw indicators (e.g. 'in', 'out')
}

function CanvasClick(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);

  var boardx = Math.floor((x - BOARDSTARTX) / TILESIZE);
  var boardy = Math.floor((y - BOARDSTARTY) / TILESIZE);
  console.log('click ' + boardx + ', ' + boardy);

  if (boardx < TILESW - 1 &&
      boardy < TILESH &&
      GetItemAt(boardx, boardy) == null &&
      GetItemAt(boardx + 1, boardy) == null) {
    // XXX could at least be checking collisions...
    var it = new Item();
    it.onboard = true;
    it.boardx = boardx;
    it.boardy = boardy;
    window.items.push(it);
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

  Draw();

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
