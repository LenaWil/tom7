import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;

class Info {

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

  public function destroy() {
    mc.removeMovieClip();
  }

  public function init() {
    mc = _root.createEmptyMovieClip('info', INFODEPTH);
    mc._x = INFOMARGINX;
    mc._y = SCREENH - (INFOHEIGHT + INFOMARGINY);
    // mc._y = 0;

    var fontbm = BitmapData.loadBitmap('font.png');
    // mc.attachBitmap(fontbm, 6);
    // return;

    width = SCREENW * SCALE - (2 * INFOMARGINX);
    height = FONTH * SCALE;

    for (var i = 0; i < FONTCHARS.length; i++) {
      // Just shift the whole graphic so that only
      // the desired character shows.
      var cropbig = new Matrix();
      cropbig.translate((0 - FONTW) * i, 0);
      cropbig.scale(SCALE, SCALE);

      // Blit to a single-character bitmap using
      // the translation matrix above, and only
      // enough room for that one character.
      var f = new BitmapData(FONTW * SCALE, FONTH * SCALE, true, 0);
      f.draw(fontbm, cropbig);
      font[FONTCHARS.charCodeAt(i)] = f;
    }

    message = '';
    reload();
    show();
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
      var xx = x * SCALE * (FONTW - FONTOVERLAP);
      place.translate(xx, 0);
      // trace(s.charCodeAt(x) + ' at ' + xx);
      textbm.draw(font[s.charCodeAt(x)], place);
    }
    redraw();
  }

  public function setMessage(m) {
    message = m;
    reload();
  }

  public function redraw() {
  }
}
