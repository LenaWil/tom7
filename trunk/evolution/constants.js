var SCREENWIDTH = 832;
var SCREENHEIGHT = 700;

var SCREENGAMEWIDTH = SCREENWIDTH;
var SCREENGAMEHEIGHT = 624;

var STATUSHEIGHT = SCREENGAMEHEIGHT - SCREENHEIGHT;

// Game area (one screen) width and height in world pixels.
var WIDTH = 416;
var HEIGHT = 312;

// Dimensions of the screen in tiles.
var TILESW = 16;
var TILESH = 12;

// In game pixels (2x2).
var TILEWIDTH = 26;
var TILEHEIGHT = 26;


// Dimensions of the world in tiles.
var WORLDTILESW = 384;
var WORLDTILESH = 384;

var WORLDPIXELSW = WORLDTILESW * TILEWIDTH;
var WORLDPIXELSH = WORLDTILESW * TILEHEIGHT;

var YOUWIDTH = 48;
var YOUHEIGHT = 64;

// actually creates four tiles of margin
var XMARGIN = TILEWIDTH * 3;
var YMARGIN = TILEHEIGHT * 3;
var XMARGINR = TILEWIDTH * 3 + YOUWIDTH;
var YMARGINB = TILEHEIGHT * 3 + YOUHEIGHT;

var DIALOGW = 265;
var DIALOGH = 150;
var DIALOGMARGINX = 16;
var DIALOGMARGINY = 16;

var FONTW = 9;
var FONTH = 16;
var FONTOVERLAP = 1;
var FONTCHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?";

var FRAMES_TO_HYPER = 20;

/////////
// Depths

// z depths, just used in flash.
var BGIMAGEDEPTH = 290;

// There are four world panels loaded at any given time,
// which occupy these depths.
var WORLDDEPTH = 300; // - 304

var STUFFDEPTH = 350;

var YOUDEPTH = 1000;

var DIALOGDEPTH = 2000;

var STATUSDEPTH = 3000;

////////////
// Landmarks

// These landmarks are always in world pixels.

var SCIENCEX1 = 2622;
var SCIENCEY1 = 4121;
var SCIENCEX2 = 2805;
var SCIENCEY2 = 4323;


// treehouse
// var STARTX = 3919;
// var STARTY = 3459;

// hyper engineer
var STARTX = 5570;
var STARTY = 8604;

// lhc
// var STARTX = SCIENCEX1;
// var STARTY = 4121 - 200;

// shell
// var STARTX = 8807;
// var STARTY = 7245;

// miners
// var STARTX = 7562;
// var STARTY = 6577;


// enter mines
// var STARTX = 4184;
// var STARTY = 5164;
