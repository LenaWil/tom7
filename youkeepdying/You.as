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

  // You keep dying!
  // This takes care of everything relating to death.
  // The single player instance always respawns (possibly
  // after a delay.) We typically also spawn a body (DeadYou),
  // which might remove itself or might persist as an obstacle.
  //
  // The anim parameter gives the frame label of the animation
  // sequence (within You) to play for death.
  // The opts parameter gives other options, as a hash from
  // option to value. If a key is not present, it gets the
  // default value. Options:
  // floating : boolean [false]  Is the animation unaffected by 
  //                             physics?
  // solid : boolean [true]  Can the player step on the body?

  // XXX Need to sort out the depths stuff for realzie.
  var bodies = 0;
  public function die(anim, opts) {
    bodies++;
    var body = _root.attachMovie("deadyou", "body_" + bodies, 999 + bodies);
    // It's a clone of me so it keeps my physical parameters.
    body._x = this._x;
    body._y = this._y;
    body._xscale = this._xscale;
    body._yscale = this._yscale;

    // XXX should be able to override physics: For example when
    // being zapped we should just freeze in place. When being shot
    // we probably get some velocity imparted.
    body.dx = this.dx;
    body.dy = this.dy;

    body.gotoAndPlay(anim);

    var floating = (opts.floating == undefined) ? false : opts.floating;
    var solid = (opts.solid == undefined) ? true : opts.solid;

    body.init(floating, solid);
    
    // And respawn us.
    respawn();
  }

  // XXX with delay?
  public function respawn() {
    dx = 0;
    dy = 0;
    var mcs = _root.spawn;
    if (mcs) {
      this._x = mcs._x - this._width / 2;
      this._y = mcs._y - this._height / 2;
      // XXX play respawn animation!
    } else {
      trace("There's no spawn on this screen!");
    }
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

  // Since we don't want to rely on the initialization
  // order of objects on the stage, we do any room-entering
  // stuff here.
  var homeframe : Number;
  public function firstTime() {
    if (homeframe != _root._currentframe) {
      homeframe = _root._currentframe;

      /* Upon changing rooms, the player will have
         his 'doordest' property set to the door
         he should spawn in. Check all of the doors
         to find the appropriate one. */

      for (var o in _root.doors) {
        var door = _root.doors[o];
        if (door.doorname == this.doordest) {

          /* reg point at center for doors */
          var cx = door._x;
          var cy = door._y;

          // Depending on whether the door is wide or tall,
          // preserve one of our two coordinates. Always
          // pull ourselves out of the ceiling, wall, or
          // floor, also depending on the orientation. 
          // This assumes that cx, cy is always a safe
          // (non-stuck) location for the player.
          if (door.tall) {
            this._x = cx - this._width / 2;
            this.getOutVert(cy);
          } else {
            this._y = cy - this._height / 2;
            this.getOutHoriz(cx);
          }
        }
      }
    }
  }

  public function onEnterFrame() {
    firstTime();

    // We know we're not inside anything. We can safely
    // modify the velocity in response to user input,
    // gravity, etc.

    movePhysics();

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
    /* clear squares */
    /*
      XXX: This is better than having the
      bodies kill themselves on the first
      frame, but takes more coordination:
      How do we know the squares are all
      movieclips? etc.

      for (var o in _root.squares) {
      _root.squares[o].removeMovieClip();
      }
    */
    _root.squares = [];

    _root.gotoAndStop(s);
  }

}
