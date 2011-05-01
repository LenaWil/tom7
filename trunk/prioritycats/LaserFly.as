import flash.display.*;

/* This is for the laser pointers that dance around at the end. */

class LaserFly extends MovieClip {

  #include "constants.js"
  #include "frames.js"

  // Laser frames.
  var frames = [];

  var fr = 0;
  var anim: MovieClip = null;

  var orange: Cat = null;
  var grey: Cat = null;
  
  // Logical location
  var dx = 0, dy = 0;
  var x, y;
  public function onEnterFrame() {
    if (anim) anim.removeMovieClip();
    anim = this.createEmptyMovieClip('anim',
                                     this.getNextHighestDepth());
    // Laser pointer should be centered
    anim._y = int(-TITLELASERW / 2);
    anim._x = int(-TITLELASERH / 2);
    // var f = int((Math.abs(x) * 123457) % 17 + 
    // (Math.abs(y) * 1711) % 23) % frames.length;
    // var f = ((Math.abs(int(x)) * 31337) % 257 ^
    // (Math.abs(int(y)) * 111311) % 253) % frames.length;

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
    if (this._x < LASERROOMX1 * 2) this._x = LASERROOMX1 * 2;
    if (this._y < LASERROOMY1 * 2) this._y = LASERROOMY1 * 2;
    if (this._x > LASERROOMX2 * 2) this._x = LASERROOMX2 * 2;
    if (this._y > LASERROOMY2 * 2) this._y = LASERROOMY2 * 2;

    fr = int(Math.random() * 9999) % frames.length;
    anim.attachBitmap(frames[fr], anim.getNextHighestDepth());
  }

  public function onLoad() {
    this._xscale = 200;
    this._yscale = 200;

    for (var i = 0; i < 4; i++) {
      frames.push(BitmapData.loadBitmap('lp' + (i + 1) + '.png'));
    }
  }

}
