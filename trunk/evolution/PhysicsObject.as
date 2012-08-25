// Rectangular "physics" object. Anything that
// can move uses this.
//
// Note, this is not the same as the ones in other copies
// of this library. I stopped using _x and _y directly, instead
// updating the .x and .y properties.

class PhysicsObject extends Depthable {
  // Position in world pixels.
  var x = 0;
  var y = 0;

  // Velocity x/y
  var dx = 0;
  var dy = 0;

  // Almost always want to override these!
  var width = 128;
  var height = 128;

  var top = 0;
  var left = 0;
  var right = 0;
  var bottom = 0;

  // Only affected by floor, not other physics objects.
  public function ignoresquares() {
    return false;
  }

  // Called when touching another physics object. To
  // tell the angle of touch you've got to compare
  // positions.
  public function touch(phys : PhysicsObject) {}

  // Physics constants. These can be overridden
  // by the subclass, though things like gravity
  // probably should be true constants.
  public function defaultconstants() {
    return {
      accel: 3.6,
      accel_air: 1.4,
      decel_ground: 0.95,
      decel_air: 0.05,
      jump_impulse: 17.8,
      gravity: 1.2,
      xgravity: 0.0,
      terminal_velocity: 13,
      maxspeed: 9.9,
      dive: 0.3 };
  }

  public function getConstants() {
    return defaultconstants();
  }

  /* These are typically overridden so that
     the object is not just deadweight. */
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

  // These are latched: They physics code sets them
  // and the client must clear them.
  var collision_right = false;
  var collision_left = false;
  var collision_up = false;
  var collision_down = false;

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
    // trace('getout1d ' + pos + ' -> ' + safepos);
    if (f.apply(this, [pos])) {
      trace('started stuck.');
      // Invariant: pos is bad, safepos is good.
      while (Math.abs(pos - safepos) > 0.1) {
        var mid = (safepos + pos) / 2;
        var stuck = f.apply(this, [mid]);
        // trace(pos + ' -> ' + mid + (stuck ? '!' : '') + ' <- ' + safepos);
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
    if (safey > this.y) {
      // get out of ceiling
      this.y = getOut1D(this.y, safey, blockedup);
    } else {
      // get out of floor
      this.y = getOut1D(this.y, safey, blockeddown);
    }
  }

  public function getOutHoriz(safex) {
    if (safex > this.x) {
      // get out of left wall
      this.x = getOut1D(this.x, safex, blockedleft);
    } else {
      // get out of right wall
      this.x = getOut1D(this.x, safex, blockedright);
    }
  }

  /* Resolves physics:
     - Use DX and DY to modify the position, subject to
     ...
   */
  public function movePhysics() {
    // By invariant, when we enter the frame, we're not inside
    // any blocks. First, resolve y:

    var oy = move1DClip(this.y, dy, (dy < 0) ? blockedup : blockeddown);
    this.y = oy.pos;
    dy = oy.dpos;

    // Now x:
    var ox = move1DClip(this.x, dx, (dx < 0) ? blockedleft : blockedright);
    this.x = ox.pos;
    dx = ox.dpos;

    // Check physics areas to get the physics constants, which we use
    // for the rest of the updates.
    var C = getConstants();

    setVelocity(C);
  }

  /* Can override this if you don't want to use the normal
     controls (and physics) */
  public function setVelocity(C) {
    var otg = ontheground();

    if (otg && wishjump()) {
      dy = -C.jump_impulse;
    }

    /*
    if (wishdive()) {
      if (!otg) {
        dy += C.dive;
      }
    }
    */

    if (wishright()) {
      dx += otg ? C.accel : C.accel_air;
      if (dx > C.maxspeed) dx = C.maxspeed;
    } else if (wishleft()) {
      dx -= otg ? C.accel : C.accel_air;
      if (dx < -C.maxspeed) dx = -C.maxspeed;
    } else {
      // If not holding either direction,
      // slow down and stop (quickly)
      if (otg) {
        // On the ground, slow to a stop very quickly
        if (dx > C.decel_ground) dx -= C.decel_ground;
        else if (dx < -C.decel_ground) dx += C.decel_ground;
        else dx = 0;
      } else {
        // In the air, not so much.
        if (dx > C.decel_air) dx -= C.decel_air;
        else if (dx < -C.decel_air) dx += C.decel_air;
        else dx = 0;
      }
    }

    if (otg) {
      dx += C.xgravity;
      if (dx < -C.terminal_velocity) dx = -C.terminal_velocity;
      else if (dx > C.terminal_velocity) dx = C.terminal_velocity;
    } else {
      dy += C.gravity;
      if (dy > C.terminal_velocity) dy = C.terminal_velocity;
    }

  }

  // Is the point x, y in any block?
  public function pointblocked(xx, yy) {
    // These count as 'touching'.

    /*
    if (!ignoresquares()) {
      for (var o in _root.squares) {
        var b = _root.squares[o];
        // no self-collisions!
        if (b != this) {
          if (xx >= b.x1() && xx <= b.x2() &&
              yy >= b.y1() && yy <= b.y2()) {
            this.touch(b);
            return true;
          }
        }
      }
    }
    */

    // Can of course also be blocked by the map.
    // These don't count as 'touching'.
    return _root.world.solidAt(xx, yy);
  }

  public function widthblocked(xx, yy, w) {
    return pointblocked(xx, yy) || pointblocked(xx + w, yy) ||
      pointblocked(xx + (w / 2), yy);
  }

  public function heightblocked(xx, yy, h) {
    return pointblocked(xx, yy) || pointblocked(xx, yy + h) ||
      pointblocked(xx, yy + (h / 2));
  }

  var GROUND_SLOP = 2.0; // ???
  public function ontheground() {
    return widthblocked(x1(),
                        y2() + GROUND_SLOP,
                        (this.width - this.left - this.right));
  }

  /*
  public function leftfootonground() {
    return pointblocked(this._x + this.width * .1,
                        this._y + this.height + GROUND_SLOP);
  }

  public function rightfootonground() {
    return pointblocked(this._x + this.width * .8,
                        this._y + this.height + GROUND_SLOP);
  }
  */

  public function x1() {
    return this.x + this.left;
  }

  public function x2() {
    return this.x + this.width - this.right;
  }

  public function y1() {
    return this.y + this.top;
  }

  public function y2() {
    return this.y + this.height - this.bottom;
  }

  public function clipheight() {
    return 0.95 * (this.height - this.top - this.bottom);
  }

  public function clipwidth() {
    return this.width - this.left - this.right;
  }

  public function blockedleft(newx) {
    var yes = heightblocked(newx + this.left, y1(), clipheight());
    collision_left = collision_left || yes;
    return yes;
  }

  public function blockedright(newx) {
    var yes = heightblocked(newx + this.width - this.right, y1(), clipheight());
    collision_right = collision_right || yes;
    return yes;
  }

  public function blockedup(newy) {
    var yes = widthblocked(x1(), newy + this.top, clipwidth());
    collision_up = collision_up || yes;
    return yes;
  }

  public function blockeddown(newy) {
    var yes = widthblocked(x1(), newy + this.height - this.bottom, clipwidth());
    collision_down = collision_down || yes;
    return yes;
  }

}
