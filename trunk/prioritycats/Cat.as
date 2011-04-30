import flash.display.*;
/* Used to be 'you', but now the game loop is
   done by LaserPointer since there are two
   cats. This just takes care of the animation
   and stuff. */
class Cat extends PhysicsObject {

  #include "constants.js"
  #include "frames.js"

  var dx = 0;
  var dy = 0;

  // Size of graphic
  var width = 50;
  var height = 25;

  // Subtracted from clip region.
  // Player's top-left corner is at x+left, y+top.
  var top = 0;
  var left = 0;
  var right = 0;
  var bottom = 0;

  var FPS = 25;


  var frames = {};

  public function init() {
    /*
    for (var o in framedata) {
      frames[o] = { l: [], r: [], div: framedata[o].div || 8 };
      var l = framedata[o].l;
      var r = framedata[o].r || l;
      
      for (var i = 0; i < l.length; i++)
        frames[o].l.push({ src : l[i],
              bm: BitmapData.loadBitmap(l[i] + '.png') });
      for (var i = 0; i < r.length; i++)
        frames[o].r.push({ src : r[i],
              bm: BitmapData.loadBitmap(r[i] + '.png') });
    }
    */
  }

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
    Key.addListener(this);
    this._xscale = 200.0;
    this._yscale = 200.0;
    // Doesn't really matter which one is on top. Try both.
    this.setdepth(CATDEPTH + 1);
    this.setdepth(CATDEPTH);
    this.stop();
  }

  public function getConstants() {
    var C = defaultconstants();
    return C;
  }

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

  var framemod : Number = 0;
  var facingright = true;
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

      // This is where I activate touchable things.

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

    // Make sure we're not interfering with the message.
    /*
    if (this._y < 130) {
      _root.message._y = (290 + _root.message._y) / 2;
    } else {
      _root.message._y = (14 + _root.message._y) / 2;
    }
    */

    var what_stand = 'buttup', what_jump = 'buttup';
    var what_animate = false;

    var otg = ontheground();
    if (otg) {
      if (dx > 1) {
        facingright = true;
        setframe(what_stand, facingright, framemod);
      } else if (dx > 0) {
        facingright = true;
        setframe(what_stand, facingright, what_animate ? framemod : 0);
      } else if (dx < -1) {
        facingright = false;
        setframe(what_stand, facingright, framemod);
      } else if (dx < 0) {
        setframe(what_stand, facingright, what_animate ? framemod : 0);
      } else {
        // standing still on ground.
        setframe(what_stand, facingright, what_animate ? framemod : 0);
      }
      // ...
    } else {
      // In the air.
      setframe(what_jump, facingright, framemod);
    }

    // Probably don't want any of this. Laser pointer
    // should control transitions?
    /*
    // Check room transitions. nb.: This exits early
    // when we warp, so it should happen last.
    var centerx = (x2() + x1()) * 0.5;
    if (centerx < 0 && dx < 0) {
      // Walked off the screen to the left.
      _root.world.gotoRoom(_root.world.leftRoom());
      this._x += GAMESCREENWIDTH;
      return;
    } 

    if (centerx >= GAMESCREENWIDTH && dx > 0) {
      _root.world.gotoRoom(_root.world.rightRoom());
      this._x -= GAMESCREENWIDTH;
      return;
    } 

    var centery = y2();
    if (centery < 0 && dy < 0) {
      _root.world.gotoRoom(_root.world.upRoom());
      this._y += GAMESCREENHEIGHT;
      return;
    } 

    if (centery >= GAMESCREENHEIGHT && dy > 0) {
      _root.world.gotoRoom(_root.world.downRoom());
      this._y -= GAMESCREENHEIGHT;
      return;
    }
    */
  }

  var body: MovieClip = null;
  public function setframe(what, fright, frmod) {
    // PERF don't need to do this if we're already on the
    // right frame, which is the common case.
    if (body) body.removeMovieClip();
    body = this.createEmptyMovieClip('body',
                                     this.getNextHighestDepth());
    body._y = 0;
    body._x = 0;

    var fs = (fright ? frames[what].r : frames[what].l);
    // XXX pingpong
    var f = int(frmod / frames[what].div) % fs.length;
    // trace(what + ' ' + frmod + f);
    body.attachBitmap(fs[f].bm, body.getNextHighestDepth());

    
  }

}
