class Airplane extends Positionable {
  
  var holdingUp = false;
  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;
  var holdingEsc = false;
  var holdingSpace = false;
  var blockEsc = false;
  var escKey = 'esc';

  // Number of frames we've been offscreen,
  // or undefined if we're not offscreen.
  var offscreenframes = undefined;

  // Objects that don't need anything done except
  // to be removed if we leave the scene.
  // (in root now) var deleteme = [];

  var gamemusic : Sound;
  var volume : Number = 0;

  // Clip region for plane itself (death)
  var clip : MovieClip;

  // var dr : Number = 15;
  var dtheta : Number = 0;
  var theta : Number = 0;  // Right
  var dx : Number = 0;
  var dy : Number = 0;

  var lastx : Number = 0;
  var lasty : Number = 0;

  var pi : Number = 3.141592653589;

  var maxwarp : Number;

  var locator;

  public function onLoad() {

    gamemusic = new Sound(this);
    // gamemusic.attachSound('bouncymp3');
    gamemusic.setVolume(0);
    volume = 0;
    gamemusic.start(0, 99999);

    locator = _root.attachMovie("locator", "locator", 90000, {_x : 250, _y : 250});
    // locator._visible = false;
    locator.stop();
    
    Key.addListener(this);
    this.setdepth(1000);

    // XXX use spawn
    gamex = 150;
    gamey = 220;

    maxwarp = Math.max(_width, _height);
  }

  var crabs = 0;

  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
    case 192: // ~
      escKey = '~';
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
      /*
      crabs++;
      var c = 
        _root.attachMovie("bouncecrab", "bouncecrab" + crabs, 
                          900 + crabs,
                          {_x : this._x, _y : this._y});
      c.gamex = this.gamex;
      c.gamey = this.gamey;
      c.dx = this.dx;
      c.dy = this.dy;
      */
      holdingSpace = true;

