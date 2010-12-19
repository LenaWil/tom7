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
  jump : { l: ['brobowalk1'] },
  thrust: { l: ['bthrust'] }
  };

  var frames = {};

  public function init() {
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

  public function touch(other : PhysicsObject) {}

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
  
  // XXX should remember if I was defeated across
  // spawns, by using global property
  var defeated = false;

  var thrustframes = 0;

  // Maximum length of shadow.
  var MAXSHADOW = 6;

  var lastframe = null;
  // Holds movieclips of our previous positions
  var shadows = [];
  var shcounter = 0;

  // Just make sure to clean up shadow, since those
  // are placed in the root.
  // XXX there is still a problem where these can
  // stick around.
  public function kill() {
    trace('kill boss');
    for (var o in shadows) {
      shadows[o].removeMovieClip();
      shadows = [];
    }
  }

  // Number of frames that escape has been held
  var framemod : Number = 0;
  public function onEnterFrame() {
    // Avoid overflow at the expense of jitter.
    framemod++;
    if (framemod > 100000)
      framemod = 0;

    // Or more generally, whenever we want to save shadow.
    if (thrustframes > 0 && lastframe && shcounter < 100) {
      var sh = 
	_root.createEmptyMovieClip('shadow' + shcounter,
				   // Maybe should count down?
				   4500 + shcounter);
      sh._y = this._y;
      sh._x = this._x;
      sh._xscale = 200.0;
      sh._yscale = 200.0;
      // XXX make it depend on depth, probably below
      sh._alpha = 50.0;
      
      sh.attachBitmap(lastframe, anim.getNextHighestDepth());
      shadows.push(sh);
      shcounter ++;
    }

    // Shrink shadow if it's too long or if we're not growing
    // it any more.
    if (thrustframes == 0 || shadows.length == MAXSHADOW) {
      // Throw away the oldest element.
      shadows[0].removeMovieClip();
      shadows = shadows.slice(1, shadows.length);
    } else if (thrustframes == 0 && shadows.length == 0) {
      // Shadow is done, so reset depths information.
      shcounter = 0;
    }

    movePhysics();

    // When boss is on the screen and not defeated,
    // prevent the player from passing.
    if (!defeated) {
      if (_root.you.x2() > 418) {
	trace('No!');

	// If the player tries to jump over boss, make the
	// boss instantly warp to his position to block him.
	var newy = _root.you._y + _root.you.top - this.top;
	if (this._y > newy) this._y = newy;
	thrustframes = 28;

	// XXX Would probably be good to show some alpha shadows
	// when thrusting... not that hard, really.

	// Absolute prevention, even if player ignores thrusted
	// command.
	_root.you._x = 417 - (_root.you.width - _root.you.right);
	_root.you.thrusted(thrustframes);
      }
    }


    // Special animation mode?
    if (thrustframes > 0) {
      thrustframes --;
      setframe('thrust', framemod);
      this._x = 417 + this.left - ((thrustframes * (thrustframes / 3)) / 3);

    } else if (defeated) {
      // XXX

    } else {
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
    lastframe = fs[f].bm;
  }

}
