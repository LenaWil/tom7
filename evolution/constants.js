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

// actually creates two tiles of margin
var XMARGIN = TILEWIDTH;
var YMARGIN = TILEHEIGHT;
var XMARGINR = TILEWIDTH + YOUWIDTH;
var YMARGINB = TILEHEIGHT + YOUHEIGHT;

/////////
// Depths

// z depths, just used in flash.
var BGIMAGEDEPTH = 290;

// There are four world panels loaded at any given time,
// which occupy these depths.
var WORLDDEPTH = 300; // - 304

var YOUDEPTH = 1000;

////////////
// Landmarks

// These landmarks are always in world pixels.
var STARTX = 6145;
var STARTY = 3933;


