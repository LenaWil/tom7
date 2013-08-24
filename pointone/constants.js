
// Config
var FASTMODE = false;

var MUSIC = !FASTMODE;

// In screen (real) pixels.
var SCREENW = 600;
var SCREENH = 700;

var SCALE = 2;

// Locations in game pixels.
var BOARDX = 16;
var BOARDY = 48;

var BLOCKW = 16;
var BLOCKH = 16;

// In blocks.
var TILESW = 17;
var TILESH = 17;

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

var NREG = 3;
var NBLOCKS = 16;

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
// var TITLESELDEPTH = 295;

var INFODEPTH = 9000;

var BGMUSICDEPTH = 80;