      break;
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
      holdingSpace = false;
      break;
    case 38:
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
        var stuck = f.apply(this, [mid]);
        // trace(pos + ' -> ' + mid + (stuck ? '!' : '') + ' <- ' + safepos);
        if (stuck) {
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

  // Assumes destx and desty are blocked, safex and safey are
  // safe. Get as close as possible to the destination, but
  // not blocked.
  public function moveTowards2D(safex, safey, destx, desty) {

    if (blockedat(safex, safey)) {
      trace ('NO');
      die();
      return;
    }

    while (((destx - safex) *
            (destx - safex) +
            (desty - safey) *
            (desty - safey)) > 0.001) {
      var candx = (destx + safex) / 2;
      var candy = (desty + safey) / 2;
      if (blockedat(candx, candy)) {
        destx = candx;
        desty = candy;
      } else {
        safex = candx;
        safey = candy;
      }
    }

    gamex = safex;
    gamey = safey;
    // leftover energy reflected into dude
    // dx = destx - gamex;
    // dy = desty - gamey;
  }

  /* Compute approximate bounce using only local
     point-inside tests. We have this 3x3 grid

     +--+--+--+
     |  |  |  |
     +--+--+--+
     |  |()|  |
     +--+--+--+
     |  |  |  |
     +--+--+--+

     where we're in the center. We know the center
     is clear by precondition. The goal is to figure
     out how to bounce
  */
  public function doBounce() {
    // trace(' do bounce: ');

    if (blockedat(gamex, gamey)) {
      trace('no bounce!');
      die();
    }

    var r = 2.5;
    /*
    for (var row = 0; row < 3; row++) {
      var s = '';
      for (var col = 0; col < 3; col++) {
        if (blockedat(gamex + (r * (col - 1)), gamey + (r * (row - 1))))
          s += '#';
        else 
          s += '-';
      }
      trace(s);
    }
    */

    var A = blockedat(gamex - r, gamey - r);
    var B = blockedat(gamex, gamey - r)
    var C = blockedat(gamex + r, gamey - r);

    var D = blockedat(gamex - r, gamey);
    // no E 
    var F = blockedat(gamex + r, gamey);

    var G = blockedat(gamex - r, gamey + r);
    var H = blockedat(gamex, gamey + r)
    var I = blockedat(gamex + r, gamey + r);

    var adx = Math.abs(dx);
    var ady = Math.abs(dy);

    if (adx > ady) {
      // X-major
      if (dx > 0) {
        var obj = bMtx(A, B, C,
                       D,    F,
                       G, H, I,  dx, dy);
        dx = obj.ndx;
        dy = obj.ndy;
      } else {
        var obj = bMtx(C, B, A,
                       F,    D,
                       I, H, G,  -dx, dy);
        dx = -obj.ndx;
        dy = obj.ndy;
      }
    } else {
      if (dy > 0) {
        var obj = bMtx(C, F, I,
                       B,    H,
                       A, D, G,  dy, -dx);
        dx = -obj.ndy;
        dy = obj.ndx;
      } else {
        var obj = bMtx(G, D, A,
                       H,    B,
                       I, F, C,  -dy, dx);
        dx = obj.ndy;
        dy = -obj.ndx;
      }
    }

    // dx *= 0.8;
    // dy *= 0.8;
    // NBOUNCES++;
    // trace('bounce #' + NBOUNCES + ' with ' + dx + ' ' + dy);
  }

  var NBOUNCES : Number = 0;

  /* Assuming quote-unqoute odx is the major
     dimension of movement, odx the minor. */
  public function bMtx(A, B, C,
                       D,    F,
                       G, H, I,   odx, ody) {
//     trace('BMTX ' + odx + ' ' + ody);
//     trace('   ' + (B?'#':'-') + (C?'#':'-'));
//     trace(' -> ' + (F?'#':'-'));
//     trace('   ' + (H?'#':'-') +(I?'#':'-'));
// 
    var DEFLECTMIN : Number = 1;
    if (F || (C && I)) {
      // Blocked to my right. If C (up) or I (down) is
      // clear, we might deflect instead of reflect,
      // depending on dy.
      if ((ody <= 0 || (ody < DEFLECTMIN && I)) && !C) {
        // trace('deflect up')
        var ndx = odx; // * 0.9;
        var ndy = -0.5 * ody;
        if (ndy > 0) ndy = -0.1;
        return { ndx : ndx, ndy : ndy };
      } else if ((ody >= 0 || (ody > -DEFLECTMIN && C)) && !I) {
        //        trace('deflect down');
        var ndx = odx; // * 0.9;
        var ndy = -0.5 * ody;
        if (ndy < 0) ndy = 0.1;
        return { ndx : ndx, ndy : ndy };
      } else {
        // Must reflect dx. dy can stay the same because it's
        // a flat wall.
        return { ndx : -0.3 * odx, ndy : ody }
      }
    } else {
      // If it's actually open, then at worst a deflection.
      if ((dy < 0) && (B || C)) {
        // trace('BC deflect down');
        var ndx = odx; // * 0.9;
        var ndy = -0.5 * ody;
        if (ndy < 0) ndy = 0.1;
        return { ndx : ndx, ndy : ndy };
      } else if ((dy > 0) && (H || I)) {
        var ndx = odx; // * 0.9;
        var ndy = -0.5 * ody;
        if (ndy > 0) ndy = -0.1;
        // trace('HI deflect up: ' + odx + ', ' + ody + ' -> ' + ndx + ', ' + ndy);
        return { ndx : ndx, ndy : ndy };
      } else {
        // Appears to be no obstacles!
        // Do we want to check the case that A or G is set,
        // and maybe still deflect?
        return { ndx : odx, ndy : ody };
      }
    }
  }

  /*
    Try to get out of being stuck by iteratively exploring the space around me.
    Returns false if I can't quickly find a safe spot.
   */
  public function getOut() {
    // If I wasn't blocked in my last position, just go back there.,
    if (!blockedat(lastx, lasty)) {
      if (NBOUNCES) trace('last out');
      moveTowards2D(lastx, lasty, gamex, gamey);
      return;
    }

    // Probably best to start opposite our motion vector.
    var degs : Number = 0;
    var r : Number = 0.5;

    // trace('getting out');

    do {

      for (var degs = 0; degs < 360; degs++) {
        var sint = Math.sin(degs * 0.0174532925);
        var cost = Math.cos(degs * 0.0174532925);
        var vx = cost * r;
        var vy = sint * r;
        
        if (!blockedat(gamex + vx, gamey + vy)) {
          moveTowards2D(gamex + vx, gamey + vy, gamex, gamey);
          // trace('gotout ' + vx + ' ' + vy + ' @' + degs + ' x ' + r);
          // dx = vx * .5;
          // dy = vy * .5;
          return true;
        } else {
          // trace('still blocked with degs: ' + degs + ' and r: ' + r);
        }
      }
      // degs += 37;
      r ++; // = maxwarp / 12; // ((360 / 17) * 3);
    } while (r < maxwarp);
    trace('so stuck!!');
    return false;
  }

  public function blockedx(newx) {
    return blockedat(newx, this.gamey);
  }

  public function blockedy(newy) {
    return blockedat(this.gamex, newy);
  }

  public function blockedat(newx, newy) {
    // Could also check other solid obstacles.
    return _root.background.hit(newx, newy);
  }

  public function onEnterFrame() {



    if (volume < 100) {
      volume += 5;
      gamemusic.setVolume(volume);
    }

    // Did I crash into the floor?
    // If so, try to get out.

      // trace('collide with floor');
      // trace(' ');
      // die();
    // XXX probably don't need this outside test,
    // but there are some corner math conditions, perhaps
    if (blockedat(gamex, gamey)) {
      if (NBOUNCES > 0) trace('in some shit');

      if (!getOut()) {
        trace(' * stuck * ');
        die();
      }
    }

    // Only physical quantities affect physical position.
    /*    
    var oy = move1DClip(gamey, dy, blockedy);
    gamey = oy.pos;
    dy = oy.dpos;

    // Now x:
    var ox = move1DClip(gamex, dx, blockedx);
    gamex = ox.pos;
    dx = ox.dpos;
    */

    // new getout tech is actually better than move1dclip?
    if (blockedat(gamex + dx, gamey + dy)) {
      if (NBOUNCES > 0) trace('was blockedat');

      moveTowards2D(gamex, gamey, gamex + dx, gamey + dy);

      // reflect in current position, updating dx and dy.
      doBounce();

    } else { 
      if (NBOUNCES > 0) trace('wasnot blocked');
      gamex += dx;
      gamey += dy;
    }
    //    this.gamex += dx;
    //    this.gamey += dy;

    lastx = gamex;
    lasty = gamey;

    /*
    this.gamex += dx;
    this.gamey += dy;
    */

    /*
    this._rotation += 0.3;
    if (dy > 18) dy = 18;
    */

    // You are affected by gravity.
    dy += .1;

    // XXX: implement lift.

    // Pitch (theta) is influenced by dtheta
    this.theta += dtheta + 360;
    this.theta %= 360;

    // Then, I impart lift and thrust based on
    // my angle, changing my real physical
    // quantities.
    var sint = Math.sin(theta * 0.0174532925);
    var cost = Math.cos(theta * 0.0174532925);
    if (holdingSpace) {
      dy += 1.3 * sint;
      dx += .9 * cost;
    }

    // trace(theta + ' : ' + cost + ' -> ' + dx);

    if (dx > 16) dx = 16;
    else if (dx < -16) dx = -16;

    if (dy > 16) dy = 16;
    else if (dy < -16) dy = -16;

    // Then, the user is able to adjust the
    // intended angle and thrust.
    if (holdingDown || holdingLeft) {
      dtheta -= 1;
      if (dtheta < -10) dtheta = -10;
    } else if (holdingUp || holdingRight) {
      dtheta += 1;
      if (dtheta > 10) dtheta = 10;
    } else {
      dtheta *= .7;
    }

    // Point in the direction of theta.
    this._rotation = theta;

    // Put the maximum amount of screen in front of me.
    // Don't actually force this because it looks too Tempest.
    // Instead, slide towards the desired pos.
    
    _root.viewport.setForPlane(gamex, gamey, theta, cost, sint);

    _root.viewport.place(this);
    _root.viewport.place(_root.background);

    var xpct = 0.5, ypct = 0.5;
    var offscreen = false;
    if (this._x < 0) {
      xpct = 0;
      offscreen = true;
    } else if (this._x > _root.viewport.width) {
      xpct = 1.0;
      offscreen = true;
    }

    if (this._y < 0) {
      ypct = 0;
      offscreen = true;
    } else if (this._y > _root.viewport.height) {
      ypct = 1;
      offscreen = true;
    }

    if (offscreen) {
      if (offscreenframes == undefined) offscreenframes = 0;
      offscreenframes++;

      var nlx = xpct * _root.viewport.width * .8 + .1 * _root.viewport.width;
      var nly = ypct * _root.viewport.height * .8 + .1 * _root.viewport.height;

      locator._x = locator._x * .9 + nlx * .1;
      locator._y = locator._y * .9 + nly * .1;

      locator._visible = true;
      locator.pointAt(this);

      var step = Math.round(offscreenframes / 16);
      // trace(step);

      if (step > 13) {
        die();
      } else {
        locator.gotoAndStop(step);
      }

    } else {
      offscreenframes = undefined;
      locator._visible = false;
    }

    var altitude = Math.round(1500 - this.gamey);
    _root.altimeter.setAltitude(altitude);

    _root.angleometer.setDegs(this.theta);
    _root.velometer.setVelocity(this.dx, this.dy);

    var showmsg = false;
    for (var o in _root.deaths) {
      if (_root.background.hitpart(_root.deaths[o], gamex, gamey)) {
        _root.messagestripe.setmessage('you keep dying');
        showmsg = true;
      }
    }

    if (_root.background.hitland(gamex, gamey)) {
      _root.messagestripe.setmessage('Landing! Press ? to explode');
      showmsg = true;
    }
    
    _root.messagestripe._visible = showmsg;


    // trace(this.clip._x);
    if (NBOUNCES > 0) {
      trace('now dx dy are ' + dx + ' ' + dy);
    }

  }

  public function die() {
    for (var o in _root.deleteme) {
      _root.deleteme[o].removeMovieClip();
    }

    gamemusic.stop();
    this.removeMovieClip();
    _root.background.removeMovieClip();
    _root.altimeter.removeMovieClip();
    _root.gotoAndStop('isntland');
  }

}
