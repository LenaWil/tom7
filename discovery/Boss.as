import flash.display.*;
class Boss extends PhysicsObject {

  #include "constants.js"

  var dx = 0;
  var dy = 0;

  // Size of graphic
  var width = 64 * 2;
  var height = 84 * 2;

  // Subtracted from clip region.
  // Player's top-left corner is at x+left, y+top.
  var top = 15 * 2;
  var left = 19 * 2;
  var right = 18 * 2;
  var bottom = 0 * 2;

  var FPS = 25;

  var framedata = {
  brobowalk : { l: ['brobowalk1', 'brobowalk2', 'brobowalk3', 'brobowalk2'] },
  // XXX jump frames!
  jump : { l: ['brobowalk1'] }
  };

  var frames = {};

  public function init() {
    trace('SPAWN BOSS');
    for (var o in framedata) {
      // n.b. boss is always 'facing' left, but keeping this as
      // a subfield to make it easier to maintain in parallel with
      // player animation (or use common utilities).
      frames[o] = { l: [] };
      var l = framedata[o].l;
      for (var i = 0; i < l.length; i++)
	frames[o].l.push({ src : l[i],
	      bm: BitmapData.loadBitmap(l[i] + '.png') });
    }
  }

  // XXX ???
  // Keep track of what dudes I touched, since
  // I don't want triple point tests or iterated
  // adjacency to make lots of little pushes.
  var touchset = [];
  public function touch(other : PhysicsObject) {
    for (var o in touchset) {
      if (touchset[o] == other)
        return;
    }
    touchset.push(other);
  }

  public function onLoad() {
    this._xscale = 200.0;
    this._yscale = 200.0;
    this.setdepth(4900);
    this.stop();
  }

  // XXX not sure if I'll use this; probably will
  // just have state machine and set physics directly.
  public function wishjump() {
    return false;
  }

  public function wishleft() {
    return false;
  }

  public function wishright() {
    return false;
  }

  public function wishdive() {
    return false;
  }

  // Number of frames that escape has been held
  var framemod : Number = 0;
  public function onEnterFrame() {
    // Avoid overflow at the expense of jitter.
    framemod++;
    if (framemod > 100000)
      framemod = 0;

    touchset = [];

    movePhysics();

    // Now, if we touched someone, give it some
    // love.
    for (var o in touchset) {
      var other = touchset[o];

      var diffx = other._x - this._x;
      var diffy = other._y - this._y;
    
      var normx = diffx / width;
      var normy = diffy / height;

      // Don't push from side to side when like
      // standing on a dude but not centered.
      if (Math.abs(normx) > Math.abs(normy)) {
        other.dx += normx;
      } else {
        other.dy += normy;
      }
    }

    // Set animation frames.
    var otg = ontheground();
    if (otg) {
      if (Math.abs(dx) < 1) {
	// XXX was 0. should give the boss some
	// dancing.
	setframe('brobowalk', framemod);
      } else {
	setframe('brobowalk', framemod);
      }
    } else {
      // In the air.
      setframe('jump', framemod);
    }
  }

  var anim: MovieClip = null;
  public function setframe(what, frmod) {
    // PERF don't need to do this if we're already on the
    // right frame, which is the common case.
    if (anim) anim.removeMovieClip();
    anim = this.createEmptyMovieClip('anim',
				     this.getNextHighestDepth());
    anim._y = 0;
    anim._x = 0;

    var fs = frames[what].l;
    // XXX animation should be able to set its own period.
    // XXX pingpong (is built in)
    var f = int(frmod / 8) % fs.length;
    // trace(what + ' ' + frmod + ' of ' + fs.length + ' = ' + f);
    anim.attachBitmap(fs[f].bm, anim.getNextHighestDepth());
  }

}
