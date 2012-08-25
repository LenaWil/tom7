var SCREENWIDTH = 832;
var SCREENHEIGHT = 700;

var SCREENGAMEWIDTH = SCREENWIDTH;
var SCREENGAMEHEIGHT = 624;

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
var XMARGIN = TILEWIDTH * 2;
var YMARGIN = TILEHEIGHT * 2;
var XMARGINR = TILEWIDTH * 2 + YOUWIDTH;
var YMARGINB = TILEHEIGHT * 2 + YOUHEIGHT;

var DIALOGW = 265;
var DIALOGH = 150;
var DIALOGMARGINX = 16;
var DIALOGMARGINY = 16;

var FONTW = 9;
var FONTH = 16;
var FONTOVERLAP = 1;
var FONTCHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?";

/////////
// Depths

// z depths, just used in flash.
var BGIMAGEDEPTH = 290;

// There are four world panels loaded at any given time,
// which occupy these depths.
var WORLDDEPTH = 300; // - 304

var YOUDEPTH = 1000;

var DIALOGDEPTH = 2000;

////////////
// Landmarks

// These landmarks are always in world pixels.
var STARTX = 3919;
var STARTY = 3459;


