
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

var TRAYX = 6;
var TRAYY = 12;
var TRAYW = 51;
var TRAYH = 178;

var CELL_HEAD = 1;
var CELL_WIRE = 2;
// etc.?

var WIRE_NS = 1;
var WIRE_WE = 2;
var WIRE_SE = 3;
var WIRE_SW = 4;
var WIRE_NE = 5;
var WIRE_NW = 6;


var FONTW = 9;
var FONTH = 16;
var FONTOVERLAP = 1;
var FONTCHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
    "abcdefghijklmnopqrstuvwxyz0123456789`-=" +
    "[]\\;',./~!@#$%^&*()_+{}|:\"<>?";
