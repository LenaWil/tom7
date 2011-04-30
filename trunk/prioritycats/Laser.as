import flash.display.*;

/* The laser pointer is actually the main actor
   for the game, driving all activity including
   the movement of the cats. */

class Laser extends MovieClip {

  #include "constants.js"
  #include "frames.js"

  // Laser frames.
  var frames = [];

  var fr = 0;
  var anim: MovieClip = null;

  var orange: Cat = null;
  var grey: Cat = null;
  
  // Logical location
  var x, y;
  public function onMouseMove() {
    // these coordinates are relative to the current movieclip position
    this._x += _xmouse;
    this._y += _ymouse;
    this.x = this._x;
    this.y = this._y;

    this._alpha = 100;
    
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

    fr = (fr + 1) % frames.length;
    anim.attachBitmap(frames[fr], anim.getNextHighestDepth());

  }

  public function onEnterFrame() {
    // Do visibility test. We do this not just when the mouse
    // moves, since a cat might move past it.
    _root.world.clearDebug();
    if (orange) {
      lookTest(orange, this.x, this.y);
    }
    if (grey) {
      lookTest(grey, this.x, this.y);
    }
  }

  public function lookTest(cat : Cat, lx, ly) {
    if (_root.world.lineOfSight(cat.x1(), cat.y1() + cat.clipheight() / 2, 
                                lx, ly) ||
        _root.world.lineOfSight(cat.x2(), cat.y1() + cat.clipheight() / 2, 
                                lx, ly)) {
      cat.lookat(lx, ly);
    } else {
      cat.nolook();
    }
  }

  public function init(oo, gg) {
    orange = oo;
    grey = gg;
  }

  public function onLoad() {
    this._xscale = 200;
    this._yscale = 200;

    for (var i = 0; i < 4; i++) {
      frames.push(BitmapData.loadBitmap('lp' + (i + 1) + '.png'));
    }

    Mouse.addListener(this);
    // Don't show system mouse cursor.
    Mouse.hide();

    this.swapDepths(LASERDEPTH);
  }

}
