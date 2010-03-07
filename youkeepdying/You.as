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

  /* Starting at the 1-dimensional position 'pos' (which may not be
     blocked), move with velocity dpos along it. If the member
     function f returns true, then we are blocked; move to
     (approximately) the closest position where we're not blocked.
     Returns the new position and velocity (set to zero if we hit
     something.) */
  public function move1DClip(pos, dpos, f) {
    var newpos = pos + dpos;

    // XXX probably should check invariant since it can probably 
    // be violated in rare cases (fp issues).
    if (f.apply(this, [newpos])) {

      // invariant: pos is good, newpos is bad
      // XXX EPSILON?
      while (Math.abs(newpos - pos) > .01) {
        var mid = (newpos + pos) / 2;
        if (f.apply(this, [mid])) {
          newpos = mid;
        } else {
          pos = mid;
        }
      }

      return { pos : pos, dpos : 0 };
    } else {
      return { pos : newpos, dpos : dpos };
    }
  }

  public function onEnterFrame() {
    // By invariant, when we enter the frame, we're not inside
    // any blocks. First, resolve y:

    var oy = move1DClip(this._y, dy, (dy < 0) ? blockedup : blockeddown);
    this._y = oy.pos;
    dy = oy.dpos;

    // Now x:
    var ox = move1DClip(this._x, dx, (dx < 0) ? blockedleft : blockedright);
    this._x = ox.pos;
    dx = ox.dpos;

    // We know we're not inside anything. We can safely
    // modify the velocity in response to user input,
    // gravity, etc.

    var otg = ontheground();

    if (holdingRight) {
      dx += ACCEL;
      if (dx > MAXSPEED) dx = MAXSPEED;
    } else if (holdingLeft) {
      dx -= ACCEL;
      if (dx < -MAXSPEED) dx = -MAXSPEED;
    } else {
      // If not holding either direction,
      // slow down and stop (quickly)
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
      // dy = 0;
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
    return widthblocked(this._x + this._width * .1,
                        this._y + this._height + GROUND_SLOP,
                        this._width * .8);
  }

/*
  public function blockedleft() {
    return heightblocked(this._x, 
                         this._y + this._height * .1, 
                         this._height * .8);
  }

  public function blockedright() {
    return heightblocked(this._x + this._width, 
                         this._y + this._height * .1, 
                         this._height * .8);
  }

  public function blockedup() {
    return widthblocked(this._x + this._width * .1,
                        this._y,
                        this._width * .8);
  }
*/

  var CORNER = 0;
  public function blockedleft(newx) {
    return heightblocked(newx, 
                         this._y + this._height * CORNER, 
                         this._height * (1 - 2 * CORNER));
  }

  public function blockedright(newx) {
    return heightblocked(newx + this._width, 
                         this._y + this._height * CORNER, 
                         this._height * (1 - 2 * CORNER));
  }

  public function blockedup(newy) {
    return widthblocked(this._x + this._width * CORNER,
                        newy,
                        this._width * (1 - 2 * CORNER));
  }

  public function blockeddown(newy) {
    return widthblocked(this._x + this._width * CORNER,
                        newy + this._height,
                        this._width * (1 - 2 * CORNER));
  }


}
