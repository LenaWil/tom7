
// In screen pixels.
var SCREENW = 840;
var SCREENH = 600;


// Size of arena in unscaled pixels.
var ARENAW = 580 * 3;
var ARENAH = 320 * 3;

var ICEMINX = 35 * 3;
var ICEMAXX = 540 * 3;
var ICEMAXY = 263 * 3;
var ICEMINY = 72 * 3;

var USAX = 249 * 3;
var USAY = 32 * 3;

var CANX = 313 * 3;
var CANY = 32 * 3;

var TIMEX = 275 * 3;
var TIMEY = 32 * 3;

var FACEOFF0X = 151 * 3;
var FACEOFF0Y = 112 * 3;
var FACEOFF1X = 423 * 3;
var FACEOFF1Y = FACEOFF0Y;
var FACEOFF2X = 287 * 3;
var FACEOFF2Y = 167 * 3;
var FACEOFF3X = FACEOFF0X;
var FACEOFF3Y = 224 * 3;
var FACEOFF4X = FACEOFF1X;
var FACEOFF4Y = FACEOFF3Y;

var USAGOALIEX = 103 * 3;
var CANGOALIEX = 471 * 3;
var GOALIEY = 145 * 3;

// Nominal player width. The actual sprites
// are larger than this.
var PLAYERW = 14 * 3;
var PLAYERC = PLAYERW / 2;
// Height of the graphic.
var PLAYERH = 25 * 3;

// Distance from the center of the player to
// the center of where the player carries the
// puck.
var PLAYERTOPUCK = 11 * 3;

var RIGHT = 0;
var LEFT = 1;

var USA = 0;
var CAN = 1;
var REF = 2;

///////////////
// Physics.

var MAXVELOCITYX = 5;
var MAXVELOCITYY = 3;

//////////////
// Title stuff

var TITLESELX = 74 * 3;
var TITLESELY = 95 * 3;
var TITLESELHEIGHT = 20 * 3;

/////////
// Depths.

// Title stuff
var BGIMAGEDEPTH = 290;
var TITLESELDEPTH = 295;

var RINKDEPTH = 200;
var HALODEPTH = 210;

// Need to be sorted by y index, so
// we reserve 1000 indices just for stuff
// on the ice.
var ICESTUFFDEPTH = 1000;  // - 2000


// Within a player movieclip
var PPLAYERDEPTH = 10;