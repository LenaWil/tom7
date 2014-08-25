
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

var resources = new Resources(
  ['font.png',
   'desk.png',
   'deskbubble.png',
   'title.png',
   'board.png',
   'sell1.png',
   'sell2.png',
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
  window.highlightin = new Frames(ConnectorGraphic(1, 3));
  window.highlightout = new Frames(ConnectorGraphic(1, 4));

  window.ballframes = new Frames(ConnectorGraphic(1, 6));

  window.sellframes = EzFrames(['sell1', 2, 'sell2', 2]);
  window.titleframes = EzFrames(['title', 1]);
  window.deskbubbleframes = EzFrames(['deskbubble', 1]);

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

  // Audio tweaks.
  song_theme.multiply = 1.5;
  song_power.multiply = 1.35;

  // song_menu[0].volume = 0.65;
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
// Pass unmated frames (facing right), mated frames,
// then string containing the name of its mate (optional).
function Head(uframes, mframes, m) {
  var ur = uframes;
  var mr = mframes;

  var ul = FlipFramesHoriz(ur);
  var ml = FlipFramesHoriz(mr);

  var ud = RotateFramesCCW(ul);
  var md = RotateFramesCCW(ml);

  var uu = RotateFramesCCW(ur);
  var mu = RotateFramesCCW(mr);

  // Assuming the order UP DOWN LEFT RIGHT.
  this.unmated = [uu, ud, ul, ur];
  this.mated = [mu, md, ml, mr];
  if (m) this.mate_properties = m;
  return this;
}

// Heads can refer to each other; tie the property names to actual
// head objects.
function TieHeads() {
  for (var o in window.heads) {
    var head = window.heads[o];
    head.mates = [];
    var mp = head.mate_properties || [];
    for (var i = 0; i < mp.length; i++) {
      if (window.heads[mp[i]]) {
	head.mates.push(window.heads[mp[i]]);
      } else {
	console.log('unknown mate ' + mp[i]);
      }
    }
  }
}

function EzHead(ux, uy, mx, my, graphic_facing, m) {
  if (!(graphic_facing == LEFT || graphic_facing == RIGHT))
    throw 'can only face LEFT or RIGHT in connectors.png';

  var ur = ConnectorGraphic(ux, uy);
  var mr = ConnectorGraphic(mx, my);

  // Make them face to the right if facing left.
  if (graphic_facing == LEFT) {
    ur = FlipHoriz(ur);
    mr = FlipHoriz(mr);
  }

  return new Head(new Frames(ur), new Frames(mr), m);
}



function InitGame() {
  var livewire_unmated =
      new Frames(FlipHoriz(ConnectorGraphic(4, 3)));
  var livewire_anim =
      FlipFramesHoriz(
	new Frames([
	  {f: ConnectorGraphic(4, 4), d: 2},
	  {f: ConnectorGraphic(4, 5), d: 1},
	  {f: ConnectorGraphic(4, 6), d: 1},
	  {f: ConnectorGraphic(4, 7), d: 3}]));

  window.heads = {
    rca_red_m:  EzHead(6, 3, 6, 2, RIGHT, ['rca_red_f']),
    rca_red_f:  EzHead(7, 3, 7, 2, LEFT,  ['rca_red_m']),
    quarter_m:  EzHead(6, 5, 6, 4, RIGHT, ['quarter_f']),
    quarter_f:  EzHead(7, 5, 7, 4, LEFT,  ['quarter_m']),
    usb_m:      EzHead(6, 1, 6, 0, RIGHT, ['usb_f']),
    usb_f:      EzHead(7, 1, 7, 0, LEFT,  ['usb_m']),
    ac_plug:    EzHead(9, 5, 9, 6, RIGHT, ['outlet_top', 'outlet_bot']),
    // For live wires, 'mated' means animated. HA HA!
    livewire:  new Head(livewire_unmated, livewire_anim, null),
    outlet_top: EzHead(11, 6, 10, 6, LEFT, ['ac_plug']),
    outlet_bot: EzHead(11, 7, 10, 7, LEFT, ['ac_plug']),
    // For pen, mated means heated tip
    solder_pen: EzHead(9, 2, 9, 3, LEFT, [])
  };

  window.heads.outlet_top.outlet = true;
  window.heads.outlet_bot.outlet = true;

  window.randheads = 8;

  TieHeads();

  window.stack = [];

  ClearGame();

  // These are canvas coordinates, updated on animation frame.
  window.mousex = 0;
  window.mousey = 0;


  // Cutscenes..
  window.cutscenes = {
    intro: new Cutscene(
      [{ f: EzFrames(['desk', 1]),
	 s: song_menu,
	 predelay: 40,
	 t: [' Hey, I\'m Jim. I ',
	     'work at Connector ',
	     'World, your one-stop ',
	     'shop for all your ',
	     '   connecting needs.'] },
       { f: EzFrames(['desk', 1]),
	 s: song_menu,
	 t: [' Today I am gonna',
	     'be \'outsourcing\' my',
	     'job. You\'re going',
	     'to do it, because',
	     '  you seem to think'] },
       { f: EzFrames(['desk', 1]),
	 s: song_menu,
	 t: [' my job is some kind',
	     'of game, which is',
	     'weird.'] }
      ], function () {
	ClearSong();
	phase = PHASE_PUZZLE;
	Level1();
      }),
    tutorialend: new Cutscene(
      [{ f: EzFrames(['desk', 1]),
	 s: song_menu,
	 predelay: 30,
	 t: [' OK, this is great.',
	     'I\'m going to play',
	     'Treat Destroyer while',
	     'you help the',
	     '      customers.'] }],
      function () {
	ClearSong();
	phase = PHASE_PUZZLE;
	Level3();
      }),
    interlude: new Cutscene(
      [{ f: EzFrames(['desk', 1]),
	 s: song_menu,
	 predelay: 30,
	 t: [' Oh wow, I just got',
	     'a 6x combo. M-m-m-m-',
	     'monster chocolate!'] }],
      function () {
	ClearSong();
	phase = PHASE_PUZZLE;
	Level5();
      }),
    hmm: new Cutscene(
      [{ f: EzFrames(['desk', 1]),
	 s: song_menu,
	 predelay: 20,
	 t: [' Hmmm, I don\'t ',
	     'know about this...'] },
       { f: EzFrames(['desk', 1]),
	 s: song_menu,
	 predelay: 5,
	 t: [' That connector was ',
	     'part of the user',
	     'interface. You\'re',
	     'not supposed to sell',
	     '       it.'] },
       { f: EzFrames(['desk', 1]),
	 s: song_menu,
	 predelay: 5,
	 t: [' Part of what makes',
	     'games fun is rules.',
	     'Let\'s follow the',
	     'rules, ok?'] }],
      function () {
	ClearSong();
	phase = PHASE_PUZZLE;
	Level7();
      })
  };

  console.log('initialized game');
}

function Cutscene(desc, cont) {
  this.desc = desc;
  this.cont = cont;
  return this;
}

function ClearGame() {
  window.touched_level = false;
  window.items = [];
  window.floating = null;
  window.dragging = null;

  window.goal = null;
  window.goalin = null;
  window.goalout = null;
  window.stack = [];
  // XXX allow by default??
  window.cantakegoal = false;

  window.tutorial = null;
  window.tutorial_test = null;

  window.nextlevel = null;
}

function InitLevel() {
  var l = window.goal.GetHeads();
  if (l.length != 2) {
    throw 'goal needs to have two heads';
  }
  window.goalin = l[0];
  window.goalout = l[1];

  // Make sure anything in stack is in the items too.
  for (var i = 0; i < window.stack.length; i++) {
    var found = false;
    for (var j = 0; j < window.items.length; j++) {
      if (window.items[j] == window.stack[i]) {
	found = true;
      }
    }
    if (!found) {
      window.items.push(window.stack[i]);
    }
  }

  // XXX Start music...?
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

function CellBall() {
  var cell = new Cell;
  cell.type = CELL_BALL;
  return cell;
}

function Item() {
  return this;
}

function MakeItem(w, h, shape) {
  var it = new Item();
  it.width = w;
  it.height = h;
  it.shape = shape;
  if (shape.length != w * h)
    throw 'bad shape';
  return it;
}

function TwoHoriz(l, r) {
  return MakeItem(2, 1, [CellHead(l, LEFT), CellHead(r, RIGHT)]);
}

function TwoVert(l, r) {
  return MakeItem(1, 2, [CellHead(l, UP), CellHead(r, DOWN)]);
}

function ThreeHoriz(l, r) {
  return MakeItem(3, 1, [CellHead(l, LEFT), 
			 CellWire(WIRE_WE),
			 CellHead(r, RIGHT)]);
}

function Level1() {
  ClearGame();
  window.goal = TwoHoriz('rca_red_m', 'rca_red_f');
  window.stack = [];
  
  var a = ThreeHoriz('rca_red_m', 'rca_red_m');
  a.onboard = true;
  a.boardx = 2;
  a.boardy = 3;
  var b = ThreeHoriz('rca_red_f', 'rca_red_f');
  b.onboard = true;
  b.boardx = 6;
  b.boardy = 3;

  window.items = [a, b];

  window.tutorial =
      ['The customer wants a RCA male-',
       'to-female connector. You can',
       'make one by connecting these',
       'two. Just drag the wire to move',
       'one.'];
  window.tutorial_test =
      function() {
	if (GetFinished()) {
	  window.tutorial =
	      ['Great! Now you can sell it.',
	       'Click the SELL button.'];
	  window.tutorial_test =
	      function () {
		if (!GetFinished()) {
		  window.tutorial =
		      ['Hmm, better put that back',
		       'together.'];
		  window.tutorial_test = null;
		}
	      };
	}
      };
  window.nextlevel = function() {
    Level2();
  };

  StartSong(song_power);

  InitLevel();
}

function Level2() {
  ClearGame();
  window.goal = TwoHoriz('rca_red_m', 'quarter_m');
  window.stack =
      [TwoHoriz('rca_red_m', 'rca_red_m'),
       ThreeHoriz('quarter_m', 'quarter_f'),
       ThreeHoriz('quarter_m', 'rca_red_f')];

  window.tutorial =
      ['You can also get some parts out',
       'of the tray on the left. Just ',
       'drag them out.'];
  window.tutorial_test =
      function () {
	if (window.stack.length == 2) {
	  window.tutorial =
	      ['You always take the top one.',
	       'Just release it in a free place.'];
	} else if (window.stack.length < 2) {
	  window.tutorial = [];
	  window.tutorial_test = null;
	}
      };

  window.nextlevel = function() {
    window.phase = PHASE_CUTSCENE;
    StartCutscene('tutorialend');
  };

  InitLevel();
}

function Level3() {
  ClearGame();
  StartSong(song_power);

  window.goal = TwoHoriz('rca_red_m', 'quarter_m');

  for (var y = 0; y < TILESH; y++) {
    for (var x = 0; x < TILESW; x++) {
      if ((y * x) % 5 > 1) {
	var it = MakeItem(1, 1, [CellBall()]);
	it.onboard = true;
	it.boardx = x;
	it.boardy = y;
	window.items.push(it);
      }
    }
  }

  var a = TwoHoriz('rca_red_m', 'usb_m');
  a.onboard = true;
  a.boardx = 10;
  a.boardy = 5;

  var b = MakeItem(11, 1,
		   [CellHead('usb_f', LEFT),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellWire(WIRE_WE),
		    CellHead('usb_f', RIGHT)]);

  var c = TwoVert('usb_m', 'quarter_m');
  c.onboard = true;
  c.boardx = 0;
  c.boardy = 6;

  window.stack = [b];

  window.items.push(a, b, c);
  
  window.tutorial =
      ['Oh yeah, sometimes there are',
       'metal balls around. I don\'t',
       'know what that\'s about.'];
  window.tutorial_test = function() {
    if (window.touched_level) {
      window.tutorial = null;
      window.tutorial_test = null;
    }
  };

  window.nextlevel = function() {
    Level4();
  };

  InitLevel();
}

function Level4() {
  ClearGame();
  StartSong(song_power);

  window.goal = TwoHoriz('rca_red_m', 'rca_red_m');

  for (var y = 0; y < TILESH; y++) {
    for (var x = 0; x < TILESW; x++) {
      if (!(x == 0 && y == 4) &&
	  !(x == 2 && y == 4) &&
	  !(x == 11 && y == 6) &&
	!((y % 2 == 0) && (x % 4) == 1) &&
	!((y % 2 == 1) && (x % 4) == 3) &&
	((x + Math.floor(y / 2)) % 2) == 0) {
	var it = MakeItem(1, 1, [CellBall()]);
	it.onboard = true;
	it.boardx = x;
	it.boardy = y;
	window.items.push(it);
      }
    }
  }

  window.stack =
      [TwoHoriz('rca_red_m', 'quarter_f'),
       ThreeHoriz('usb_m', 'rca_red_m'),
       ThreeHoriz('quarter_m', 'usb_f')];
  
  window.nextlevel = function() {
    // No, Cutscene!
    // Level5();
    window.phase = PHASE_CUTSCENE;
    StartCutscene('interlude');
  };

  InitLevel();
}

function Level5() {
  ClearGame();
  StartSong(song_power);

  window.goal = TwoHoriz('quarter_m', 'quarter_f');

  var outlet = new Item();
  outlet.width = 1;
  outlet.height = 2;
  outlet.shape = [CellHead('outlet_top', LEFT),
		  CellHead('outlet_bot', LEFT)];
  outlet.onboard = true;
  outlet.boardx = 11;
  outlet.boardy = 6;

  var iron = new Item();
  iron.width = 5;
  iron.height = 4,
  iron.shape =
      [CellHead('solder_pen', UP), null, null, null, null,
       CellWire(WIRE_NE), CellWire(WIRE_WE), CellWire(WIRE_WE), 
                                                 CellWire(WIRE_SW), null,
       null, null, null, CellWire(WIRE_NS), null,
       null, null, null, CellWire(WIRE_NE), CellHead('ac_plug', RIGHT)];
  iron.onboard = true;
  iron.boardx = 6;
  iron.boardy = 4;
  
  window.items = [iron, outlet];

  var a = ThreeHoriz('usb_m', 'livewire');
  a.onboard = true;
  a.boardx = 3;
  a.boardy = 1;
  var b = ThreeHoriz('livewire', 'quarter_m');
  b.onboard = true;
  b.boardx = 6;
  b.boardy = 1;

  window.items.push(a, b);

  window.stack =
      [TwoHoriz('quarter_f', 'usb_m'),
       TwoHoriz('usb_f', 'usb_f'),
       ThreeHoriz('rca_red_m', 'rca_red_f')];

  window.tutorial =
      ['Oh, dang. Sometimes the',
       'connectors get frayed. Use ',
       'the soldering pen to ',
       'reconnect them.'];

  window.tutorial_test =
      function () {
	for (var i = 0; i < window.items.length; i++) {
	  if (window.items[i].HasFrayed()) {
	    return;
	  }
	}
	window.tutorial = ['That\'s the ticket!'];
	window.tutorial_test = null;
      };
  
  window.nextlevel = function() {
    Level6();
  };

  InitLevel();
}

function Level6() {
  ClearGame();
  StartSong(song_power);

  window.goal = TwoHoriz('ac_plug', 'usb_m');

  window.items = [];

  window.cantakegoal = true;

  window.stack =
      [TwoHoriz('usb_m', 'rca_red_m'),
       TwoVert('quarter_f', 'quarter_m'),
       ThreeHoriz('rca_red_m', 'rca_red_f')];

  window.nextlevel = function() {
    window.phase = PHASE_CUTSCENE;
    StartCutscene('hmm');
  };

  InitLevel();
}

function Level7() {
  ClearGame();
  StartSong(song_power);

  window.goal = TwoHoriz('quarter_m', 'quarter_f');

  var outlet = new Item();
  outlet.width = 1;
  outlet.height = 2;
  outlet.shape = [CellHead('outlet_top', LEFT),
		  CellHead('outlet_bot', LEFT)];
  outlet.onboard = true;
  outlet.boardx = 11;
  outlet.boardy = 6;

  var iron = new Item();
  iron.width = 5;
  iron.height = 4,
  iron.shape =
      [CellHead('solder_pen', UP), null, null, null, null,
       CellWire(WIRE_NE), CellWire(WIRE_WE), CellWire(WIRE_WE), 
                                                 CellWire(WIRE_SW), null,
       null, null, null, CellWire(WIRE_NS), null,
       null, null, null, CellWire(WIRE_NE), CellHead('ac_plug', RIGHT)];
  iron.onboard = true;
  iron.boardx = 6;
  iron.boardy = 4;
  
  window.items = [iron, outlet];

  var a = ThreeHoriz('usb_m', 'livewire');
  a.onboard = true;
  a.boardx = 3;
  a.boardy = 1;
  var b = ThreeHoriz('livewire', 'quarter_m');
  b.onboard = true;
  b.boardx = 6;
  b.boardy = 1;

  window.items.push(a, b);

  window.stack =
      [TwoHoriz('quarter_f', 'usb_m'),
       TwoHoriz('usb_f', 'usb_f'),
       ThreeHoriz('rca_red_m', 'rca_red_f')];

  window.tutorial =
      ['Oh, dang. Sometimes the',
       'connectors get frayed. Use ',
       'the soldering pen to ',
       'reconnect them.'];

  window.tutorial_test =
      function () {
	for (var i = 0; i < window.items.length; i++) {
	  if (window.items[i].HasFrayed()) {
	    return;
	  }
	}
	window.tutorial = ['That\'s the ticket!'];
	window.tutorial_test = null;
      };
  
  window.nextlevel = function() {
    Level6();
  };

  InitLevel();
}


function Cell() {
  return this;
}

Item.prototype.HasFrayed = function() {
  for (var i = 0; i < this.shape.length; i++) {
    if (this.shape[i] && this.shape[i].type == CELL_HEAD &&
	this.shape[i].head == window.heads.livewire) {
      return true;
    }
  }
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

  return cell.facing == ReverseDir(mcell.facing) &&
      CanMate(cell.head, mcell.head);
}

function CanMate(head1, head2) {
  var ok1 = false, ok2 = false;
  for (var i = 0; i < head1.mates.length; i++)
    if (head1.mates[i] == head2)
      ok1 = true;
  if (!ok1) return false;
  for (var i = 0; i < head2.mates.length; i++)
    if (head2.mates[i] == head1)
      ok2 = true;
  return ok2;
}

function MoveX(x, dir) {
  if (dir == LEFT) return x - 1;
  else if (dir == RIGHT) return x + 1;
  else return x;
}

function MoveY(y, dir) {
  if (dir == UP) return y - 1;
  else if (dir == DOWN) return y + 1;
  else return y;
}

Item.prototype.DoSolder = function() {
  // First, find a soldering tip. There should be just one.
  if (!this.onboard) return false;
  for (var y = 0; y < this.height; y++) {
    for (var x = 0; x < this.width; x++) {
      var cell = this.shape[y * this.width + x];
      if (cell && cell.type == CELL_HEAD && 
	  cell.head == window.heads.solder_pen) {
	var gx = this.boardx + x;
	var gy = this.boardy + y;
	if (!ConnectedToOutlet(gx, gy, cell))
	  return;

	// Are we lookuing at a frayed wire?
	var dx = MoveX(gx, cell.facing);
	var dy = MoveY(gy, cell.facing);
	if (dx < 0 || dx >= TILESW ||
	    dy < 0 || dy >= TILESH)
	  return;
	var oitem = GetItemAt(dx, dy);
	if (!oitem)
	  return;
	var ocell = oitem.GetCellByGlobal(dx, dy);
	console.log(ocell);
	if (!ocell || ocell.type != CELL_HEAD || 
	    ocell.head != window.heads.livewire)
	  return;

	console.log('solderable wire at ' + XY(dx, dy));

	// OK, it's a wire. Is IT looking at a frayed wire?
	var ddx = MoveX(dx, ocell.facing);
	var ddy = MoveY(dy, ocell.facing);
	if (ddx < 0 || ddx >= TILESW ||
	    ddy < 0 || ddy >= TILESH)
	  return;
	var ooitem = GetItemAt(ddx, ddy);
	if (!ooitem)
	  return;
	var oocell = ooitem.GetCellByGlobal(ddx, ddy);
	if (!oocell || oocell.type != CELL_HEAD || 
	    oocell.head != window.heads.livewire) {
	  console.log('not wire');
	  return;
	}

	// And are they facing each other?
	if (ocell.facing != ReverseDir(oocell.facing))
	  return;

	if (oitem == ooitem) {
	  console.log('could in principle be supported but is not');
	  return;
	}

	// OK, we can do this!
	var newwire = (ocell.facing == UP || ocell.facing == DOWN) ?
	    WIRE_NS : WIRE_WE;

	// Replace with real wires.
	oitem.SafePlot(
	  dx - oitem.boardx,
	  dy - oitem.boardy,
	  CellWire(newwire));

	ooitem.SafePlot(
	  ddx - ooitem.boardx,
	  ddy - ooitem.boardy,
	  CellWire(newwire));
	
	// Copy one item into the other, delete the first. Say
	// ooitem is the source, oitem is the dest.
	var src = ooitem;
	var dst = oitem;
	
	for (var yy = 0; yy < src.height; yy++) {
	  for (var xx = 0; xx < src.width; xx++) {
	    var c = src.shape[yy * src.width + xx];
	    if (c) {
	      // NOTE! SafePlot can change dst.boardx/y so
	      // this has to be INSIDE the loop.
	      var ox = dst.boardx - src.boardx;
	      var oy = dst.boardy - src.boardy;
	      
	      dst.SafePlot(xx - ox,
			   yy - oy,
			   c);
	    }
	  }
	}

	// remove from items list.
	var newitems = [];
	for (var i = 0; i < window.items.length; i++) {
	  if (window.items[i] != src) {
	    newitems.push(window.items[i]);
	  }
	}
	window.items = newitems;

	console.log('soldered..!');
      }
    }
  }
};

// Return true if the head (must be a head, expected
// live wire or solder) is connected to an outlet.
function ConnectedToOutlet(x, y, cell) {
  var res = Trace(x, y, ReverseDir(cell.facing));
  // Has to be plugged in.
  if (!res) return false;
  var oitem = GetItemAt(res.x, res.y);
  if (!oitem) throw 'bad trace';
  var ocell = oitem.GetCellByGlobal(res.x, res.y);
  if (!ocell || ocell.type != CELL_HEAD)
    throw 'bad trace 2';
  return !!ocell.head.outlet;
}

function GetFinished() {
  // Find any open head of the goal in type.
  for (var y = 0; y < TILESH; y++) {
    for (var x = 0; x < TILESW; x++) {
      var item = GetItemAt(x, y);
      if (item != null) {
	var cell = item.GetCellByGlobal(x, y);
	if (cell != null && cell.type == CELL_HEAD &&
	    cell.head == window.goalin) {
	  var xx = MoveX(x, cell.facing);
	  var yy = MoveY(y, cell.facing);
	  if (xx >= 0 && xx < TILESW &&
	      yy >= 0 && yy < TILESH) {
	    if (null == GetItemAt(xx, yy)) {
	      // OK, it's open!
	      // Trace to make sure it reaches an end..
	      var res = Trace(x, y, ReverseDir(cell.facing));
	      if (res) {
		// console.log('trace ' + XY(x, y) + ' to ' +
		// XY(res.x, res.y) + ' dir ' + res.dir);
		var oitem = GetItemAt(res.x, res.y);
		if (!oitem)
		  throw 'bad trace';
		var ocell = oitem.GetCellByGlobal(res.x, res.y);
		if (!ocell || ocell.type != CELL_HEAD)
		  throw 'bad trace 2';
		if (ocell.head == window.goalout) {
		  // Good, as long as it's open!
		  var xxx = MoveX(res.x, ocell.facing);
		  var yyy = MoveY(res.y, ocell.facing);
		  if (xxx >= 0 && xxx < TILESW &&
		      yyy >= 0 && yyy < TILESH &&
		      null == GetItemAt(xxx, yyy)) {
		    // Finally, can't use the same space as
		    // the open start!
		    if (xxx != xx || yyy != yy) {
		      return { sx: xx, sy: yy,
			       ex: xxx, ey: yyy };
		    }
		  }
		}
	      }
	    }
	  }
	}
      }
    }
  }
  return null;
}

function Trace(x, y, dir) {
  var visited = {};
  do {
    visited[[x, y]] = true;
    x = MoveX(x, dir);
    y = MoveY(y, dir);
    var item = GetItemAt(x, y);
    if (!item) {
      console.log('fell off item at ' + XY(x, y) + '..?');
      return null;
    }
    var cell = item.GetCellByGlobal(x, y);
    if (!cell) {
      throw 'bad item';
    }

    switch (cell.type) {
      case CELL_BALL:
      return null;
      case CELL_HEAD:
      if (IsMated(x, y)) {
	if (cell.head.outlet) {
	  // XXX busted hack -- just stop on outlets
	  // since they are not really well-formed (you
	  // connect from the side)
	  return {x: x, y: y, dir: dir};
	}
	dir = dir;
	// Continue through mated heads (both source
	// and destination). Assumes well-formed items!
      } else {
	return { x: x, y: y, dir: dir };
      }
      break;
      case CELL_WIRE:
      // Turn according to wire.
      switch (dir) {
	case UP:
	if (cell.wire == WIRE_NS) dir = UP;
	else if (cell.wire == WIRE_SW) dir = LEFT;
	else if (cell.wire == WIRE_SE) dir = RIGHT;
	else return null;
	break;
	case DOWN:
	if (cell.wire == WIRE_NS) dir = DOWN;
	else if (cell.wire == WIRE_NW) dir = LEFT;
	else if (cell.wire == WIRE_NE) dir = RIGHT;
	else return null;
	break;
	case LEFT:
	if (cell.wire == WIRE_WE) dir = LEFT;
	else if (cell.wire == WIRE_NE) dir = UP;
	else if (cell.wire == WIRE_SE) dir = DOWN;
	else return null;
	break;
	case RIGHT:
	if (cell.wire == WIRE_WE) dir = RIGHT;
	else if (cell.wire == WIRE_NW) dir = UP;
	else if (cell.wire == WIRE_SW) dir = DOWN;
	else return null;
	break;
      }
      break;
    }

  } while (!visited[[x, y]]);
  // This is certainly possible by making a cycle of
  // connectors, but when would we trace such a thing?
  // (maybe to test for self-connected outlet?)
  // console.log('cycle?');
  return null;
}

function DrawCutscene() {
  var cuts = window.cutscenes[window.cutscene];
  if (!cuts) throw 'invalid cutscene';
  var cs = cuts.desc[window.cutscene_idx];
  if (!cs) throw 'invalid cutscene idx';

  var predelay = cs.predelay || 10;
  DrawFrame(cs.f, 0, 0);
  window.cutscene_frames++;
  if (window.cutscene_ffwd) window.cutscene_frames += 3;
  if (window.cutscene_frames >= predelay) {
    DrawFrame(window.deskbubbleframes, DESKBUBBLEX, DESKBUBBLEY);
    var charsleft = 
	// 1 char per frame, seems fine
	window.cutscene_frames - predelay;

    var lines = cs.t;
    for (var i = 0; i < lines.length; i++) {
      var s = (lines[i].length <= charsleft) ?
	  lines[i] :
	  lines[i].substring(0, charsleft);
      charsleft -= s.length;
      font.Draw(ctx, CUTSCENETEXTX, 
		CUTSCENETEXTY + FONTH * i,
		s);
    }
    
    if (charsleft > 0) {
      // Allow continuing.
      // (draw 'CLICK' indicator?)
      window.cutscene_ready = true;
      window.cutscene_ffwd = false;
    }
  }
}

function StartCutscene(name) {
  window.phase = PHASE_CUTSCENE;

  window.cutscene = name;
  window.cutscene_idx = 0;
  window.cutscene_frames = 0;
  window.cutscene_ffwd = false;
  window.cutscene_ready = false;
  
  var cuts = window.cutscenes[window.cutscene];
  if (!cuts) throw 'invalid cutscene';
  var cs = cuts.desc[window.cutscene_idx];
  if (!cs) throw 'invalid cutscene idx';

  if (song != cs.s) {
    StartSong(cs.s);
  }
}

function DrawPuzzle() {
  if (tutorial_test) tutorial_test();

  // ClearScreen();
  DrawFrame(window.boardbg, 0, 0);

  for (var i = 0; i < window.items.length; i++) {
    window.items[i].DoSolder();
  }

  var fin = GetFinished();
  if (fin) {
    DrawFrame(window.highlightin,
	      BOARDSTARTX + fin.sx * TILESIZE,
	      BOARDSTARTY + fin.sy * TILESIZE);
    DrawFrame(window.highlightout,
	      BOARDSTARTX + fin.ex * TILESIZE,
	      BOARDSTARTY + fin.ey * TILESIZE);
    DrawFrame(window.sellframes, SELLX, SELLY);
  }

  // Draw items and I/O indicators
  for (var y = 0; y < TILESH; y++) {
    for (var x = 0; x < TILESW; x++) {
      var item = GetItemAt(x, y);
      if (item != null) {
        var cell = item.GetCellByGlobal(x, y);
        if (!cell) throw 'bug';
        if (cell.type == CELL_HEAD) {
	  // if (cell.head == window.heads.solder_pen)
	  // console.log(cell);
	  var is_live =
	      (cell.head == window.heads.livewire ||
	       cell.head == window.heads.solder_pen) &&
	      ConnectedToOutlet(x, y, cell);
	  // PERF
          var frame = (is_live || IsMated(x, y)) ?
	      cell.head.mated[cell.facing] :
	      cell.head.unmated[cell.facing];
          DrawFrame(frame,
                    BOARDSTARTX + x * TILESIZE,
                    BOARDSTARTY + y * TILESIZE);
        } else if (cell.type == CELL_WIRE) {
	  DrawFrame(window.wireframes[cell.wire],
		    BOARDSTARTX + x * TILESIZE,
		    BOARDSTARTY + y * TILESIZE);
        } else if (cell.type == CELL_BALL) {
	  DrawFrame(window.ballframes,
		    BOARDSTARTX + x * TILESIZE,
		    BOARDSTARTY + y * TILESIZE);
	}
      } else {
	// No item. Then maybe an indicator.
      }
    }
  }

  // Draw tray...
  for (var i = 0; i < window.stack.length; i++) {
    // XXX max depth
    DrawHeads(window.stack[i], TRAYPLACEX, TRAYPLACEY + i * TILESIZE);
  }

  // Draw goal...
  if (window.goal) {
    // (implement 'taking' the goal, in which case it should
    // not be drawn.)
    // DrawFloatingItem(window.goal, GOALPLACEX, GOALPLACEY);
    DrawHeads(window.goal, GOALPLACEX, GOALPLACEY);
  }

  // Tutorial on top of most things...
  if (window.tutorial) {
    var starty = HEIGHT - FONTH * window.tutorial.length;
    for (var i = 0; i < window.tutorial.length; i++) {
      font.Draw(ctx, TUTORIALX, starty + i * FONTH, window.tutorial[i]);
    }
  }

  // Floating should be near the end!

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
    // (when that's the case)

    // Draw the item itself.
    DrawFloatingItem(it, cx, cy);
  }

  // Draw indicators (e.g. 'in', 'out')

}

Item.prototype.GetHeads = function() {
  var l = [];
  for (var i = 0; i < this.shape.length; i++) {
    if (this.shape[i] && this.shape[i].type == CELL_HEAD) {
      l.push(this.shape[i].head);
    }
  }
  return l;
};

function DrawHeads(it, x, y) {
  var l = it.GetHeads();
  if (l.length != 2) {
    console.log('item without two heads?');
    return;
  }
  DrawFrame(l[0].unmated[LEFT], x, y);
  DrawFrame(l[1].unmated[RIGHT], x + TILESIZE, y);
}

function DrawFloatingItem(it, cx, cy) {
  for (var y = 0; y < it.height; y++) {
    for (var x = 0; x < it.width; x++) {
      var cell = it.GetCell(x, y);
      if (cell) {
	if (cell.type == CELL_HEAD) {
	  // Always unmated when floating.
	  DrawFrame(cell.head.unmated[cell.facing],
		    cx + x * TILESIZE,
		    cy + y * TILESIZE);
	} else if (cell.type == CELL_WIRE) {
	  DrawFrame(window.wireframes[cell.wire],
		    cx + x * TILESIZE,
		    cy + y * TILESIZE);
	} else if (cell.type == CELL_BALL) {
	  DrawFrame(window.ballframes,
		    cx + x * TILESIZE,
		    cy + y * TILESIZE);
	}
      }
    }
  }
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
	if (cell && (cell.type == CELL_HEAD || 
		     cell.type == CELL_WIRE ||
		     cell.type == CELL_BALL)) {
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

function CanvasMousedownPuzzle(x, y) {
  if (window.floating || window.dragging) {
    // behave as mousedown if we're holding something, since these
    // are not always actually bracketed. Don't add another one!
    CanvasMouseupPuzzle(x, y);
    return;
  }

  // If in the tray section, then we create a new piece and
  // start floating it.

  if (x >= TRAYX && y >= TRAYY &&
      x <= (TRAYX + TRAYW) &&
      y <= (TRAYY + TRAYH)) {
    window.touched_level = true;
    console.log('touch in tray');

    if (window.floating || window.dragging)
      throw 'already established';

    if (window.stack.length > 0) {
      var it = window.stack[0];
      window.stack.splice(0, 1);
      window.floating = it;
      // if not on board, then that always means floating,
      // which means wherever the mouse is.
      it.onboard = false;
    } else {
      // Say some message...
    }

  } else if (x >= SELLX && y >= SELLY &&
	     x < (SELLX + SELLW) &&
	     y < (SELLY + SELLH)) {
    
    window.touched_level = true;
    var fin = GetFinished();
    if (fin) {
      // OK, can sell...
      window.nextlevel();
    }

  } else if (window.cantakegoal &&
	     x >= GOALX && y >= GOALY &&
	     x <= (GOALX + GOALW) &&
	     y <= (GOALY + GOALH)) {

    if (window.goal) {
      var it = window.goal;
      window.goal = null;
      window.floating = it;

      window.tutorial = ['Whoa now. What are you doing?'];
      window.tutorial_test =
	  function () {
	    if (window.floating == null) {
	      window.tutorial = null;
	      window.tutorial_test = null;
	    }
	  };
    }

  } else {

    window.touched_level = true;
    // In board? -- pick up piece?
    var boardx = Math.floor((x - BOARDSTARTX) / TILESIZE);
    var boardy = Math.floor((y - BOARDSTARTY) / TILESIZE);
    // console.log('touch maybe in board ' + boardx + ', ' + boardy);

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
	if (cell.head.outlet) {
	  console.log('cannot drag outlets');
	  return;
	}
	window.dragging =
	    { it: it,
	      x: boardx,
	      y: boardy };
      } else if (cell.type == CELL_BALL) {
	console.log('cannot drag balls');
	return;
      }
    }
  }

}

function CanvasMousedownCutscene(x, y) {
  window.cutscene_ffwd = true;
  if (window.cutscene_ready) {
    window.cutscene_ready = false;
    window.cutscene_ffwd = false;
    window.cutscene_idx++;
    window.cutscene_frames = 0;
    var cuts = window.cutscenes[window.cutscene];
    if (!cuts) throw 'bad cutscene?';
    if (window.cutscene_idx >= cuts.desc.length) {
      // Avoid re-entrance, but the continuation
      // had better move to a new phase!
      window.cutscene = null;
      cuts.cont();
    }
  }
}

function CanvasMouseupCutscene(x, y) {
  window.cutscene_ffwd = false;
}

function CanvasMousedown(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);

  switch (window.phase) {
    case PHASE_PUZZLE:
    return CanvasMousedownPuzzle(x, y);
    break;
    case PHASE_TITLE:
    if (x >= DOORX && x <= (DOORX + DOORW) &&
	y >= DOORY && y <= (DOORY + DOORH)) {
      ClearSong();
      window.phase = PHASE_CUTSCENE;
      StartCutscene('intro');
    }
    break;
    case PHASE_CUTSCENE:
    return CanvasMousedownCutscene(x, y);
    break;
  }
}

function CanvasMouseupPuzzle(x, y) {
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

function CanvasMouseup(e) {
  e = e || window.event;
  var bcx = bigcanvas.canvas.offsetLeft;
  var bcy = bigcanvas.canvas.offsetTop;
  var x = Math.floor((event.pageX - bcx) / PX);
  var y = Math.floor((event.pageY - bcy) / PX);

  switch (window.phase) {
    case PHASE_PUZZLE:
    return CanvasMouseupPuzzle(x, y);
    break;
    case PHASE_TITLE:
    // ignored
    break;
    case PHASE_CUTSCENE:
    return CanvasMouseupCutscene(x, y);
    break;
  }
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

  // If we use movement anywhere else (unlikely!) then
  // do the switch thing.
  if (window.phase != PHASE_PUZZLE) return;

  if (window.dragging) {
    var Detach = function () {
      window.floating = window.dragging.it;
      window.floating.onboard = false;
      window.dragging = null;
    };

    var boardx = Math.floor((x - BOARDSTARTX) / TILESIZE);
    var boardy = Math.floor((y - BOARDSTARTY) / TILESIZE);
    // console.log('touch maybe in board ' + boardx + ', ' + boardy);

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
	  if (ocell.type == CELL_HEAD || ocell.type == CELL_BALL) {
	    console.log('run into other head/ball');
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
  console.log('safe-plot: ', XY(dx, dy), cell);
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

function Draw() {
  switch (window.phase) {
    case PHASE_TITLE:
    DrawFrame(window.titleframes, 0, 0);
    break;
    case PHASE_CUTSCENE:
    DrawCutscene();
    break;
    case PHASE_PUZZLE:
    DrawPuzzle();
    break;
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

  UpdateSong();

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

  window.phase = PHASE_TITLE;
  StartSong(song_theme);

  bigcanvas.canvas.onmousemove = CanvasMove;
  bigcanvas.canvas.onmousedown = CanvasMousedown;
  bigcanvas.canvas.onmouseup = CanvasMouseup;

  // XXX not this!
  // WarpTo('beach', 77, 116);
  // SetPhase(PHASE_PLAYING);

  start_time = (new Date()).getTime();
  window.requestAnimationFrame(Step);
}

document.onkeydown = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  switch (e.keyCode) {
    case 49: window.phase = PHASE_PUZZLE; Level1(); break;
    case 50: window.phase = PHASE_PUZZLE; Level2(); break;
    case 51: window.phase = PHASE_PUZZLE; Level3(); break;
    case 52: window.phase = PHASE_PUZZLE; Level4(); break;
    case 53: window.phase = PHASE_PUZZLE; Level5(); break;
    case 54: window.phase = PHASE_PUZZLE; Level6(); break;
    case 55: window.phase = PHASE_PUZZLE; Level7(); break;
    case 9:
    if (window.cutscene) {
      var cuts = window.cutscenes[window.cutscene];
      if (cuts) {
	window.cutscene = null;
	cuts.cont();
      }
    }
    break;
    case 27: // ESC
    if (true || DEBUG) {
      ClearSong();
      document.body.innerHTML =
	  '<b style="color:#fff;font-size:40px">(SILENCED. ' +
          'RELOAD TO PLAY)</b>';
      Step = function() { };
      // n.b. javascript keeps running...
    }
    break;
  }
};

resources.WhenReady(Start);
