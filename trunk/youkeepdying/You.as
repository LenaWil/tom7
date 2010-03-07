class You extends MovieClip {

  var dx = 0;
  var dy = 0;

  var holdingLeft = false;
  var holdingRight = false;

  // Physics constants
  var ACCEL = 2;
  var DECEL_GROUND = 0.6;
  var DECEL_AIR = 0.05;
  var JUMP_IMPULSE = 7.5;
  var GRAVITY = 0.3;
  var MAXSPEED = 4;

  public function onLoad() {
    Key.addListener(this);
    this.stop();
  }

  public function onKeyDown() {
    var k = Key.getCode();
    //     trace(k);
    switch(k) {
    case 32: // space
    case 38: // up
      if (ontheground()) {
	dy = -JUMP_IMPULSE;
      }
      break;
    case 37: // left
      holdingLeft = true;
      break;
    case 39: // right
      holdingRight = true;
      break;
    case 40: // down
      break;
    }
  }

  public function onKeyUp() {
    var k = Key.getCode();
    switch(k) {
    case 37:
      holdingLeft = false;
    case 39:
      holdingRight = false;
    }
  }

  public function onEnterFrame() {
    var oldx = this._x;
    var oldy = this._y;
    this._x += dx;
    this._y += dy;

    var otg = ontheground();

    // XXX need to check collisions L/R/U
    if (blockedright()) {
      // XXX snap to pos
      if (dx > 0) dx = 0;
    } else {
      if (holdingRight) {
	dx += ACCEL;
	if (dx > MAXSPEED) dx = MAXSPEED;
      }
    }

    if (blockedleft()) {
      if (dx < 0) dx = 0;
    } else {
      if (holdingLeft) {
	dx -= ACCEL;
	if (dx < -MAXSPEED) dx = -MAXSPEED;
      }
    }

    // If not holding either direction,
    // slow down and stop (quickly)
    if (!holdingLeft && !holdingRight) {
      if (otg) {
	// On the ground, slow to a stop very quickly
	if (dx > DECEL_GROUND) dx -= DECEL_GROUND;
	else if (dx < -DECEL_GROUND) dx += DECEL_GROUND;
	else dx = 0;
      } else {
	// In the air, not so much.
	if (dx > DECEL_AIR) dx -= DECEL_AIR;
	else if (dx < -DECEL_AIR) dx += DECEL_AIR;
	else dx = 0;
      }
    }

    if (otg) {
      // XXX snap to pos
      dy = 0;
    } else {
      dy += GRAVITY;
    }
  }

  // Is the point x,y in any block?
  public function pointblocked(x, y) {
    for (var o in _root.blocks) {
      var b = _root.blocks[o];
      if (b.hitTest(x, y, true)) return true;
    }
  }

  public function widthblocked(x, y, w) {
    return pointblocked(x, y) || pointblocked(x + w, y) ||
      pointblocked(x + (w / 2), y);
  }

  public function heightblocked(x, y, h) {
    return pointblocked(x, y) || pointblocked(x, y + h) ||
      pointblocked(x, y + (h / 2));
  }

  var GROUND_SLOP = 2.0;
  public function ontheground() {
    
    if (pointblocked(this._x, this._y + this._height + GROUND_SLOP) ||
	pointblocked(this._x + this._width,
		     this._y + this._height + GROUND_SLOP))
      return true;

    return false;
  }

  public function blockedleft() {
    return false;
  }

  public function blockedright() {
    return false;
  }


}
