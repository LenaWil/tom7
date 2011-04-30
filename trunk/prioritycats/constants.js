
// This map data is loaded by both the editor (JavaScript)
// and Flash (ActionScript), so it needs to be compatible
// with both syntaxes.

// Real width and height in native pixels.
// n.b. you also need to change the width and height in CSS
// in editor.html.
var WIDTH = 50;
var HEIGHT = 50;

// Dimensions of a room in tiles.
var TILESW = 16;
var TILESH = 11;

// z depths, just used in flash.
var BGIMAGEDEPTH = 300;
var PUPILDEPTH = 310;
var BGTILEDEPTH = 400;
var FGTILEDEPTH = 6000;
var LASERDEPTH = 15000;

var CATDEPTH = 5000;

// Height of game area (not counting status bar).
var GAMESCREENWIDTH = WIDTH * TILESW;
var GAMESCREENHEIGHT = HEIGHT * TILESH;

// Bounds of 'start' button on title, native
var TITLESTARTX1 = 178;
var TITLESTARTY1 = 272;
var TITLESTARTX2 = 227;
var TITLESTARTY2 = 288;

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

