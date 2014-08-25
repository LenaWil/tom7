
var DEBUG = false; // true;

var WIDTH = 320;
var HEIGHT = 200;
var PX = 3;
var MINFRAMEMS = 25.0;

var TILESIZE = 20;

var TILESW = 12;
var TILESH = 8;

var BOARDSTARTX = 68;
var BOARDSTARTY = 20;

var PHASE_TITLE = 1;
var PHASE_CUTSCENE = 2;
var PHASE_PUZZLE = 3;
// and end, ...

var DOORX = 30;
var DOORY = 91;
var DOORW = 64;
var DOORH = 109;

// Order is assumed.
var UP = 0;
var DOWN = 1;
var LEFT = 2;
var RIGHT = 3;
function ReverseDir(d) {
  switch (d) {
    case UP: return DOWN;
    case DOWN: return UP;
    case LEFT: return RIGHT;
    case RIGHT: return LEFT;
  }
  return undefined;
}

var TUTORIALX = 64;

var CUTSCENETEXTX = 149;
var CUTSCENETEXTY = 5;

var INDICATOR_IN = 1;
var INDICATOR_OUT = 2;
var INDICATOR_BOTH = 3;

var TRAYX = 6;
var TRAYY = 12;
var TRAYW = 51;
var TRAYH = 108;

var TRAYPLACEX = 11;
var TRAYPLACEY = 25;

var SELLX = 6;
var SELLY = 122;
var SELLW = 51;
var SELLH = 29;

var CELL_HEAD = 1;
var CELL_WIRE = 2;
var CELL_BALL = 3;
// etc.?

var DESKBUBBLEX = 134;
var DESKBUBBLEY = 0;

var WIRE_NS = 1;
var WIRE_WE = 2;
var WIRE_SE = 3;
var WIRE_SW = 4;
var WIRE_NE = 5;
var WIRE_NW = 6;

// goal box
var GOALX = 6;
var GOALY = 153;
var GOALW = 51;
var GOALH = 37;

// where the goal piece goes
var GOALPLACEX = 11;
var GOALPLACEY = 164;

var MAXHANDTIME = 100;

var FONTW = 9;
var FONTH = 16;
var FONTOVERLAP = 1;
var FONTCHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
    "abcdefghijklmnopqrstuvwxyz0123456789`-=" +
    "[]\\;',./~!@#$%^&*()_+{}|:\"<>?";
