
// Config
var FASTMODE = false;

var MUSIC = !FASTMODE;

// In screen pixels.
var SCREENW = 840;
var SCREENH = 600;


// Size of arena in unscaled pixels.
var ARENAW = 580 * 3;
var ARENAH = 320 * 3;

var ICEMINX = 35 * 3;
var ICEMAXX = 540 * 3;
var ICEMAXY = 270 * 3;
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
var FACEOFF2X = 286 * 3;
var FACEOFF2Y = 166 * 3;
var FACEOFF3X = FACEOFF0X;
var FACEOFF3Y = 224 * 3;
var FACEOFF4X = FACEOFF1X;
var FACEOFF4Y = FACEOFF3Y;

var USAGOALIEX = 103 * 3;
var CANGOALIEX = 471 * 3;
var GOALIEY = 145 * 3;
var GOALH = 48 * 3;

// Location of bottom boards overlay.
var BOTTOMBOARDSX = 32 * 3;
var BOTTOMBOARDSY = 212 * 3;

var PUCKH = 4 * 3;

var PUCKCLIPW = 4 * 3;
var PUCKCLIPH = 3 * 3;

// Nominal player width. The actual sprites
// are larger than this.
var PLAYERW = 14 * 3;
var PLAYERC = PLAYERW / 2;
// Height of the graphic.
var PLAYERH = 25 * 3;
var PLAYERCLIPHEIGHT = 6 * 3;

var COLLIDEDIST = 6 * 3;

// Distance from the center of the player to
// the center of where the player carries the
// puck.
var PLAYERTOPUCK = 11 * 3;
var PICKUPDIST = 11 * 3;

var PICKUPSTICKDIST = 13 * 3;

var SPLATTIME = 24;
var GETUPTIME = 12;
var FOLLOWTHROUGHTIME = 6;

var FULLSTRENGTHTIME = 24;

var RIGHT = 0;
var LEFT = 1;

var USA = 0;
var CAN = 1;
var REF = 2;

///////////////
// Sounds.
var NHURT = 4;
var NBOUNCE = 3;

///////////////
// Physics.

var MAXVELOCITYX = 8;
var MAXVELOCITYY = 5.6;
var ICEFRICTION = 0.96;
var SHOTSTRENGTH = 25;

var PLAYERACCEL = 2.0;

//////////////
// Title stuff

var TITLESELX = 74 * 3;
var TITLESELY = 95 * 3;
var TITLESELHEIGHT = 20 * 3;

/////////////
// Info stuff

// These unusually are in png pixels, not screen pixels.
var FONTW = 9;
var FONTH = 16;
var FONTOVERLAP = 1;
var FONTCHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?";

var INFOLINES = 2;
var INFOHEIGHT = INFOLINES * FONTH * 3;
var INFOMARGINX = 0 * 3;
var INFOMARGINY = 0 * 3;

/////////
// Depths.

// Title stuff
var BGIMAGEDEPTH = 290;
var TITLESELDEPTH = 295;

var MUSICDEPTH = 80;

var RINKDEPTH = 200;
var HALODEPTH = 210;

// Need to be sorted by y index, so
// we reserve 9000 indices just for stuff
// on the ice.
var ICESTUFFDEPTH = 1000;  // - 10000

var PUCKSOUNDDEPTH = 299;
var PLAYERSOUNDDEPTH = 300;  // - 350

// Within a player movieclip
var PPLAYERDEPTH = 10;

var BOTTOMBOARDSDEPTH = 50000;

var INFODEPTH = 60000;

