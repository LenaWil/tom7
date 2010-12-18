class You extends PhysicsObject {

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

  var width = 128;
  var height = 128;

  var FPS = 25;

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

  // Number of frames that escape has been held
  var framemod : Number = 0;
  var facingright = true;
  public function onEnterFrame() {
    // We know we're not inside anything. We can safely
    // modify the velocity in response to user input,
    // gravity, etc.

    touchset = [];

    // XXX do do physics
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
    if (true || otg) {
      if (true || dx > 1) {
        facingright = true;
        framemod++;
	framemod = framemod % 2;
        this.gotoAndStop('robowalkr' + (framemod + 1));
      } else if (dx > 0) {
        this.gotoAndStop('robowalkr1');
      } else if (dx < -1) {
        facingright = false;
        framemod++;
        framemod = framemod % 2;
        this.gotoAndStop('robowalkl' + (framemod + 1));
      } else if (dx < 0) {
        this.gotoAndStop('robowalkl1');
      } else {
        if (facingright) {
          this.gotoAndStop('robowalkr1');
        } else {
          this.gotoAndStop('robowalkl1');
        }
      }
      // ...
    } else {
      // Need frames for air; disable true || otg above.
      if (facingright) {
        this.gotoAndStop('robowalkl1');
      } else {
        this.gotoAndStop('robowalkr1');
      }
    }

  }

}
