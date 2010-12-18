import flash.display.*;
class You extends PhysicsObject {

  #include "constants.js"

  var dx = 0;
  var dy = 0;

  var holdingUp = false;
  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;
  var holdingEsc = false;
  // Block escape until a key is released.
  // This keeps the user from continuously
  // resetting, which is usually undesirable.
  var blockEsc = false;
  var escKey = 'esc';

  // Size of graphic
  var width = 128;
  var height = 128;

  // Subtracted from clip region.
  // Player's top-left corner is at x+left, y+top.
  var top = 12 * 2;
  var left = 23 * 2;
  var right = 20 * 2;
  var bottom = 3 * 2;

  var FPS = 25;

  var framedata = {
  robowalk : { l: ['robowalkl1', 'robowalkl2'],
               r: ['robowalkr1', 'robowalkr2'] },
  jump : { l: ['jumpl'],
           r: ['jumpr'] }
  };

  var frames = {};

  public function init() {
    for (var o in framedata) {
      frames[o] = { l: [], r: [] };
      var l = framedata[o].l;
      var r = framedata[o].r || l;
      for (var i = 0; i < l.length; i++)
        frames[o].l.push({ src : l[i],
              bm: BitmapData.loadBitmap(l[i] + '.png') });
      for (var i = 0; i < r.length; i++)
        frames[o].r.push({ src : r[i],
              bm: BitmapData.loadBitmap(r[i] + '.png') });
    }
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
    this.setdepth(5000);
    this.stop();
  }

  public function onKeyDown() {
    var k = Key.getCode();
    // _root.message.say(k);
    switch(k) {
    case 192: // ~
      escKey = '~';
      if (!blockEsc) holdingEsc = true;
      break;
    case 82: // r
      escKey = 'r';
      if (!blockEsc) holdingEsc = true;
      break;
    case 27: // esc
      escKey = 'esc';
      if (!blockEsc) holdingEsc = true;
      break;
    case 32: // space
    case 38: // up
      holdingUp = true;
      break;
    case 37: // left
      holdingLeft = true;
      break;
    case 39: // right
      holdingRight = true;
      break;
    case 40: // down
      holdingDown = true;
      break;
    default:
      _root.status.selectDance(k);
      break;
    }
  }

  public function onKeyUp() {
    var k = Key.getCode();
    switch(k) {
    case 192: // ~
    case 82: // r
    case 27: // esc
      holdingEsc = false;
      blockEsc = false;
      break;

    case 32:
    case 38:
      // XXX ok if player is pressing both and
      // releases one??
      // XXX also, this should really be impulse
      // so that the player doesn't keep jumping
      // when holding it down.
      holdingUp = false;
      break;
    case 37:
      holdingLeft = false;
      break;
    case 39:
      holdingRight = false;
      break;
    case 40:
      holdingDown = false;
      break;
    }
  }

  public function wishjump() {
    return holdingUp;
  }

  public function wishleft() {
    return holdingLeft;
  }

  public function wishright() {
    return holdingRight;
  }

  public function wishdive() {
    return holdingDown;
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

    // Set animation frames.
    var otg = ontheground();
    if (otg) {
      if (dx > 1) {
        facingright = true;
        setframe('robowalk', facingright, framemod);
      } else if (dx > 0) {
        facingright = true;
        setframe('robowalk', facingright, 0);
      } else if (dx < -1) {
        facingright = false;
        setframe('robowalk', facingright, framemod);
      } else if (dx < 0) {
        setframe('robowalk', facingright, 0);
      } else {
        // standing still on ground.
        setframe('robowalk', facingright, 0);
      }
      // ...
    } else {
      // In the air.
      setframe('jump', facingright, framemod);
    }

    // XXX Check fell out of world -> death
    // (or check that world is always valid and thus
    // prevents this...)
    

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

    var centery = (y2() + y1()) * 0.5;
    if (centery < 0 && dy < 0) {
      _root.world.gotoRoom(_root.world.upRoom());
      this._y += GAMESCREENHEIGHT;
      return;
    } 

    // Wow I am dumb. Did you catch that bug in the
    // screencaps faster than I did? Probably.
    if (centery >= GAMESCREENHEIGHT && dy > 0) {
      _root.world.gotoRoom(_root.world.downRoom());
      this._y -= GAMESCREENHEIGHT;
      return;
    }
  }

  var anim: MovieClip = null;
  public function setframe(what, fright, frmod) {
    // PERF don't need to do this if we're already on the
    // right frame, which is the common case.
    if (anim) anim.removeMovieClip();
    anim = this.createEmptyMovieClip('anim',
                                     this.getNextHighestDepth());
    anim._y = 0;
    anim._x = 0;

    var fs = (fright ? frames[what].r : frames[what].l);
    // XXX animation should be able to set its own period.
    // XXX pingpong
    var f = int(frmod / 8) % fs.length;
    // trace(what + ' ' + frmod + f);
    anim.attachBitmap(fs[f].bm, anim.getNextHighestDepth());
  }

}
