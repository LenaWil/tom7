import flash.display.*;

/* This is a butterfly in the final room, which
   you can just look at. */

class Butterfly extends MovieClip {

  #include "constants.js"
  #include "frames.js"

  // Butterframes.
  var frames = [];

  var fr = 0;
  var anim: MovieClip = null;
  var which = '';

  var x1, y1, x2, y2;

  // Logical location
  var dx = 0, dy = 0;
  var x, y;
  public function onEnterFrame() {
    if (anim) anim.removeMovieClip();
    anim = this.createEmptyMovieClip('anim',
                                     this.getNextHighestDepth());
    // Laser pointer should be centered
    anim._y = int(-BUTTERFLYW / 2);
    anim._x = int(-BUTTERFLYH / 2);
    // var f = int((Math.abs(x) * 123457) % 17 + 
    // (Math.abs(y) * 1711) % 23) % frames.length;
    // var f = ((Math.abs(int(x)) * 31337) % 257 ^
    // (Math.abs(int(y)) * 111311) % 253) % frames.length;

    // XXX Should make it avoid the bounding box.

    dx += Math.random() - 0.5;
    dy += Math.random() * 0.5 - 0.25;

    // don't move too fast
    if (dx > 2) dx = 2;
    if (dx < -2) dx = -2;
    if (dy > 2) dy = 2;
    if (dy < -2) dy = -2;
    
    this._x += dx;
    this._y += dy;
    // stay in bounds
    if (this._x < x1) this._x = x1;
    if (this._y < y1) this._y = y1;
    if (this._x > x2) this._x = x2;
    if (this._y > y2) this._y = y2;

    fr = (fr + 1) % frames.length;
    anim.attachBitmap(frames[fr], anim.getNextHighestDepth());
  }

  public function init(w, x, y) {
    // Don't all flap in synchrony.
    fr = int(Math.random() * 80);
    which = w;
    trace('startup butterfly ' + which);
    // Always 2 frames?
    var gfx = 'a'; // XXX
    for (var i = 0; i < 2; i++) {
      frames.push(BitmapData.loadBitmap('butterfly' + gfx + (i + 1) + '.png'));
    }
    this.x1 = x - BUTTERFLYW / 2;
    this.x2 = x + BUTTERFLYW / 2;
    this.y1 = y - BUTTERFLYH / 2;
    this.y2 = y + BUTTERFLYH / 2;
  }

  public function onLoad() {
    this._xscale = 200;
    this._yscale = 200;
  }

}
