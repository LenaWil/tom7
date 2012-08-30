import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class Dialog {

  #include "constants.js"

  var mc : MovieClip = null;
  // never changes
  var background : BitmapData = null;
  // not scaled. probably don't need to keep pointer to it
  var fontbm : BitmapData = null;
  // currently displayed
  var textbm : BitmapData = null;

  var message = [];
  var speaker = null;
  var cx : Number = 0;
  var cy : Number = 0;

  var font = [];

  public function init() {
    mc = _root.createEmptyMovieClip('dialog', DIALOGDEPTH);
    mc._x = int((SCREENWIDTH - (DIALOGW * 2)) / 2);
    mc._y = 40;

    fontbm = BitmapData.loadBitmap('font.png');

    var bg = BitmapData.loadBitmap('dialog.png');
    var grow = new Matrix();
    grow.scale(2, 2);
    background = new BitmapData(bg.width * 2, bg.height * 2, true, 0);
    background.draw(bg, grow);

    for (var i = 0; i < FONTCHARS.length; i++) {
      // Just shift the whole graphic so that only
      // the desired character shows.
      var cropbig = new Matrix();
      cropbig.translate((0 - FONTW) * i, 0);
      cropbig.scale(2, 2);

      // Blit to a single-character bitmap using
      // the translation matrix above, and only
      // enough room for that one character.
      var f = new BitmapData(FONTW * 2, FONTH * 2, true, 0);
      f.draw(fontbm, cropbig);
      font[FONTCHARS.charCodeAt(i)] = f;
    }

    message = "";
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
    // Always at depth 1.
    mc.attachBitmap(background, 1);
    textbm = new BitmapData(background.width, background.height, true, 0);
    mc.attachBitmap(textbm, 2);
    cx = 0;
    cy = 0;
  }

  public function setMessage(m, sp) {
    message = [];
    speaker = sp;
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

  public function done() {
    return cy >= message.length;
  }

  // Make progress on the display.
  // If the argument is true, then go faster.
  public function doFrame(holdingKey) {

    var n = holdingKey ? 4 : 1;
    for (var i = 0; i < n; i++) {
      if (cy >= message.length) {
        // blink cursor or something.
        return;
      } else {
        var s = message[cy];

        if (cx >= s.length) {
          // Easy to just have this count as a keypress,
          // might be natural anyway.
          cx = 0;
          cy++;
        } else {
          var place = new Matrix();
          place.translate(2 * DIALOGMARGINX + 2 * cx * (FONTW - FONTOVERLAP),
                          2 * DIALOGMARGINY + 2 * cy * FONTH);
          textbm.draw(font[s.charCodeAt(cx)], place);
          mc.attachBitmap(textbm, 2);
          if (!(cx % 2) && speaker) speaker.jiggle = !speaker.jiggle;
          cx++;
        }

      }
    }

  }

}
