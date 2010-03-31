class You extends PhysicsObject {

  var dx = 0;
  var dy = 0;

  var holdingUp = false;
  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;

  var width = 64.65;
  var height = 43.75;

  var FPS = 25;

  // Single item we're currently holding;
  // optional.
  var item : Item = undefined;

  var respawning : Number = 0;
  var respawn_warp : String = undefined;

  // Contains my destination door
  // when warping.
  var doordest : String;

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

  public function hasUmbrella() {
    return this.item && this.item.hasUmbrella();
  }

  public function onLoad() {
    Key.addListener(this);
    this.setdepth(5000);
    this.stop();
  }

  public function onKeyDown() {
    var k = Key.getCode();
    //     trace(k);
    switch(k) {
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

  var aileffects = 0;
  public function ail(ailname, deathanim, frames, opts) {
    // Can't get more ailed (unless maybe time is less?)
    // (Should I really be able to avoid burning by having
    // bees on me??)
    if (this.ailment) return;

    aileffects++;
    var mc = _root.attachMovie("ailments", "ail_" + aileffects, 
                               // above my body
                               5500 + aileffects);

    mc.gotoAndPlay(ailname);
    // It's a clone of me so it keeps my physical parameters.
    mc._x = this._x;
    mc._y = this._y;
    mc._xscale = this._xscale;
    mc._yscale = this._yscale;

    ailment = { ailname : ailname,
                mc : mc,
                deathanim : deathanim,
                frames : frames,
                // for resetting ailment timer
                startframes : frames,
                opts : opts };
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
    // Discard item. Maybe in some special cases we'd keep it?
    // it works fine.
    this.item = undefined;

    bodies++;
    var body = _root.attachMovie("deadyou", "body_" + bodies, 1999 + bodies);
    // It's a clone of me so it keeps my physical parameters.
    body._x = this._x;
    body._y = this._y;
    body._xscale = this._xscale;
    body._yscale = this._yscale;

    // Don't persist ailments unless they're infectious.
    if (opts.byailment) {
      // Only thing special to do is pass on the
      // ailment to the dead body, if infectious.
      if (opts.infectious) {
        // takes the movie clip and everything;
        // no need to detach it.
        trace('infected!');
        body.ailment = this.ailment;
        this.ailment = undefined;
      } else {
        trace('cured');
        this.ailment.mc.swapDepths(0);
        this.ailment.mc.removeMovieClip();
        this.ailment = undefined;
      }
    } else if (this.ailment) {
      _root.message.say('You keep dying!');
      this.ailment.mc.swapDepths(0);
      this.ailment.mc.removeMovieClip();
      this.ailment = undefined;
    }

    // XXX should be able to override physics: For example when
    // being zapped we should just freeze in place. When being shot
    // we probably get some velocity imparted.
    body.dx = this.dx;
    body.dy = this.dy;

    body.gotoAndPlay(anim);

    var floating = (opts.floating == undefined) ? false : opts.floating;
    var solid = (opts.solid == undefined) ? true : opts.solid;

    body.init(floating, solid);

    this._visible = false;

    // XXX option that overrides respawn still, for
    // portal gameplay
    this.dx = 0;
    this.dy = 0;

    if (opts.warpto == undefined) {
      // Same screen respawn; normal.
      respawn_warp = undefined;
      this.respawning = 15;

      var mcs = _root.spawn;
      if (mcs) {
        // play respawn animation
        mcs.becomeVisible();
        this.waitRespawn();
      } else {
        trace("There's no spawn on this screen!");
      }

    } else {
      respawn_warp = opts.warpto;
      this.respawning = 15;

    }
  }

  // When spawning, we're already at the target position.
  // Become invisible for a moment, disable physics, and lock keys.
  public function waitRespawn() {
    // Animation is about 15 frames (600ms). Could be settable by
    // the death trigger?
    this.respawning = 15;
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

  // Since we don't want to rely on the initialization
  // order of objects on the stage, we do any room-entering
  // stuff here.
  var homeframe : Number;
  public function firstTime() {
    if (homeframe != _root._currentframe) {
      homeframe = _root._currentframe;

      /* Upon changing rooms via spawn, the player has his
         'respawn_warp' property set to the string name of
         the frame. If it's set, then we're on that frame
         and should respawn. */
      if (respawn_warp != undefined) {
        respawn_warp = undefined;
        _root.spawn.becomeVisible();
        // Wait until respawn animation finishes.
        this.waitRespawn();

        // Ignore door warps.
        return;
      }

      /* Upon changing rooms via a door, the player will have his
         'doordest' property set to the door he should spawn in. Check
         all of the doors to find the appropriate one. */

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
            this._x = cx - this.width / 2;
            this.getOutVert(cy);
          } else {
            this._y = cy - this.height / 2;
            this.getOutHoriz(cx);
          }
        }
      }
    }
  }

  var pingpong = ['1', '1', '2', '2', '3', '3', '2', '2']

  var framemod : Number = 0;
  var facingright = true;
  public function onEnterFrame() {
    firstTime();
    if (this.respawning > 0) {
      // If respawning, this is a countdown timer.
      // We ignore keys and physics because we're
      // invisible.
      this.respawning--;

      // If the timer just ran out, then do the
      // respawn. We set position at the last
      // moment since the spawn itself might be
      // moving. (XXX also absorb a little of
      // its velocity!)
      if (this.respawning == 0) {
        if (this.respawn_warp != undefined) {
          this.changeframe(this.respawn_warp);
          // Do not continue; new frame!
          return;
        } else {
          var mcs = _root.spawn;
          if (mcs) {
            this.dx = mcs.dx;
            this.dy = mcs.dy;
            this._x = mcs._x - this.width / 2;
            this._y = mcs._y - this.height / 2;
            this._visible = true;
          } else {
            trace('when respawn timer ended, the spawn ' +
                  'spot was gone!?');
          }
          // And continue into regular behavior...
        }
      } else {
        return;
      }
    }

    if (this.ailment != undefined) {
      this.ailment.frames--;
      if (this.ailment.frames <= 0) {
        _root.message.say('You have died of ' + 
                          this.ailment.ailname + '!');
        this.ailment.opts.byailment = true;
        this.die(this.ailment.deathanim, this.ailment.opts);
        // Don't continue with turn if dying.
        return;
      } else {
        this.ailment.mc._x = this._x;
        this.ailment.mc._y = this._y;
        var dsecs = Math.round(this.ailment.frames * 10 / FPS);
        var isec = Math.round(dsecs / 10);
        var fsec = dsecs % 10;
        _root.message.say('[' + isec + '.' + fsec + ']  ' +
                          this.ailment.ailname + '!');
      }
    }

    // We know we're not inside anything. We can safely
    // modify the velocity in response to user input,
    // gravity, etc.

    touchset = [];
    movePhysics();

    // Now, if we touched someone, give it some
    // love.
    for (var o in touchset) {
      var other = touchset[o];

      // Contract its ailments, if it's infectious and
      // we're not.
      if (!this.ailment && other.ailment) {
        this.ailment = other.ailment;
        // also need to reset timer...
        this.ailment.frames = this.ailment.startframes;
        other.ailment = undefined;
      }

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
    if (this._y < 130) {
      _root.message._y = (290 + _root.message._y) / 2;
    } else {
      _root.message._y = (14 + _root.message._y) / 2;
    }

    // Set animation frames.
    var otg = ontheground();
    if (otg) {
      if (dx > 1) {
        facingright = true;
        framemod++;
        framemod = (framemod + 1) % 8;
        this.gotoAndStop('r' + pingpong[framemod]);
      } else if (dx > 0) {
        this.gotoAndStop('r0');
      } else if (dx < -1) {
        facingright = false;
        framemod++;
        framemod = (framemod + 1) % 8;
        this.gotoAndStop('l' + pingpong[framemod]);
      } else if (dx < 0) {
        this.gotoAndStop('l0');
      } else {
        if (facingright) {
          this.gotoAndStop('r0');
        } else {
          this.gotoAndStop('l0');
        }
      }
      // ...
    } else {
      if (facingright) {
        this.gotoAndStop('ra');
      } else {
        this.gotoAndStop('la');
      }
    }

    var xattach, yattach;
    if (facingright) {
      // XXX fakey. Scaled by .25
      xattach = 241 / 4;
      yattach = 40 / 4;
    } else {
      xattach = 17 / 4;
      yattach = 27 / 4;
    }

    if (this.item != undefined) {
      // Offset of the 'hold' point from the
      // item's registration point (which is its
      // top left, so that it can be a physics object)
      var xh = this.item.xhold ? this.item.xhold : 0;
      var yh = this.item.yhold ? this.item.yhold : 0;

      // assume zero...
      this.item._x = this._x + xattach - xh;
      this.item._y = this._y + yattach - yh;
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
      if (mct.isHit(this, dx, dy)) {
        if (mct.activate != undefined) mct.activate();
        else trace("no activate");
      }
    }

    if (this.item == undefined) {
      for (var d in _root.items) {
        var mci = _root.items[d];
        if (mci.isHit(this, dx, dy)) {
          this.item = mci;
          // Item should be held behind
          // the player (right?)
          this.item.setdepth(4000);
          // Play "get" animation or sound...
        }
      }
    }
  }

  /* go to a frame, doing cleanup and
     initialization... */
  public function changeframe(s : String) {
    /* clear doors */
    _root.doors = [];
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

    _root.triggers = [];
    _root.physareas = [];
    
    for (var o in _root.deleteme) {
      _root.deleteme[o].swapDepths(0);
      _root.deleteme[o].removeMovieClip();
    }
    _root.deleteme = [];
    
    // Make spawn dot hidden, since it
    // can visibly persist across boards, which
    // can spoil some puzzles.
    // Deleting it here causes problems where
    // it won't be there when we come back?
    if (_root.spawn) {
      // _root.spawn.swapDepths(0);
      // _root.spawn.removeMovieClip();
      // _root.spawn = undefined;
      _root.spawn._visible = false;
    }

    // Also detach items, unless we're carrying
    // them.
    for (var o in _root.items) {
      if (this.item == _root.items[o]) {
        trace('holding onto ' + this.item);
      } else {
        _root.items[o].swapDepths(0);
        _root.items[o].removeMovieClip();
      }
    }
    // Item stays with us.
    if (this.item) {
      _root.items = [this.item];
    } else {
      _root.items = [];
    }

    _root.gotoAndStop(s);
  }

}
