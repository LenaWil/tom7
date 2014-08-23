
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
  window.highlightok = new Frames(ConnectorGraphic(1, 2));
  window.highlightnotok = new Frames(ConnectorGraphic(1, 1));
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

  // These are canvas coordinates, updated on animation frame.
  window.mousex = 0;
  window.mousey = 0;

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

var item_what = 0;
function Item() {
    // XXX obviously, configurable
  item_what++;
  
  switch (item_what % 4) {
    case 0:
    this.width = 2;
    this.height = 1;
    this.shape = [CellHead('rca_red_m', LEFT),
                  CellHead('rca_red_f', RIGHT)];
    break;
    case 1:
    this.width = 1;
    this.height = 2;
    this.shape = [CellHead('rca_red_f', UP),
                  CellHead('rca_red_f', DOWN)];
    break;
    case 2:
    this.width = 1;
    this.height = 2;
    this.shape = [CellHead('rca_red_m', UP),
                  CellHead('rca_red_m', DOWN)];
    break;
    case 3:
    this.width = 2;
    this.height = 1;
    this.shape = [CellHead('rca_red_f', LEFT),
                  CellHead('rca_red_m', RIGHT)];
    break;
  }
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

  return cell.head.mate == mcell.head &&
      mcell.head.mate == cell.head &&
      cell.facing == ReverseDir(mcell.facing);
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

  // Draw floating item:


  if (window.floating) {
    var it = window.floating;

    // Highlight cells that the item is aligned with.
    var res = CheckDrop();
      
    var cx = res.cx;
    var cy = res.cy;

    if (res.highlight) {
      for (var y = 0; y < it.height; y++) {
	for (var x = 0; x < it.width; x++) {
	  var f = res.highlight[y * it.width + x];
	  if (f) DrawFrame(f,
			   BOARDSTARTX + (res.startx + x) * TILESIZE,
			   BOARDSTARTY + (res.starty + y) * TILESIZE);
	}
      }
    }
    // TODO: Indicate that dropping would reset it...

    // Draw the item itself.
    for (var y = 0; y < it.height; y++) {
      for (var x = 0; x < it.width; x++) {
	var cell = it.GetCell(x, y);
	if (cell && cell.type == CELL_HEAD) {
	  DrawFrame(cell.head.unmated[cell.facing],
		    cx + x * TILESIZE,
		    cy + y * TILESIZE);
	}
      }
    }
    // Draw indicators for floating thing!
  }

  // Draw indicators (e.g. 'in', 'out')
}

// Returns an objec
//   - ok: true if we may drop here
//   - startx, starty: board coordinates for top left of object,
//     if it's safe to drop
//   - cx, cy: virtual mouse coordinates (top left of object),
//   - highlight: (or null) array of size item.width*height
function CheckDrop() {
  if (!window.floating) throw 'precondition';
  var it = window.floating;

  // Move the center of the item to the mouse point.
  var cx = window.mousex - (it.width * TILESIZE >> 1);
  var cy = window.mousey - (it.height * TILESIZE >> 1);
  var ret = {
    cx: cx,
    cy: cy,
    startx: Math.round((cx - BOARDSTARTX) / TILESIZE),
    starty: Math.round((cy - BOARDSTARTY) / TILESIZE),
    highlight: null,
  };
  if (ret.startx >= 0 && (ret.startx + it.width) <= TILESW &&
      ret.starty >= 0 && (ret.starty + it.height) <= TILESH) {
    ret.highlight = [];
    ret.ok = true;
    for (var y = 0; y < it.height; y++) {
      for (var x = 0; x < it.width; x++) {
	var cell = it.GetCell(x, y);
	if (cell && cell.type == CELL_HEAD) {
	  // XXX test if occupied...
	  var occupied = GetItemAt(ret.startx + x, ret.starty + y) != null;
	  if (occupied) ret.ok = false;
	  ret.highlight.push(
	    occupied ? window.highlightnotok : window.highlightok);
	} else {
	  ret.highlight.push(null);
	}
      }
    }
    return ret;
  } else {
    // Not ok. No highlighting.
    return ret;
  }
}

function CanvasMousedown(e) {
  if (window.floating) {
    // behave as mousedown if we're holding something, since these
    // are not always actually bracketed. Don't add another one!
    CanvasMouseup(e);
    return;
  }

  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);

  // If in the tray section, then we create a new piece and
  // start dragging it.
  if (x >= TRAYX && y >= TRAYY &&
      x < (TRAYX + TRAYW) &&
      y <= (TRAYY + TRAYH)) {
    console.log('touch in tray');
    // In tray.
    var it = new Item();

    window.floating = it;
    // if not on board, then that always means floating,
    // which means wherever the mouse is.
    it.onboard = false;

  } else {
    // In board? -- pick up piece?
    var boardx = Math.floor((x - BOARDSTARTX) / TILESIZE);
    var boardy = Math.floor((y - BOARDSTARTY) / TILESIZE);
    console.log('touch maybe in board ' + boardx + ', ' + boardy);

    // XXX NO.
    /*
    var it = new Item();
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
    */
  }

  // HERE...
}

function CanvasMouseup(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);

  if (window.floating) {
    console.log('try drop...');
    var it = window.floating;
    var res = CheckDrop();
    console.log(res);
    if (res.ok) {
      it.onboard = true;
      it.boardx = res.startx;
      it.boardy = res.starty;
      window.items.push(it);
      window.floating = false;
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

function CanvasMove(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);
  window.mousex = x;
  window.mousey = y;
}

function Start() {
  Init();
  InitGame();

  bigcanvas.canvas.onmousemove = CanvasMove;
  bigcanvas.canvas.onmousedown = CanvasMousedown;
  bigcanvas.canvas.onmouseup = CanvasMouseup;

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
