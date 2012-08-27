import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class Status {

  #include "constants.js"

  var icons = {
    snorkel: { p: "snorkel" },
    walljump: { p: "walljump" },
    labcoat: { p: "labcoat" },
    cactus: { p: "cactus" },
    mitochondria: { p: "mitochondria" },
    birthdayhat: { p: "birthdayhat" }
  };

  var mc : MovieClip = null;
  // never changes
  var background : BitmapData = null;
  // currently displayed
  var cur : BitmapData = null;

  public function init() {
    mc = _root.createEmptyMovieClip('status', STATUSDEPTH);
    mc._x = 0;
    mc._y = SCREENGAMEHEIGHT;

    var bg = BitmapData.loadBitmap('status.png');
    var grow = new Matrix();
    grow.scale(2, 2);
    background = new BitmapData(bg.width * 2, bg.height * 2, true, 0);
    background.draw(bg, grow);

    var idx = 0;
    for (var o in icons) {
      var icon = icons[o];
      icon.idx = idx;
      var bm = BitmapData.loadBitmap(icon.p + '.png');
      if (!bm) {
	trace('could not load bitmap ' + icon.p +
	      '. add it to the library and set linkage!');
      }

      var bm2x : BitmapData =
	new BitmapData(bm.width * 2, bm.height * 2, true, 0);
      bm2x.draw(bm, grow);
      icon.bm = bm2x;

      idx++;
    }

    redraw();
  }

  public function redraw() {
    // Always at depth 1.
    mc.attachBitmap(background, 1);
    cur = new BitmapData(background.width, background.height, true, 0);
    for (var o in icons) {
      var icon = icons[o];
      if (icon.have) {
        var place = new Matrix();
        place.translate(16 + 64 * icon.idx, 11);
	cur.draw(icon.bm, place);
      }
    }
    mc.attachBitmap(cur, 2);
  }

  public function get(s) {
    if (icons[s].bm) {
      icons[s].have = true;
    } else {
      trace('unknown item ' + s);
    }
    redraw();
  }

}
