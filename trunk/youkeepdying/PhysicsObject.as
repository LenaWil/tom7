// Rectangular "physics" object. The player,
// dead player bodies, and enemies use this
// base class.
class PhysicsObject extends MovieClip {
  // Velocity x/y
  var dx = 0;
  var dy = 0;

  // Physics constants. These can be overridden
  // by the subclass, though things like gravity
  // probably should be true constants.
  var ACCEL = 3;
  var DECEL_GROUND = 0.95;
  var DECEL_AIR = 0.05;
  var JUMP_IMPULSE = 11.8;
  var GRAVITY = 0.7;
  var TERMINAL_VELOCITY = 9;
  var MAXSPEED = 5.9;
  var DIVE = 0.3;

  /* These are typically overridden so that
   the object is not just deadweight. */
  public function wishleft() {
    return false;
  }

  public function wishright() {
    return false;
  }

  public function wishdive() {
    return false;
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

  /* Try to move the minimal distance towards safepos
     that gets us unstuck, according to the function f. If
     we're not stuck at all, keep the same position. */
  public function getOut1D(pos, safepos, f) {
    trace('getout1d ' + pos + ' -> ' + safepos);
    if (f.apply(this, [pos])) {
      trace('started stuck.');
      // Invariant: pos is bad, safepos is good.
      while (Math.abs(pos - safepos) > 0.1) {
        var mid = (safepos + pos) / 2;
        var stuck = f.apply(this, [mid]);
        trace(pos + ' -> ' + mid + (stuck ? '!' : '') + ' <- ' + safepos);
        if (stuck) {
          pos = mid;
        } else {
          safepos = mid;
        }
      }
      return safepos;
    } else {
      return pos;
    }
  }

  public function getOutVert(safey) {
    if (safey > this._y) {
      // get out of ceiling
      this._y = getOut1D(this._y, safey, blockedup);
    } else {
      // get out of floor
      this._y = getOut1D(this._y, safey, blockeddown);
    }
  }

  public function getOutHoriz(safex) {
    if (safex > this._x) {
      // get out of left wall
      this._x = getOut1D(this._x, safex, blockedleft);
    } else {
      // get out of right wall
      this._x = getOut1D(this._x, safex, blockedright);
    }
  }

  /* Resolves physics:
     - Use DX and DY to modify the position, subject to 
     ...
   */
  public function movePhysics() {
    // By invariant, when we enter the frame, we're not inside
    // any blocks. First, resolve y:

    var oy = move1DClip(this._y, dy, (dy < 0) ? blockedup : blockeddown);
    this._y = oy.pos;
    dy = oy.dpos;

    // Now x:
    var ox = move1DClip(this._x, dx, (dx < 0) ? blockedleft : blockedright);
    this._x = ox.pos;
    dx = ox.dpos;

    var otg = ontheground();

    if (wishdive()) {
      if (!otg) {
        dy += DIVE;
      }
    }

    if (wishright()) {
      dx += ACCEL;
      if (dx > MAXSPEED) dx = MAXSPEED;
    } else if (wishleft()) {
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

    if (!otg) {
      dy += GRAVITY;
      if (dy > TERMINAL_VELOCITY) dy = TERMINAL_VELOCITY;
    }
  }

  public function centerhit(mc) {
    return mc.hitTest(this._x + this._width * .5, 
                      this._y + this._height * .5,
                      true);
  }

  // Is the point x,y in any block?
  public function pointblocked(x, y) {
    for (var o in _root.squares) {
      var b = _root.squares[o];
      /* no self-collisions! */
      if (b != this) {
        if (x >= b.x1() && x <= b.x2() &&
            y >= b.y1() && y <= b.y2())
          return true;
      }
    }

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

  public function x1() {
    return this._x;
  }

  public function x2() {
    return this._x + this._width;
  }

  public function y1() {
    return this._y;
  }

  public function y2() {
    return this._y + this._height;
  }

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
