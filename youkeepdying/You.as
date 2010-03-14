class You extends PhysicsObject {

  var dx = 0;
  var dy = 0;

  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;

  // Contains my destination door
  // when warping.
  var doordest : String;

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
      holdingDown = true;
      break;
    }
  }

  public function onKeyUp() {
    var k = Key.getCode();
    switch(k) {
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

    if (holdingDown) {
      if (!otg) {
        dy += DIVE;
      }
    }

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
      if (dy > TERMINAL_VELOCITY) dy = TERMINAL_VELOCITY;
    }

    // Check warping.
    for (var d in _root.doors) {
      var mcd = _root.doors[d];
      /* must be going the correct dir, and
         have actually hit the door */
      if (mcd.correctdir(dx, dy) && centerhit(mcd)) {

        /* set my doortarget. when the door loads,
           it checks my target and maybe moves me
           there. */
        this.doordest = mcd.doortarget;

        /* nb this invalidates mcd */
        this.changeframe(mcd.frametarget);

        // TODO: might disable input in order to
        // enable cutscenes, etc.

        // Shouldn't continue looking at doors!
        return;
      }
    }

    // Check triggers.
    for (var d in _root.triggers) {
      var mct = _root.triggers[d];
      // TODO: Could allow trigger to specify hit style,
      // eg. center, any, all.
      if (mct.correctdir(dx, dy) && centerhit(mct)) {
        if (mct.activate != undefined) mct.activate();
        else trace("no activate");
      }
    }
  }

  /* go to a frame, doing cleanup and
     initialization... */
  public function changeframe(s : String) {
    /* clear doors */
    _root["doors"] = [];
    _root.gotoAndStop(s);
  }

  public function centerhit(mc) {
    return mc.hitTest(this._x + this._width * .5, 
                      this._y + this._height * .5,
                      true);
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
