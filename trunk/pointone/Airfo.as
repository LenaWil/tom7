import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;

class Airfo {

  #include "constants.js"
  #include "util.js"

  var mc : MovieClip = null;
  // never changes
  var background : BitmapData = null;
  // currently displayed
  var textbm : BitmapData = null;

  var width;
  var height;

  var message = "";
  var font = [];

  public function position(x, y) {
    mc._x = (x + BOARDX) * SCALE;
    mc._y = (y + BOARDY) * SCALE;
  }

  public function init() {
    mc = _root.createEmptyMovieClip('info', AIRFODEPTH);
    var fontbm = BitmapData.loadBitmap('fontsmall.png');

    width = SCREENW * SCALE;
    height = SMALLFONTH * SCALE;

    for (var i = 0; i < FONTCHARS.length; i++) {
      // Just shift the whole graphic so that only
      // the desired character shows.
      var cropbig = new Matrix();
      cropbig.translate((0 - SMALLFONTW) * i, 0);
      cropbig.scale(SCALE, SCALE);

      // Blit to a single-character bitmap using
      // the translation matrix above, and only
      // enough room for that one character.
      var f = new BitmapData(SMALLFONTW * SCALE, SMALLFONTH * SCALE, true, 0);
      f.draw(fontbm, cropbig);
      font[FONTCHARS.charCodeAt(i)] = f;
    }

    message = '';
    reload();
    hide();
  }

  public function hide() {
    mc._visible = false;
  }

  public function show() {
    mc._visible = true;
  }

  public function reload() {
    // Probably don't need to recreate bitmap data, just
    // clear it.
    textbm = new BitmapData(width, height, true, 0);
    mc.attachBitmap(textbm, 2);
    var s = message;
    // clearBitmap(textbm);
    for (var x = 0; x < s.length; x++) {
      var place = new Matrix();
      var xx = x * SCALE * (SMALLFONTW - SMALLFONTOVERLAP);
      place.translate(xx, 0);
      // trace(s.charCodeAt(x) + ' at ' + xx);
      textbm.draw(font[s.charCodeAt(x)], place);
    }
  }

  public function setMessage(m) {
    message = m;
    reload();
  }
}
