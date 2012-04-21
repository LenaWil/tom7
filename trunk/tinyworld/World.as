import flash.display.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.geom.Point;

/* This is basically the whole damn game.
   It's just easier that way... */

class World extends MovieClip {

  var FONTW = 18;
  var FONTH = 32;

  // XXX should be lots more.
  var TILESW = 40;
  var TILESH = 25;

  var WIDTH = TILESW * FONTW;
  var HEIGHT = TILESH * FONTH;


  var font = [];

  var data = [];

  var mc : MovieClip;
  var fontbitmap : BitmapData;
  var bitmap : BitmapData;

  public function init(k) {
    fontbitmap = BitmapData.loadBitmap('fontbig.png');
    var chars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
      "abcdefghijklmnopqrstuvwxyz" +
      "0123456789`-=[]\\;',./~!@#" +
      "$%^&*()_+{}|:\"<>?";
    for (var i = 0; i < chars.length; i++) {

      // Just shift the whole graphic so that only
      // the desired character shows.
      var crop = new Matrix();
      crop.translate((0 - FONTW) * i, 0);

      // Blit to a single-character bitmap using
      // the translation matrix above, and only
      // enough room for that one character.
      var f = new BitmapData(FONTW, FONTH, true, 0xFF000000);
      f.draw(fontbitmap, crop);
      // trace(chars.charCodeAt(i));
      font[chars.charCodeAt(i)] = f;
    }

    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        data.push("ABCDEFGHIJKLMNOPQRSTUVWXYZ".charCodeAt((x + y * TILESW) % 26));
      }
    }

    mc = _root.createEmptyMovieClip('worldmc', 999);
    bitmap = new BitmapData(WIDTH, HEIGHT, false, 0xFFCCFFCC);
    mc.attachBitmap(bitmap, 1000);
    // mc.attachBitmap(font[i], 1100);
  }

  public function onLoad() {
    // Key.addListener(this);
    trace('hi');
    init();

    // Scale 2:1 pixels? Probably.
    // But we should just do this in the font -- the math
    // is typically easier.
    // this._xscale = 200.0;
    // this._yscale = 200.0;
    // Doesn't really matter which one is on top. Try both.
    _root.stop();
    this.stop();
  }

  var framemod : Number = 0;
  var facingright = true;
  public function onEnterFrame() {
    // Avoid overflow at the expense of jitter.
    framemod++;
    if (framemod > 100000)
      framemod = 0;

    redraw();
  }

  private function redraw() {
    // XXX clear bitmap
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        // var ch = data[y * TILESW + x];
        var ch = data[(framemod + y * TILESW + x) % (TILESW * TILESH)]
        bitmap.copyPixels(font[ch],
                          new Rectangle(0, 0, FONTW, FONTH),
                          new Point(x * FONTW, y * FONTH));
      }
    }
  }
    /*
  private function makeClipAt(x, y, startdepth, ground, hitlist) {
    var depth = startdepth + y * TILESW + x;
    var mc : MovieClip =
      _root.createEmptyMovieClip('b' + y + '_' + x,
                                 depth);
    //_root.attachMovie("Star", "m" + depth, depth);
    mc._xscale = 200;
    mc._yscale = 200;
    mc._y = y * HEIGHT;
    mc._x = x * WIDTH;
    // trace(g.frames[0].src);
    mc.attachBitmap(g.frames[0].bm, mc.getNextHighestDepth());
    hitlist.push(mc);
  }

  // Clears the tiles and redraws them.
  // Shouldn't need to call this every frame.
  public function rerender() {
    // Kill all old tiles.
    for (var i = 0; i < bgtiles.length; i++)
      bgtiles[i].removeMovieClip();
    for (var i = 0; i < fgtiles.length; i++)
      fgtiles[i].removeMovieClip();

    bgtiles = [];
    fgtiles = [];

    // Make tiles.
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        makeClipAt(x, y, BGTILEDEPTH, background, bgtiles);
        makeClipAt(x, y, FGTILEDEPTH, foreground, fgtiles);
      }
    }
  }
    */

}
