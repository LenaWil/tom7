// Rectangular "physics" object. The player,
// dead player bodies, items, and enemies use this
// base class.
class PhysicsObject extends Depthable {
  // Velocity x/y
  var dx = 0;
  var dy = 0;

  // Almost always want to override these!
  var width = 1;
  var height = 1;

  // Overridden for objects that should behave
  // like they're carrying an umbrella.
  public function hasUmbrella() {
    return false;
  }

  // Physics constants. These can be overridden
  // by the subclass, though things like gravity
  // probably should be true constants.
  public function defaultconstants() {
    return { 
      accel: 3,
      decel_ground: 0.95,
      decel_air: 0.05,
      jump_impulse: 13.8,
      gravity: 1.0,
      terminal_velocity: 9,
      maxspeed: 5.9,
      dive: 0.3 };
  };

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

    // Check physics areas to get the physics constants, which we use
    // for the rest of the updates.
    var C = defaultconstants();
    for (var d in _root.physareas) {
      var mca = _root.physareas[d];
      if (mca.isHit(this, dx, dy)) {
        if (mca.getConstants != undefined) 
          mca.getConstants(this, C);
        else trace("no getConstants");
      }
    }

    var otg = ontheground();

    if (otg && wishjump()) {
      dy = -C.jump_impulse;
    }

    if (wishdive()) {
      if (!otg) {
        dy += C.dive;
      }
    }

    if (wishright()) {
      dx += C.accel;
      if (dx > C.maxspeed) dx = C.maxspeed;
    } else if (wishleft()) {
      dx -= C.accel;
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

    if (!otg) {
      dy += C.gravity;
      if (dy > C.terminal_velocity) dy = C.terminal_velocity;
    }
  }

  public function centerhit(mc) {
    return mc.hitTest(this._x + this.width * .5, 
                      this._y + this.height * .5,
                      true);
  }

  public function anyhit(mc) {
    return mc.hitTest(this);
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
    return widthblocked(this._x + this.width * .1,
                        this._y + this.height + GROUND_SLOP,
                        this.width * .8);
  }

  public function leftfootonground() {
    return pointblocked(this._x + this.width * .1, 
                        this._y + this.height + GROUND_SLOP);
  }

  public function rightfootonground() {
    return pointblocked(this._x + this.width * .8, 
                        this._y + this.height + GROUND_SLOP);
  }
  
  public function x1() {
    return this._x;
  }

  public function x2() {
    return this._x + this.width;
  }

  public function y1() {
    return this._y;
  }

  public function y2() {
    return this._y + this.height;
  }

  var CORNER = 0;
  public function blockedleft(newx) {
    var yes = heightblocked(newx, 
                            this._y + this.height * CORNER, 
                            this.height * (1 - 2 * CORNER));
    collision_left = collision_left || yes;
    return yes;
  }

  public function blockedright(newx) {
    var yes = heightblocked(newx + this.width, 
                         this._y + this.height * CORNER, 
                         this.height * (1 - 2 * CORNER));
    collision_right = collision_right || yes;
    return yes;
  }

  public function blockedup(newy) {
    return widthblocked(this._x + this.width * CORNER,
                        newy,
                        this.width * (1 - 2 * CORNER));
  }

  public function blockeddown(newy) {
    return widthblocked(this._x + this.width * CORNER,
                        newy + this.height,
                        this.width * (1 - 2 * CORNER));
  }
  
}
