
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

  // West-East
  var wirebar = ConnectorGraphic(5, 3);  
  // South-East
  var wireangle = ConnectorGraphic(5, 2);
  
  window.wireframes = {};
  window.wireframes[WIRE_WE] = new Frames(wirebar);
  window.wireframes[WIRE_NS] = new Frames(RotateCCW(wirebar));
  window.wireframes[WIRE_SE] = new Frames(wireangle);
  wireangle = RotateCCW(wireangle);
  window.wireframes[WIRE_NE] = new Frames(wireangle);
  wireangle = RotateCCW(wireangle);
  window.wireframes[WIRE_NW] = new Frames(wireangle);
  wireangle = RotateCCW(wireangle);
  window.wireframes[WIRE_SW] = new Frames(wireangle);
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

function InitGame() {
  window.heads = {
    rca_red_m: new Head(6, 3, 6, 2, RIGHT, 'rca_red_f'),
    rca_red_f: new Head(7, 3, 7, 2, LEFT,  'rca_red_m'),
    quarter_m: new Head(6, 5, 6, 4, RIGHT, 'quarter_f'),
    quarter_f: new Head(7, 5, 7, 4, LEFT,  'quarter_m'),
    usb_m:     new Head(6, 1, 6, 0, RIGHT, 'usb_f'),
    usb_f:     new Head(7, 1, 7, 0, LEFT,  'usb_m')
  };

  TieHeads();

  window.items = [];
  window.floating = null;
  window.dragging = null;

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

function CellWire(wire) {
  var cell = new Cell;
  cell.type = CELL_WIRE;
  cell.wire = wire;
  return cell;
}

var item_what = 0;
function Item() {
  // XXX obviously, make configurable
  item_what++;

  var heads = [];
  for (var o in window.heads) {
    heads.push(o);
  }
  var head1 = heads[Math.floor(Math.random() * heads.length)];
  var head2 = heads[Math.floor(Math.random() * heads.length)];

  var len = Math.floor(Math.random() * 2);

  switch (item_what % 2) {
    case 0:
    this.width = 2 + len;
    this.height = 1;
    this.shape = [CellHead(head1, LEFT)];
    for (var i = 0; i < len; i++) this.shape.push(CellWire(WIRE_WE));
    this.shape.push(CellHead(head2, RIGHT));
    break;
    case 1:
    this.width = 1;
    this.height = 2 + len;
    this.shape = [CellHead(head1, UP)];
    for (var i = 0; i < len; i++) this.shape.push(CellWire(WIRE_NS));
    this.shape.push(CellHead(head2, DOWN));
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
        } else if (cell.type == CELL_WIRE) {
	  DrawFrame(window.wireframes[cell.wire],
		    BOARDSTARTX + x * TILESIZE,
		    BOARDSTARTY + y * TILESIZE);
        }
      }
    }
  }

  // Draw floating item, if any:
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
	if (cell) {
	  if (cell.type == CELL_HEAD) {
	    DrawFrame(cell.head.unmated[cell.facing],
		      cx + x * TILESIZE,
		      cy + y * TILESIZE);
	  } else if (cell.type == CELL_WIRE) {
	    DrawFrame(window.wireframes[cell.wire],
		      cx + x * TILESIZE,
		      cy + y * TILESIZE);
	  }
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
	if (cell && (cell.type == CELL_HEAD || cell.type == CELL_WIRE)) {
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
  if (window.floating || window.dragging) {
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
  // start floating it.
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

    if (boardx >= 0 && boardy >= 0 &&
	boardx < TILESW &&
	boardy < TILESH) {
      var it = GetItemAt(boardx, boardy);
      if (!it) return;
      var cell = it.GetCellByGlobal(boardx, boardy);
      if (!cell) return;
      if (cell.type == CELL_WIRE) {
	// Wires just mean detach.
	if (window.floating) throw 'already established';
	window.floating = it;
	it.onboard = false;
      } else if (cell.type == CELL_HEAD) {
	console.log('sorry not yet');
	window.dragging =
	    { it: it,
	      x: boardx,
	      y: boardy };
      }
    }

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
    // console.log(res);
    if (res.ok) {
      it.onboard = true;
      it.boardx = res.startx;
      it.boardy = res.starty;
      window.items.push(it);
      window.floating = false;
    }
  } else if (window.dragging) {
    console.log('undrag');
    window.dragging = null;
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

// Get the direction from (sx, sy) to (dx, dy), but only if it
// is exactly one square (manhattan distance). Otherwise return
// null.
function GetDirection1(sx, sy, dx, dy) {
  if (sx == dx) {
    if (sy + 1 == dy) return DOWN;
    else if (sy - 1 == dy) return UP;
    else return null;
  } else if (sy == dy) {
    if (sx + 1 == dx) return RIGHT;
    else if (sx - 1 == dx) return LEFT;
    else return null;
  } else {
    return null;
  }
}

function CanvasMove(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);
  window.mousex = x;
  window.mousey = y;

  if (window.dragging) {
    var Detach = function () {
      window.floating = window.dragging.it;
      window.floating.onboard = false;
      window.dragging = null;
    };

    var boardx = Math.floor((x - BOARDSTARTX) / TILESIZE);
    var boardy = Math.floor((y - BOARDSTARTY) / TILESIZE);
    console.log('touch maybe in board ' + boardx + ', ' + boardy);

    if (boardx >= 0 && boardy >= 0 &&
	boardx < TILESW &&
	boardy < TILESH) {
      // Mouse moves can be arbitrary, but only do
      // it if manhattan distance is 1.
      var mh = GetDirection1(window.dragging.x, window.dragging.y,
			     boardx, boardy);
      if (mh == null) {
	return;
      } else {
	var it = window.dragging.it;
	// Is it occupied by another item, we detach.
	var other = GetItemAt(boardx, boardy);
	if (other && other != it) {
	  console.log('detach due to collision with other');
	  Detach();
	  return;
	}
	
	var cell = it.GetCellByGlobal(window.dragging.x,
				      window.dragging.y);

	// Otherwise, try shrink, grow...
	if (!other) {
	  // Can grow into free space.
	  if (cell.type != CELL_HEAD) throw 'bad drag';
	  var oldface = cell.facing;
	  var newface = mh;
	  var newwire = GetTurn(oldface, newface);

	  if (newwire == null) {
	    console.log('impossible turn!');
	    Detach();
	    return;
	  }
	  console.log('turn!');
	  
	  var srcx = window.dragging.x - it.boardx;
	  var srcy = window.dragging.y - it.boardy;
	  var dstx = boardx - it.boardx;
	  var dsty = boardy - it.boardy;
	  it.shape[srcy * it.width + srcx] = CellWire(newwire);
	  // dstx/y might be negative, or outside the it's shape.
	  // safeplot expands/moves as necessary to preserve the
	  // fiction.
	  cell.facing = newface;
	  it.SafePlot(dstx, dsty, cell);
	  window.dragging.x = boardx;
	  window.dragging.y = boardy;
	} else {
	  if (other != it) throw 'already established';
	  if (mh != ReverseDir(cell.facing)) {
	    console.log('non-retraction');
	    Detach();
	    return;
	  }

	  // Then we're running into ourself.
	  var ocell = it.GetCellByGlobal(boardx, boardy);
	  if (!ocell) throw ('object but no cell?');
	  if (ocell.type == CELL_HEAD) {
	    console.log('run into other head');
	    Detach();
	    return;
	  } else if (ocell.type == CELL_WIRE) {
	    var oldface = cell.facing;
	    var oldwire = ocell.wire;
	    var newface = GetCompatibleShrink(oldface, oldwire);
	    
	    if (newface == null) {
	      // Note: probably means buggy wire state.
	      console.log('impossible retraction!');
	      Detach();
	      return;
	    }

	    var srcx = window.dragging.x - it.boardx;
	    var srcy = window.dragging.y - it.boardy;
	    var dstx = boardx - it.boardx;
	    var dsty = boardy - it.boardy;
	    cell.facing = newface;
	    it.shape[srcy * it.width + srcx] = null;
	    it.shape[dsty * it.width + dstx] = cell;
	    it.ShrinkToFit();
	    window.dragging.x = boardx;
	    window.dragging.y = boardy;
	  }
	}
      }
    }
  }
}

// Pass the direction the head is currently facing, and the wire
// we're trying to move into. Returns null if it makes no sense,
// otherwise, the new direction the head faces.
function GetCompatibleShrink(face, wire) {
  switch (face) {
    case UP:
    if (wire == WIRE_NS) return UP;
    else if (wire == WIRE_NW) return RIGHT;
    else if (wire == WIRE_NE) return LEFT;
    else return null;
    break;
    case DOWN:
    if (wire == WIRE_NS) return DOWN;
    else if (wire == WIRE_SW) return RIGHT;
    else if (wire == WIRE_SE) return LEFT;
    else return null;
    break;
    case LEFT:
    if (wire == WIRE_WE) return LEFT;
    else if (wire == WIRE_NW) return DOWN;
    else if (wire == WIRE_SW) return UP;
    else return null;
    break;
    case RIGHT:
    if (wire == WIRE_WE) return RIGHT;
    else if (wire == WIRE_NE) return DOWN;
    else if (wire == WIRE_SE) return UP;
    break;
  }
  return null;
}

Item.prototype.EmptyColumn = function(x) {
  for (var y = 0; y < this.height; y++)
    if (this.shape[y * this.width + x] != null)
      return false;
  return true;
};

Item.prototype.EmptyRow = function(y) {
  for (var x = 0; x < this.width; x++)
    if (this.shape[y * this.width + x] != null)
      return false;
  return true;
};

// Assuming the item is on the board, trim away any
// empty rows and columns.
Item.prototype.ShrinkToFit = function() {
  while (this.EmptyColumn(0)) {
    if (this.width <= 1) throw 'impossible - empty';
    var owidth = this.width;
    this.width--;
    this.boardx++;
    var oldshape = this.shape;
    this.shape = [];
    for (var y = 0; y < this.height; y++) {
      for (var x = 0; x < this.width; x++) {
	var prev = oldshape[y * owidth + x + 1];
	this.shape[y * this.width + x] = prev;
      }
    }
  }

  while (this.EmptyRow(0)) {
    if (this.height <= 1) throw 'impossible - empty';
    this.height--;
    this.boardy++;
    var oldshape = this.shape;
    this.shape = [];
    for (var y = 0; y < this.height; y++) {
      for (var x = 0; x < this.width; x++) {
	var prev = oldshape[(y + 1) * this.width + x];
	this.shape[y * this.width + x] = prev;
      }
    }
  }

  while (this.EmptyColumn(this.width - 1)) {
    if (this.width <= 1) throw 'impossible - empty';
    var owidth = this.width;
    this.width--;
    var oldshape = this.shape;
    this.shape = [];
    for (var y = 0; y < this.height; y++) {
      for (var x = 0; x < this.width; x++) {
	var prev = oldshape[y * owidth + x];
	this.shape[y * this.width + x] = prev;
      }
    }
  }

  while (this.EmptyRow(this.height - 1)) {
    if (this.height <= 1) throw 'impossible - empty';
    this.height--;
    // Just truncate the last row.
    this.shape.splice(this.shape.length - this.width, this.width);
    if (this.shape.length != this.width * this.height)
      throw 'bug';
    console.log(this.shape);
  }
};

// assumes the item is on the board currently...
Item.prototype.SafePlot = function(dx, dy, cell) {
  console.log(XY(dx, dy), cell);
  while (dx < 0) {
    // Add column on the left.
    var owidth = this.width;
    this.width++;
    this.boardx--;
    var oldshape = this.shape;
    this.shape = [];
    for (var y = 0; y < this.height; y++) {
      for (var x = 0; x < this.width; x++) {
	var prev = ((x - 1) >= 0) ?
	    oldshape[y * owidth + x - 1] :
	    null;
	this.shape[y * this.width + x] = prev;
      }
    }
    dx++;
  }

  while (dy < 0) {
    // Add row on top.
    this.height++;
    this.boardy--;
    var oldshape = this.shape;
    this.shape = [];
    for (var y = 0; y < this.height; y++) {
      for (var x = 0; x < this.width; x++) {
	var prev = ((y - 1) >= 0) ?
	    oldshape[(y - 1) * this.width + x] :
	    null;
	this.shape[y * this.width + x] = prev;
      }
    }
    dy++;
  }

  while (dx >= this.width) {
    console.log('grow right');
    var owidth = this.width;
    this.width++;
    var oldshape = this.shape;
    this.shape = [];
    for (var y = 0; y < this.height; y++) {
      for (var x = 0; x < this.width; x++) {
	var prev = (x < owidth) ?
	    oldshape[y * owidth + x] :
	    null;
	this.shape[y * this.width + x] = prev;
      }
    }
  }

  while (dy >= this.height) {
    this.height++;
    var oldshape = this.shape;
    // Add a new row to existing array.
    for (var x = 0; x < this.width; x++) {
      this.shape.push(null);
    }
  }

  // also dy >= height
  this.shape[dy * this.width + dx] = cell;
};

// If we used to be facing in oldface direction, and want
// to turn to the new direction, what kind of wire do we
// need?
function GetTurn(oldface, newface) {
  if (oldface == newface) {
    if (oldface == UP || oldface == DOWN) return WIRE_NS;
    else if (oldface == LEFT || oldface == RIGHT) return WIRE_WE;
  } else {
    switch (oldface) {
      case UP:
      if (newface == LEFT) return WIRE_SW;
      else if (newface == RIGHT) return WIRE_SE;
      else return null;
      case DOWN:
      if (newface == LEFT) return WIRE_NW;
      else if (newface == RIGHT) return WIRE_NE;
      else return null;
      case LEFT:
      if (newface == UP) return WIRE_NE;
      else if (newface == DOWN) return WIRE_SE;
      else return null;
      case RIGHT:
      if (newface == UP) return WIRE_NW;
      else if (newface == DOWN) return WIRE_SW;
      else return null;
    }
  }
  return null;
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
