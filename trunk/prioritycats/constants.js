
// This map data is loaded by both the editor (JavaScript)
// and Flash (ActionScript), so it needs to be compatible
// with both syntaxes.

// Real width and height in native pixels.
// n.b. you also need to change the width and height in CSS
// in editor.html.
var WIDTH = 50;
var HEIGHT = 50;

// Dimensions of a real room in tiles (like in the
// map editor.)
var TILESW = 16;
var TILESH = 11;
// Dimension of a room when shown on the screen,
// including the one tile border.
// var SCREENTILESW = 18;
// var SCREENTILESH = 13;


// z depths, just used in flash.
var BGIMAGEDEPTH = 300;
var PUPILDEPTH = 310;
var BGTILEDEPTH = 400;
var FGTILEDEPTH = 6000;
var LASERDEPTH = 15000;
var LASERSDEPTH = 15500;

// XXX should be between bg and fg.
var CATDEPTH = 10000;

// Height of game area (not counting status bar or border).
// XXX used for doors only. redo for new regime.
var GAMESCREENWIDTH = WIDTH * TILESW;
var GAMESCREENHEIGHT = HEIGHT * TILESH;

// Bounds of 'start' button on title, native
var TITLESTARTX1 = 178 + 25;
var TITLESTARTY1 = 272 + 25;
var TITLESTARTX2 = 227 + 25;
var TITLESTARTY2 = 288 + 25;

var TITLELASERW = 25;
var TITLELASERH = 25;

// XXX maybe should be in Cat.as or whatever.

// Standard head, right-facing body. Everything
// in native pixels.
var HEADW = 15;
var HEADH = 14;

// This is the offset from the head's top-left
// corner to the "center of the neck" on the
// body.
var HEADATTACHX = 6;
var HEADATTACHY = 9;


var ORANGE_STATIONARY_FRAMES = 10;

var LASERROOMX1 = 27 + 25;
var LASERROOMY1 = 27 + 25;
var LASERROOMX2 = 373 + 25;
var LASERROOMY2 = 224 + 25;
