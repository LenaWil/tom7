
// Config
var FASTMODE = false;

// var MUSIC = !FASTMODE;
var MUSIC = true;
var CHEATS = true;

// In screen (real) pixels.
var SCREENW = 600;
var SCREENH = 700;

var SCALE = 2;

// Locations in game pixels.
var BOARDX = 16;
var BOARDY = 48;

var TIMERX = 17;
var TIMERY = 2;
var TIMERW = 270;
var TIMERH = 9;

var POINTSX = BOARDX;
var POINTSY = 15;

var BLOCKW = 16;
var BLOCKH = 16;

// In blocks.
var TILESW = 17;
var TILESH = 17;

var GAMEW = TILESW * BLOCKW;
var GAMEH = TILESH * BLOCKH;

var BREG1 = 0;
var BREG2 = 1;
var BREG3 = 2;
var BVERT = 3;
var BHORIZ = 4;
var BSILVER = 5;
var B0 = 6;
var B1 = 7;
var B2 = 8;
var B3 = 9;
var B4 = 10;
var B5 = 11;
var B6 = 12;
var B7 = 13;
var B8 = 14;
var B9 = 15;
var BBREAK = 16;
var BBLUE = 17;
var BRED = 18;
var BAIR = 19;
var BAIRBORDER = 20;

var NREG = 3;
var NPICK = 16;
var NBLOCKS = 21;
var NPOINTS = 10;

var BREAKFRAMES = 10;
var NBREAKANIM = 4;

// punch width and depth
var PUNCHW = 4;
var PUNCHD = 2;

var CREATEW = 12;
var CREATED = 12;

var CAPW = 6;

var PFALL = 7;
var PGROWTH = 8;
var PSOKO = 9;
var PTHINK = 5;
var PHURT = 1;

// How many pixels does the player extend up and to the left
// of the origin?
var PLAYERLAPX = 0;
var PLAYERLAPY = 10;

var POINTSOVERLAP = 3;

// How many pixels into the player do we test for the
// left foot?
var LEFTFOOT = 4;
// XXX is it -1?
var RIGHTFOOT = BLOCKW - 4 - 1;

// Y offset from player x,y (not graphic) that should be considered
// the player's head (for clipping).
var HEAD = 4;
// The last pixel in the block, not the one below.
var FEET = BLOCKW - 1;


// Game tuning...
// Nominal FPS. Must match timeline setting.
var FPS = 30;
var FRAMESPERAIR = 5;

// When suffocating, breathe every this many frames.
var BREATHEEVERY = FPS * 2;

/////////////
// Info stuff

// These unusually are in png pixels, not screen pixels.
var FONTW = 9;
var FONTH = 16;
var FONTOVERLAP = 1;
var FONTCHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?";

var INFOLINES = 1;
var INFOHEIGHT = INFOLINES * FONTH * SCALE;
var INFOMARGINX = 8 * SCALE;
var INFOMARGINY = 8 * SCALE;

/////////
// Depths.

var TITLEDEPTH = 289;
var BGIMAGEDEPTH = 290;
var GAMEDEPTH = 300;
var TIMERDEPTH = 305;
var POINTSDEPTH = 310;
// var TITLESELDEPTH = 295;

// Basically should be in front of all game stuff?
var PLAYERDEPTH = 1000;

var INFODEPTH = 9000;

var BGMUSICDEPTH = 80;
var BGMUSICDEPTH2 = 81;
var SFXDEPTH = 85;
