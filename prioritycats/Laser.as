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

    if (_root.butterfly) {
      checkButterfly(orange) || checkButterfly(grey);
    }

    checkWarp(orange) || checkWarp(grey);
  }

  public function checkButterfly(cat : Cat) {
    var bx = _root.butterfly._x;
    var by = _root.butterfly._y;
    if (bx >= cat.x1() && bx <= cat.x2() &&
        by >= cat.y1() && by <= cat.y2()) {
      _root.world.gotButterfly();
      return true;
    }
  }

  public function catsTo(cx, cy) {
    orange._x = cx;
    orange._y = cy;
    grey._x = cx;
    grey._y = cy;
  }

  // Check if the cat is oriented in such a way that we
  // ought to be warping. Either cat can warp, and we
  // just bring the cats together.
  //
  // If the cats are traveling different directions at
  // the edge of the screen, we can get into a very
  // disturbing feedback loop. When we transition,
  // force the velocity vectors of both cats to be
  // as though they were thrown through the warp.
  // This is particularly important when jumping
  // upward, since one of the cats is usually standing
  // still on the ground, so with dy of 0, it will
  // get sufficient dy to move back downward after
  // a single frame of gravity!
  public function checkWarp(cat : Cat) {
    var centerx = (cat.x2() + cat.x1()) * 0.5;
    if (centerx < WIDTH && cat.dx < 0) {
      // Walked off the screen to the left.
      _root.world.gotoRoom(_root.world.leftRoom());
      catsTo(cat._x + (WIDTH * TILESW), cat._y);
      grey.dx = Math.min(grey.dx, -4);
      orange.dx = Math.min(orange.dx, -4);
      return true;
    } 
    if (centerx >= (WIDTH * TILESW) && cat.dx > 0) {
      _root.world.gotoRoom(_root.world.rightRoom());
      catsTo(cat._x - (WIDTH * TILESW), cat._y);
      grey.dx = Math.max(grey.dx, 4);
      orange.dx = Math.max(orange.dx, 4);
      return true;
    } 

    var centery = cat.y2();
    if (centery < HEIGHT && cat.dy < 0) {
      _root.world.gotoRoom(_root.world.upRoom());
      catsTo(cat._x, cat._y + (HEIGHT * TILESH));
      var dy = Math.min(Math.min(grey.dy, orange.dy), -11.9);
      // Not just that, but make them share the larger (magnitude)
      // dx component, which helps jumping around corners. They
      // have different terminal velocities so they should separate.
      var dx = (Math.abs(grey.dx) > Math.abs(orange.dx)) ? grey.dx : orange.dx;
      grey.dy = dy;
      orange.dy = dy;
      grey.dx = dx;
      orange.dx = dx;
      return true;
    } 

    if (centery >= (HEIGHT * TILESH) && cat.dy > 0) {
      _root.world.gotoRoom(_root.world.downRoom());
      catsTo(cat._x, cat._y - (HEIGHT * TILESH));
      // Don't need to throw here. Gravity takes
      // care of downward tendency.
      var dy = Math.max(orange.dy, grey.dy);
      orange.dy = dy;
      grey.dy = dy;
      return true;
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
