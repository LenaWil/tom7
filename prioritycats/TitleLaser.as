import flash.display.*;
/* Like regular laser pointer, but moves the cats
   eyes and can start the game. */
class TitleLaser extends MovieClip {

  #include "constants.js"

  var usetime : Number;
  var startframe : Number;

  var pupil;

  var frames = [];

  var fr = 0;
  var anim: MovieClip = null;
  
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

    // Should probably be difference between left and right pupils...
    setPupils(this.x, this.y);
  }

  // pupils
  var o1, o2, g1, g2;
  public function setPupils(lx, ly) {
    setPupil(o1, 109, 150, lx, ly);
    setPupil(o2, 150, 150, lx, ly);
    setPupil(g1, 266, 157, lx, ly);
    setPupil(g2, 307, 157, lx, ly);
  }

  var started = false;
  var framesonstart = 0;
  public function onEnterFrame() {
    // Not even on screen yet
    if (!this.x || !this.y) return;
    // Already did it.
    if (started) return;

    if (this.x / 2 >= TITLESTARTX1 &&
        this.x / 2 <= TITLESTARTX2 &&
        this.y / 2 >= TITLESTARTY1 &&
        this.y / 2 <= TITLESTARTY2) {

      // XXX need to indcate that I'm on the start
      // button. Wiggle cat butt? Glow?
      framesonstart++;
      // trace('onstart ' + this.x + ' ' + this.y);
      if (framesonstart > 10) {
        _root["titlescreen"].triggerStart();
        trace('triggerstart');
        // Freeze self?
        // At least don't let it trigger any other
        // actions, because titlescreen is in control now.
        started = true;
      }
    } else {
      framesonstart = 0;
    }
  }

  // Set the pupil (whose normal center is cx,cy)
  // to point at the laser pointer at (lx, ly)
  public function setPupil(mc, cx, cy, lx, ly) {
    cx *= 2;
    cy *= 2;
    var dx = lx - cx;
    var dy = ly - cy;
    if (dx == 0 && dy == 0) {
      mc._x = cx;
      mc._y = cy;
      return;
    }
    var rads = Math.atan2(dy, dx);
    var degs = (360 + rads * 57.2957795) % 360;
    // if ('_level0.o1' == '' + mc) trace(mc + ' ' + dx + ' ' + dy +
    // ' @' + degs);

    // XXX these values can be improved, plus main axis of
    // ellipse should not actually be 0 degrees. might want
    // to wait until cat cuteification happens
    mc._x = int(cx + Math.cos(rads) * 10);
    mc._y = int(-4 + cy + Math.sin(rads) * 3.5);
  }

  public function onLoad() {
    this._xscale = 200;
    this._yscale = 200;

    for (var i = 0; i < 4; i++) {
      frames.push(BitmapData.loadBitmap('lp' + (i + 1) + '.png'));
    }
    pupil = BitmapData.loadBitmap('pupil.png');
    o1 = _root.createEmptyMovieClip('o1',
                                    _root.getNextHighestDepth());
    o1.attachBitmap(pupil, o1.getNextHighestDepth());
    o1.swapDepths(PUPILDEPTH);
    o1._xscale = 200;
    o1._yscale = 200;
    o2 = _root.createEmptyMovieClip('o2',
                                    _root.getNextHighestDepth());
    o2.attachBitmap(pupil, o2.getNextHighestDepth());
    o2.swapDepths(PUPILDEPTH + 1);
    o2._xscale = 200;
    o2._yscale = 200;

    g1 = _root.createEmptyMovieClip('g1',
                                    _root.getNextHighestDepth());
    g1.attachBitmap(pupil, g1.getNextHighestDepth());
    g1.swapDepths(PUPILDEPTH + 2);
    g1._xscale = 200;
    g1._yscale = 200;
    g2 = _root.createEmptyMovieClip('g2',
                                    _root.getNextHighestDepth());
    g2.attachBitmap(pupil, g2.getNextHighestDepth());
    g2.swapDepths(PUPILDEPTH + 3);
    g2._xscale = 200;
    g2._yscale = 200;

    // Pretend laser pointer is in center (?)
    setPupils(202, 194);

    Mouse.addListener(this);
    // Don't show system mouse cursor.
    Mouse.hide();

    this.swapDepths(LASERDEPTH);
  }

}
