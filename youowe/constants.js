
var DEBUG = false; // true;

var WIDTH = 320;
var HEIGHT = 200;
var PX = 3;
var MINFRAMEMS = 25.0;
// (33.34)

var GAMEHEIGHT = 128;
var WALLHEIGHT = 87;

var ME_HEIGHT = 32;
var ME_FEET = 3;

// ?
var TOP = 24;

// Registration is to the bottom center of the player.


// Physics
var GRAVITY = 0.8;
var JUMP_IMPULSE = 6;
var ACCEL_X = 0.6;
var ACCEL_Y = 0.2;
var AIR_ACCEL_X = 0.25;
var TERMINAL_X = 4;
var TERMINAL_Y = 2;
var TERMINAL_Z = 8;

// Fighting
var ATTACKSIZE_Y = 6;
var ATTACKSIZE_X = 14;
var HALFPERSON_W = 8;

var PUNCHFRAMES = 5;
var KICKFRAMES = 9;
// Needs to be < PUNCHFRAMES - 2, or else
// infinite punch combo is possible
var HURTFRAMES = 2;
var KOFRAMES = 40;
var DEADFRAMES = 60;

var PUNCH_DAMAGE = 2;
var KICK_DAMAGE = 3;


var FONTW = 9;
var FONTH = 16;
var FONTOVERLAP = 1;
var FONTCHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
    "abcdefghijklmnopqrstuvwxyz0123456789`-=" +
    "[]\\;',./~!@#$%^&*()_+{}|:\"<>?";
