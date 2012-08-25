import flash.display.*;
import flash.geom.Matrix;
/* This is the cell that you control. */

class You extends PhysicsObject {

  #include "constants.js"
  #include "frames.js"

  var x = STARTX;
  var y = STARTY;

  var dx = 0;
  var dy = 0;

  // Size of graphic, in world pixels.
  var width = YOUWIDTH;
  var height = YOUHEIGHT;

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

  // Subtracted from clip region.
  // Player's top-left corner is at x+left, y+top.
  var top = 21;
  var left = 10;
  var right = 10;
  var bottom = 3;

  var FPS = 25;


  var frames;

  // XXX shouldn't be squares, but...
  public function ignoresquares() {
    return true;
  }

  public function init() {
    // initialize frame data, by loading the bitmaps and
    // doing the flippin.
    frames = {};

    // Everything scaled 2x.
    var grow = new Matrix();
    grow.scale(2, 2);

    for (var o in framedata) {
      // Copy frames into L and R.
      frames[o] = { l: [],
                    r: [],
                    div: framedata[o].div || 8 };
      var f = framedata[o].f;
      for (var i = 0; i < f.length; i++) {
        var bm = BitmapData.loadBitmap(f[i].p + '.png');
        if (!bm) {
          trace('could not load bitmap ' + f[i].p +
                '. add it to the library and set linkage!');
        }

        var bm2x : BitmapData =
          new BitmapData(bm.width * 2, bm.height * 2, true, 0);
        bm2x.draw(bm, grow);

        frames[o].r.push({ bm: bm2x });

        var fliphoriz = new Matrix();
        fliphoriz.scale(-1,1);
        fliphoriz.translate(bm2x.width, 0);

        var fbm = new BitmapData(bm2x.width, bm2x.height, true, 0);
        fbm.draw(bm2x, fliphoriz);
        frames[o].l.push({ bm: fbm });
      }
    }

    trace('initialized you.');
    x = STARTX;
    y = STARTY;

  }

  // Keep track of what dudes I touched, since
  // I don't want triple point tests or iterated
  // adjacency to make lots of little pushes.
  var touchset;
  public function touch(other : PhysicsObject) {
    for (var o in touchset) {
      if (touchset[o] == other)
        return;
    }
    touchset.push(other);
  }

  public function onLoad() {
    touchset = [];
    // You drive the input.
    Key.addListener(this);

    this.setdepth(YOUDEPTH);
    this.stop();

    trace('onload you');
  }

  public function getConstants() {
    var C = defaultconstants();
    return C;
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

    // XXXXXXXXXXXXX
    // movePhysics();
    if (wishjump()) {
      this.y -= 10;
    } else if (wishdive()) {
      this.y += 10;
    }

    if (wishleft()) {
      this.x -= 10;
    } else if (wishright()) {
      this.x += 10;
    }


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

    // XXX
    var what_stand = 'stopped', what_jump = 'moving';

    if (Math.abs(dx) > 9)
      what_stand = 'moving';

    // true means force animation, even if still
    // XXX unused...
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

        setframe(what_stand, facingright, what_animate ? framemod : 0);
      }
      // ...
    } else {
      // In the air.
      setframe(what_jump, facingright, framemod);
    }

    _root.world.scrollToShow(x, y);

  }

  var body: MovieClip = null, head: MovieClip = null;
  public function setframe(what, fright, frmod) {

    // PERF don't need to do this if we're already on the
    // right frame, which is the common case.
    if (body) body.removeMovieClip();
    body = this.createEmptyMovieClip('body',
                                     this.getNextHighestDepth());
    body._x = 0;
    body._y = 0;

    // Facing left or right?
    var fs = (fright ? frames[what].r : frames[what].l);
    // XXX pingpong
    var f = int(frmod / frames[what].div) % fs.length;
    // trace(what + ' ' + frmod + f);
    // trace('' + fs[f].bm + ' ?');
    body.attachBitmap(fs[f].bm, body.getNextHighestDepth());

    // XXX attachments.
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
      // XXXXXXXXXXXX cheats

      /*
    case 66:
      _root.status.learnDance('x');
      _root.status.learnDance('c');
      _root.status.learnDance('v');
      _root.status.showGotDance();
      break;
      */

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


}
