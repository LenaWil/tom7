import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class Info {

  #include "constants.js"

  var mc : MovieClip = null;
  // never changes
  var background : BitmapData = null;
  // not scaled. probably don't need to keep pointer to it
  var fontbm : BitmapData = null;
  // currently displayed
  var textbm : BitmapData = null;

  var message = [];
  var cx : Number = 0;
  var cy : Number = 0;

  var font = [];

  var SCALE = 3;

  public function init() {
    mc = _root.createEmptyMovieClip('info', INFODEPTH);
    mc._x = 0;
    mc._y = SCREENHEIGHT - INFOHEIGHT;

    fontbm = BitmapData.loadBitmap('font.png');

    var bg = BitmapData.loadBitmap('info.png');
    var grow = new Matrix();
    grow.scale(SCALE, SCALE);
    background = new BitmapData(bg.width * SCALE, bg.height * SCALE, true, 0);
    background.draw(bg, grow);

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

    message = [];
    setMessage("HOCKEY GAME PLAY\n        TACKLE A PLAYERS\n");
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
    // Always at depth 1.
    mc.attachBitmap(background, 1);
    textbm = new BitmapData(background.width, background.height, true, 0);
    mc.attachBitmap(textbm, 2);
  }

  public function setMessage(m, sp) {
    message = [];
    var s = "";
    for (var i = 0; i < m.length; i++) {
      if (m.charAt(i) == "\n") {
        message.push(s);
        s = '';
      } else {
        s += m.charAt(i);
      }
    }
    message.push(s);
    reload();
  }

  // Make progress on the display.
  // If the argument is true, then go faster.
  public function doFrame() {
    for (var y = 0; y < INFOLINES; y++) {
      var s = message[y];
      for (var x = 0; x < s.length; x++) {
        var place = new Matrix();
        place.translate(INFOMARGINX + x * 3 * (FONTW - FONTOVERLAP),
                        INFOMARGINY + y * 3 * FONTH);
        textbm.draw(font[s.charCodeAt(cx)], place);
        mc.attachBitmap(textbm, 2);
      }
    }
  }

}
