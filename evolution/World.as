import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class World {

  #include "constants.js"

  // The movieclips holding the current graphics.

  var currentmusic = null;
  var backgroundmusic = null;

  var mask : BitmapData = null;

  var tlbg : MovieClip = null;
  var trbg : MovieClip = null;
  var blbg : MovieClip = null;
  var brbg : MovieClip = null;

  var mapwidth = 0;
  var tilemap = {};
  public function init() {

    mask = BitmapData.loadBitmap("mask.png");

    tlbg = _root.createEmptyMovieClip("tlbg", WORLDDEPTH + 1);
    trbg = _root.createEmptyMovieClip("trbg", WORLDDEPTH + 2);
    blbg = _root.createEmptyMovieClip("blbg", WORLDDEPTH + 3);
    brbg = _root.createEmptyMovieClip("brbg", WORLDDEPTH + 4);
    trace('init world');
  }

  // Give the screen x and y coordinates; load the corresponding
  // bitmap into the movie clip.
  public function loadBits(mc, sx, sy) {
    var png = "screen_" + sx + "_" + sy + ".png";
    var bm : BitmapData = BitmapData.loadBitmap(png);
    var bm2x : BitmapData =
      new BitmapData(WIDTH * 2,
                     HEIGHT * 2,
                     // No transparency.
                     false, 0);
    var grow = new Matrix();
    grow.scale(2, 2);
    bm2x.draw(bm, grow);
    mc.attachBitmap(bm2x,
                    // depth: always the same
                    10);
  }

  // Takes world pixel coordinates.
  public function solidAt(x, y) {
    var tilex = int(x / TILEWIDTH);
    var tiley = int(y / TILEHEIGHT);

    // Pretend the whole world is surrounded by solids.
    if (tilex < 0 || tiley < 0 ||
        tilex >= WORLDTILESW ||
        tiley >= WORLDTILESH) return true;

    var pix : Number = mask.getPixel32(tilex, tiley);
    var aa = pix >> 24 & 0xFF;

    // Treat as solid if more than 50% alpha.
    // XXX Should allow for more kinds of information here, based
    // on the color?
    return aa > 0x70;
  }

  var scrollx : Number = 0;
  var scrolly : Number = 0;

  public function scrollToShow(x, y) {
    // Scrollx and scrolly are world coordinates too.

    // Scroll as little as possible.
    if (x - scrollx < XMARGIN) scrollx = x - XMARGIN;
    if (y - scrolly < YMARGIN) scrolly = y - YMARGIN;
    if (scrollx + WIDTH - x < XMARGINR) scrollx = x + XMARGINR - WIDTH;
    if (scrolly + HEIGHT - y < YMARGINB) scrolly = y + YMARGINB - HEIGHT;

    // Now, hard bounds on scrolling.
    if (scrollx < 0) scrollx = 0;
    if (scrolly < 0) scrolly = 0;
    if (scrollx > WORLDPIXELSW - WIDTH) scrollx = WORLDPIXELSW - WIDTH;
    if (scrolly > WORLDPIXELSH - HEIGHT) scrolly = WORLDPIXELSH - HEIGHT;

    // This is the screen number of the top-left screen.
    var screenx = int(scrollx / WIDTH);
    var screeny = int(scrolly / HEIGHT);

    var youx = x - scrollx;
    var youy = y - scrolly;

    var left = scrollx % WIDTH;
    var top = scrolly % HEIGHT;

    // Everything up to this point is in world pixels.

    loadBits(tlbg, screenx, screeny);
    tlbg._x = -2 * left;
    tlbg._y = -2 * top;

    loadBits(trbg, screenx + 1, screeny);
    trbg._x = -2 * left + 2 * WIDTH;
    trbg._y = -2 * top;

    loadBits(blbg, screenx, screeny + 1);
    blbg._x = -2 * left;
    blbg._y = -2 * top + + 2 * HEIGHT;

    loadBits(brbg, screenx + 1, screeny + 1);
    brbg._x = -2 * left + 2 * WIDTH;
    brbg._y = -2 * top + 2 * HEIGHT;

    // XXX place You based on scroll window.
    _root.you._x = youx * 2;
    _root.you._y = youy * 2;
  }

}
