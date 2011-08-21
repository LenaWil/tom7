class Game extends MovieClip {

  var SCREENW = 900;
  var SCREENH = 700;

  // The fishes I'm inside, not including the one that is
  // currently the game. Element 0 is the nearest enclosing fish.
  // Just fish names like 'purple'.
  var inside_fishes = ['orange', 'green', 
                       'purple', 'red', 'orange',
                       'green', 'red', 'purple', 'red',
                       'red', 'purple', 'orange', 'red', 'purple',
                       'red', 'orange', 'purple', 'green', 'purple',
                       'orange', 'orange', 'green', 'purple',
                       'red', 'green', 'red' ];
  var current_background = 0;
  
  // The fish I'm currently in. I just use this to animate. We
  // keep game state locally.
  var fish_mc;
  var fish_mc_radar;

  // Previous fish's movie clip. Only set when mode == REGURGITATE.
  var old_fish_mc;
  // when regurgitating, we offset the old fish by this amount.
  var old_fishx;
  var old_fishy;


  // Background movieclip. Replaced with an empty movie clip
  // and then filled whenever we need a new background color.
  var background_mc = null;

  // Fish is always at 0,0.
  var fishdx = 0, fishdy = 0;
  // Heading in radians.
  var fishr;
  // Fish can only steer by changing dr, but it can change it pretty quickly.
  var fishdr;
  // XXX randomize at start?
  var fishdestx = 100, fishdesty = 20;
  var fishboredom = 0;
  
  // Not a pun. Percentage of full size that the fish should
  // render at. Usually 100, but when being swallowed, we zoom
  // out by setting this to 30-ish.
  var fishscale = 100;
  var MIN_SCALE = 30;

  // My current fish is always at world coordinates 0,0. There
  // are other fish swiming with it though. Fields:
  //  who: fish name
  //  mc_big: the movieclip, attached to root. shown when we
  //    are close to it. positioned in game's onEnterFrame.
  //  mc_radar: the movieclip, attached to the radar. shown
  //    more often.
  //  x,y: authoritative world coordinates, relative to
  //    the current fish.
  //  dx,dy: velocity vector
  //  r,dr: rotation and drotation in radians
  //  destx,desty: destination when swimming aimlessly.
  //  hungry: true if we're swimming straight towards the
  //    target fish (at 0,0) with our mouth open, to try to
  //    eat it.
  var other_fish = [];

  // The movieclip of the ball. positioned manually on every frame.
  // Not scaled.
  var ball_mc : MovieClip = null;
  // in pixels. constant since we never scale the ball.
  var RADIUS = 25;
  var ELASTICITY = 0.7;

  var FRICTION = 0.7;

  // TODO: radar
  var radar_mc;

  // These are all in "game" coordinates (not screen), which
  // is centered around the fish's registration point (center)
  // with scale = 1.0. We do all of the physics in this orientation,
  // but then draw it rotated and scaled and whatever.

  // All the border vectors. These are objects {x0, y0, x1, y1} where
  // a "floor" border has x0 < x1. Aliases the fish's property.
  var borders = null;
  // Same. Always axis aligned with x0,x1 at top left. Usually just
  // one. Aliases the fish's property.
  var exits = null;

  // normalized gravity vector
  // var gravityddx, gravityddy;
  var XGRAVITY = 0;
  var YGRAVITY = 4;

  // position of center of ball. Constant size.
  var ballx, bally;
  // velocity of ball.
  var balldx, balldy;

  // TODO: fish's acceleration. Should only matter when you're
  // on the wall. Or actually, should be significantly dampened when
  // you're not on the wall.

  var all_fishes = 
    { red: { bg: 0x581C1C },
      purple: { bg: 0x421458 },
      orange: { bg: 0x794A11 },
      green: { bg: 0x092A12 } };
  var fishnames = [];

  var PLAYING = 0;
  var REGURGITATE = 1;
  var mode = PLAYING;

  var advance = true;
  var holdingSpace = false, holdingEsc = false,
    holdingUp = false, holdingLeft = false,
    holdingRight = false, holdingDown = false;
  public function onKeyDown() {
    var k = Key.getCode();

    advance = true;

    switch(k) {
    case 27: // esc
    case 'r':
      holdingEsc = true;
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
    case 27: // esc
      holdingEsc = false;
      break;

    case 32:
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

  public function setBackground(hexcolor) {
    if (this.background_mc) {
      this.background_mc.removeMovieClip();
    }
    this.background_mc = _root.createEmptyMovieClip('bg', 1000);
    this.background_mc._x = 0;
    this.background_mc._y = 0;

    this.background_mc.beginFill(hexcolor);
    this.background_mc.moveTo(0, 0);
    this.background_mc.lineTo(0, SCREENH);
    this.background_mc.lineTo(SCREENW, SCREENH);
    this.background_mc.lineTo(SCREENW, 0);
    this.background_mc.endFill();
  }

  // Read the fish's pieces. This doesn't hide the movieclips
  // (that's done in the onLoad for the fish), but keeps the
  // canonical copy. We only do it for the fish we're actually
  // using, not like all the fish swimmin' around.
  public function getFishPieces(f) {
    this.borders = [];
    this.exits = [];

    for (var o in f) {
      if (f[o] instanceof Solid) {
        var mc = f[o];

        // Because it's 100 units wide, and scale is
        // in percentage.
        var w = mc._xscale;
        var rrad = (mc._rotation / 360.0) * 2.0 * Math.PI;
        var x0 = mc._x;
        var y0 = mc._y;
        var x1 = x0 + Math.cos(rrad) * w;
        var y1 = y0 + Math.sin(rrad) * w;

        // trace('found solid ' + o + ' ' + x0 + ' ' + y0);
        this.borders.push({x0 : x0, y0 : y0, x1 : x1, y1 : y1,
              w : w, rrad : rrad });

      } else if (f[o] instanceof Exit) {
        var mc = f[o];
        // trace('found exit ' + o + ' ' + mc._x + ' ' + mc._y);
        // Assuming these are axis aligned with the registration
        // in the top-left corner.
        this.exits.push({x0: mc._x, y0: mc._y,
              x1: mc._x + mc._xscale,
              y1: mc._y + mc._yscale});
      }
    }
  }


  // Make the game be the named fish. This puts the ball at the origin
  // in game coordinates and then gives control to the player.
  //
  // Doesn't do anything with an existing fish movie clip. (If you
  // hang onto it, make sure to move it to a new depth, since 4000
  // is reserved for the current fish.)
  var ctr = 0;
  public function setFish(name) {
    ctr++;
    fish_mc =
      _root.attachMovie(name, "fish" + ctr, 4000,
                        {_x: -10000, _y: -10000});
    // start unhungry.
    fish_mc.gotoAndStop(1);

    fish_mc_radar =
      this.radar_mc.attachMovie(name + '_radar', 'myfish', 8100,
                                {_x: -10000, _y: -10000});

    // never hungry. already ate a pinball.
    fish_mc_radar.gotoAndStop(1);

    // should this be randomized? or remembered from when the
    // fish swallowed us, for continuity if we escape just as
    // being swallowed?
    fishdr = 0;
    fishr = 0;

    /*
    // Caller should have established this or nearly so, so that
    // this doesn't jump.
    ballx = 0;
    bally = 0;
    */

    this.borders = null;
    this.exits = null;

    /*
    trace('fishmc:');
    for (var o in fish_mc) {
      trace(o);
    }
    */
  }

  // Let's say 10 other fish.
  var NUM_OTHER = 10;
  // A fish is about 700x600. Make room
  // for a hundred fish in each direction.
  var WORLD_WIDTH = 70000;
  var WORLD_HEIGHT = 60000;
  public function initializeOthers() {
    for (var i = 0; i < other_fish.length; i++) {
      other_fish[i].mc_big.removeMovieClip();
      other_fish[i].mc_radar.removeMovieClip();
    }
    other_fish = [];

    for (var i = 0; i < NUM_OTHER; i++) {
      var who = fishnames[int(Math.random() * 9999) % fishnames.length];

      // The current fish is always at 0,0.
      var x = Math.random() * WORLD_WIDTH - (WORLD_WIDTH / 2);
      var y = Math.random() * WORLD_HEIGHT - (WORLD_HEIGHT / 2);

      // Random destination.
      var destx = Math.random() * WORLD_WIDTH - (WORLD_WIDTH / 2);
      var desty = Math.random() * WORLD_HEIGHT - (WORLD_HEIGHT / 2);

      // XXX avoid collisions with the current fish!

      var mc_big = _root.attachMovie(who, 'other' + i, 3900 + i,
                                     {_x: -10000, _y: -10000});
      mc_big.gotoAndStop(1);

      var mc_radar = this.radar_mc.attachMovie(who + '_radar', 'otherr' + i,
                                               8000 + i, 
                                               {_x: -10000, 
                                                _y: -10000});
      mc_radar.gotoAndStop(1);

      // Start at a random angle? Based on the way these fish swim
      // it's realistic...
      var r = Math.random() * 2 * Math.PI - Math.PI;
      var dr = 0;

      other_fish.push({who: who, x: x, y: y, mc_big: mc_big,
            mc_radar: mc_radar, r: r, dr: dr,
            dx: 0, dy: 0, hungry: false, destx: destx, desty: desty });
    }
  }

  // Place the movie clip on the screen at the desired
  // fish-centric coordinates. Doesn't set or do anything with
  // rotation, but takes care of any scaling.
  var XOFFSET = 320;
  var YOFFSET = 420;
  public function fishToScreen(mc, x, y, scale) {
    mc._x = XOFFSET + x * (fishscale / 100);
    mc._y = YOFFSET + y * (fishscale / 100);
    mc._xscale = scale * (fishscale / 100);
    mc._yscale = scale * (fishscale / 100);
  }

  // Ignores scaling because we need a visual cheat so
  // that the pinball doesn't keep getting smaller as more
  // fishes swallow you. Takes care of rotation.
  public function ballToScreen(mc, x, y, rrad) {
    var sinr = Math.sin(rrad);
    var cosr = Math.cos(rrad);
    mc._x = XOFFSET + (x * cosr - y * sinr) * (fishscale / 100);
    mc._y = YOFFSET + (x * sinr + y * cosr) * (fishscale / 100);
    mc._xscale = fishscale;
    mc._yscale = fishscale;
  }

  var RADAR_XOFFSET = Radar.WIDTH / 2;
  var RADAR_YOFFSET = Radar.HEIGHT / 2;
  var RADAR_SCALE = 45;
  var RADAR_FISH_SCALE = 4;
  public function fishToRadar(mc, x, y) {
    mc._x = RADAR_XOFFSET + x / RADAR_SCALE;
    mc._y = RADAR_YOFFSET + y / RADAR_SCALE;
    mc._xscale = 100 / RADAR_FISH_SCALE;
    mc._yscale = 100 / RADAR_FISH_SCALE;
  }

  // Initialize, the first time.
  public function onLoad() {
    Key.addListener(this);

    for (var o in all_fishes)
      fishnames.push(o);

    ballx = 0;
    bally = 0;

    balldx = 0;
    balldy = 0;

    ball_mc = _root.attachMovie("pinball", "pinball", 5000,
                                // note: won't be right; should
                                // be set in first onEnterFrame though.
                                {_x: 0, _y: 0});
    
    radar_mc = _root.attachMovie("radar", "radar", 6000,
                                 {_x: SCREENW - Radar.WIDTH, _y: 0});

    setFish('purple');

    // Need to populate the world.
    initializeOthers();

    mode = PLAYING;
  }

  // Rotate an unnormalized vector.
  public function rotateVec(dx, dy, rrad) {
    var sinr = Math.sin(rrad);
    var cosr = Math.cos(rrad);
    return { dx : dx * cosr - dy * sinr,
             dy : dx * sinr + dy * cosr };
  }

  public function distance(v1x, v1y, v2x, v2y) {
    var vdx = (v2x - v1x);
    var vdy = (v2y - v1y);
    var ds = vdx * vdx + vdy * vdy;
    return Math.sqrt(ds);
  }

  // Get the closest point between the point and the vector
  // described by the other two.
  // PERF lots of redundant calculations here; also, useful
  // to return the distance too since we often compute it
  // again.
  public function closestPoint(px, py, v1x, v1y, v2x, v2y) {
    // distance squared
    var vdx = (v2x - v1x);
    var vdy = (v2y - v1y);
    var ds = vdx * vdx + vdy * vdy;
    var u = ((px - v1x) * vdx +
             (py - v1y) * vdy) / ds;
  
    if (u < 0.0 || u > 1.0) {
      // endpoint collision. Which one?
      var d1 = distance(px, py, v1x, v1y);
      var d2 = distance(px, py, v2x, v2y);
      return (d1 < d2) ? { x : v1x, y : v1y } : { x : v2x, y : v2y };
    } else {
      return { x : v1x + u * vdx, y : v1y + u * vdy };
    }
  }

  // Return the borders that I'd collide with if the ball were at
  // x,y.
  var last_collisions = [];
  var BOUNCE_RADIUS = RADIUS * 1.05;
  public function getCollisionsAt(x, y, r) {
    var collisions = [];

    /*
    for (var i = 0; i < last_collisions.length; i++) {
      last_collisions[i].removeMovieClip();
    }

    last_collisions.push(_root.attachMovie("star", "star" + ctr, 50000 + ctr,
                                          {_x: 300 + x, _y: 300 + y}));
    */

    for (var i = 0; i < this.borders.length; i++) {
      var b = this.borders[i];
      var n = closestPoint(x, y, b.x0, b.y0, b.x1, b.y1);
      var dist = distance(x, y, n.x, n.y);

      /*
      ctr++;
      last_collisions.push (_root.attachMovie("star", "star" + ctr, 50000 + ctr,
                                             {_x: 300 + n.x, _y: 300 + n.y}));
      */
      
      if (dist < r) {
        collisions.push({b : b, n : n, dist : dist});
      }
    }
    return collisions;
  }

  // Move the ball from startx,starty as far along dx,dy
  // while staying out of clipped regions. Returns the
  // list of collisions.
  public function moveStaySafe(startx, starty, dx, dy) {
    /*
    trace('moveStaySafe ' + startx + ' ' + starty + ' +' +
          dx + ' ' + dy + ' against ' + borders.length);
    */

    if (getCollisionsAt(startx, starty, RADIUS).length > 0) {
      trace('started stuck.');
      return;
    }

    var newx = startx + dx;
    var newy = starty + dy;
    var cnew = getCollisionsAt(newx, newy, RADIUS);

    if (cnew.length > 0) {
      // trace('resolving collisions with ' + cnew.length);
      // invariant: start is good, new is bad.
      while (distance(startx, starty, newx, newy) > .05) {
        var midx = (startx + newx) * 0.5;
        var midy = (starty + newy) * 0.5;
        // PERF: could be filtering down cnew.
        cnew = getCollisionsAt(midx, midy, RADIUS);
        if (cnew.length > 0) {
          // bad.
          newx = midx;
          newy = midy;
        } else {
          // ok.
          startx = midx;
          starty = midy;
        }
      }
      ballx = startx;
      bally = starty;
      return cnew;
    } else {
      // trace('no collisions at dest');
      // No collision (common case).
      ballx = newx;
      bally = newy;
      return [];
    }
  }
  
  // Resolve the motion of the ball, assuming we don't start
  // inside an obstacle. Without any obstacles,
  // this just sets ballx = startx + dx and bally = starty + dy.
  // In the case that this puts us inside an object, we make
  // the increment smaller and do binary search to find a
  // collision time and position. Once the delta (dx, dy)
  // is small enough, we compute a reflection force based
  // on the original balldx and balldy, as well as the angle(s)
  // of whatever we're colliding with.
  public function resolveForce(startx, starty, dx, dy) {

    // First, put the ball in a new location that's safe.
    var col = moveStaySafe(startx, starty, dx, dy);

    if (col.length > 0) {
      /*
      trace('there are collisions with ' +
            col.length + '. old vel: ' +
            dx + ' ' + dy);
      */
      var dxs = 0, dys = 0;

      // For each collision, compute the reflected force. Average
      // all of those.
      for (var i = 0; i < col.length; i++) {
        var b = col[i].b;
        // Transform the problem so that we are falling towards
        // a floor like this:

        //      tbx,tby
        //         \
        //          > tdx,tdy
        //
        //   -----------------  ty0 = ty1 = 0
        //   tx0 = 0        tx1

        // (because to rotate the border to angle 0,
        // we'd rotate it the negative of its current angle)
        var rotd = rotateVec(dx, dy, -b.rrad);

        // Since the floor is flat, we always bounce by just
        // reversing dy but keeping the same dx.
        var refdx = rotd.dx;
        var refdy = -ELASTICITY * rotd.dy;

        // Now rotate back to game space.
        var unrotd = rotateVec(refdx, refdy, b.rrad);
        // Accumulate forces.
        dxs += unrotd.dx;
        dys += unrotd.dy;
      }

      // New dx,dy is the average of the forces applied.
      balldx = dxs / col.length;
      balldy = dys / col.length;

      // trace('new vel: ' + balldx + ' ' + balldy);
    }
  }

  var REGURGITATE_FRAMES = 24;
  var framesleft = 0;

  public function onEnterFrame() {

    // Hack: Can't do this until the thing has actually loaded.
    // But it will be loaded before we enter a frame, which is
    // the first time we need it.
    if (this.borders == null) {
      getFishPieces(fish_mc);
      // trace('now there are ' + this.borders.length + ' borders');
    }

    // Set background for radar and game. Do this since we could
    // get swallowed at any time, and we can't do it in initialization
    // anyway since the radar won't have loaded yet.

    // Sea color if not swallowed.
    var bgcolor = 0x15235B;

    if (inside_fishes.length > 0) {
      bgcolor = all_fishes[inside_fishes[0]].bg;
    }

    if (current_background != bgcolor) {
      // trace('setting bgcolor to ' + bgcolor);
      current_background = bgcolor;
      this.radar_mc.setBackground(bgcolor);
      this.setBackground(bgcolor);
    }


    // Might be in several different modes.
    // 1. TODO: Zooming out and replacing the fish. No control.
    // 2. TODO: Zooming out and winning the game. No control.
    // 3. Normal play:
    if (mode == PLAYING) {

      // XXX frame-by-frame mode
      if (!advance)
        return;
      // advance = false;

      //  - Check keyboard/mouse to get ball's intention

      //  - Simulate physics, resolving against geometry

      // Apply acceleration. Don't use the bounce code to
      // apply forces when on surfaces, as it produces jittery
      // or sticky results at best. If we're near walls,
      // apply rolling forces.

      // Some acceleration is in screen orientation.
      // gravity is always down; arrows don't rotate with
      // the fish...
      var sddx = XGRAVITY;
      var sddy = YGRAVITY;

      // no air jumps!
      if (holdingUp) {
        sddy -= 20;
      }

      if (holdingLeft) {
        sddx -= 3;
      } else if (holdingRight) {
        sddx += 3;
      }

      var dd = rotateVec(sddx, sddy, -fishr);
      

      var col = getCollisionsAt(ballx, bally, BOUNCE_RADIUS);
      if (col.length > 0) {

        // Apply gravity normal forces.
        var ndx = 0, ndy = 0, denom = 0;
        for (var i = 0; i < col.length; i++) {
          // as in resolveForce
          var b = col[i].b;
          var rotd = rotateVec(dd.dx, dd.dy, -b.rrad);

          if (rotd.dy > 0) {
            var refdy = 0;
            // dot product is just x component in this
            // orientation.
            var refdx = rotd.dx;
            var unrotd = rotateVec(refdx, refdy, b.rrad);
            // Accumulate forces.
            denom++;
            ndx += unrotd.dx;
            ndy += unrotd.dy;
          }
        }

        // If we had any downward collisions, accumulate
        // the tangent forces.
        if (denom > 0) {
          balldx += ndx / denom;
          balldy += ndy / denom;
        } else {
          // else equivalent to freefall, but
          // attenuate because of friction
          balldx += dd.dx;
          balldy += dd.dy;
        }
        
        balldx *= FRICTION;
        balldy *= FRICTION;

      } else {
        // free-fall
        balldx += dd.dx;
        balldy += dd.dy;
      }


      // terminal velocity checks. Collision code assumes it's
      // not moving faster than its diamter, currently.
      var dlen = Math.sqrt((balldx * balldx) + (balldy * balldy));
      if (dlen > RADIUS * 1.2) {
        // Make normal.
        balldx /= dlen;
        balldy /= dlen;
        balldx *= RADIUS * 1.2;
        balldy *= RADIUS * 1.2;
        // trace('set terminal: ' + balldx + ' ' + balldy);
      } else if (dlen < 1 && col.length > 0) {
        // If going very slowly and touching the wall,
        // static friction stops us.
        // trace('stop');
        balldx = 0;
        balldy = 0;
      } else {
        // trace('go');
      }

      resolveForce(ballx, bally, balldx, balldy);
      
      // Check if we've made it into an exit area, transitioning
      // states.
      for (var i = 0; i < exits.length; i++) {
        var e = exits[i];
        if (ballx > e.x0 && ballx < e.x1 &&
            bally > e.y0 && bally < e.y1) {
          // Exited!
          if (inside_fishes.length > 0) {
            // Make a nice transition to the outer fish,
            // by going into REGURGITATE mode.
            old_fish_mc = fish_mc;
            old_fish_mc.swapDepths(4010);
            fish_mc = null;

            // The new fish spawns with fishr = 0, so
            // put the ball in the same screen position
            // but as if fishr = 0.
            var nball = rotateVec(ballx, bally, fishr);
            // trace('oldball: ' + ballx + ' ' + bally + ' new: ' +
            // nball.dx + ' ' + nball.dy);
            ballx = nball.dx;
            bally = nball.dy;

            var nextfish = inside_fishes[0];
            inside_fishes = inside_fishes.slice(1);
            setFish(nextfish);
            mode = REGURGITATE;

            old_fishx = 0;
            old_fishy = 0;
            framesleft = REGURGITATE_FRAMES;
            // Immediately start, because we don't
            // want to spend any time with the fish
            // at the wrong size.
            regurgitate();
            // Don't do anything else on this frame,
            return;
          } else {
            // XXX need something to happen here...
            // you win!!
            trace('you win');
          }
        }
      }

      // Update world fish. I'll act first, since I need to adjust
      // the coordinates of all the other fish according to my
      // movement, so I stay at the center.


      // Where am I in relation to my destination? Swim towards it.
      var destdist = distance(0, 0, fishdestx, fishdesty);

      fishboredom++;
      if (destdist < 100 || fishboredom > 600) {
        // Change my destination. Keep in mind that this is centered
        // around me.
        fishdestx = Math.random() * 20000 - 10000;
        fishdesty = Math.random() * 10000 - 5000;
        fishboredom = 0;
        trace('new target: ' + fishdestx + ' ' + fishdesty);
        destdist = distance(0, 0, fishdestx, fishdesty);
      }

      // XXX. Is there another fish nearby? If so, swim away.
      
      // Accelerate in the direction I want to go.
      // This should probably be contingent on facing in
      // that direction?
      fishdx += (fishdestx / destdist) * 2;
      fishdy += (fishdesty / destdist) * 2;

      // Terminal velocity for fish.
      var MAX_FISH_VELOCITY = 40;
      var dlen = Math.sqrt((fishdx * fishdx) + (fishdy * fishdy));
      if (dlen > MAX_FISH_VELOCITY) {
        // Make normal.
        fishdx /= dlen;
        fishdy /= dlen;
        fishdx *= MAX_FISH_VELOCITY;
        fishdy *= MAX_FISH_VELOCITY;
      }

      var heading = getFishHeading(fishdx, fishdy, fishr, fishdr);
      fishr = heading.r;
      fishdr = heading.dr;

      // We don't actually modify the fish's coordinates because they
      // are always 0,0; rather, we subtract this from every other
      // fish's position.
      fishdestx -= fishdx;
      fishdesty -= fishdy;


      var closest_fish_dist = 99999;
      // trace('fishd: ' + fishdx + ' ' + fishdy);
      for (var i = 0; i < other_fish.length; i++) {
        var f = other_fish[i];
        // trace(i + ' ' + f.x + ' ' + f.y);

        f.x -= fishdx;
        f.y -= fishdy;

        // This also needs to be in world coords, relative to the
        // current fish.
        f.destx -= fishdx;
        f.desty -= fishdy;

        // Opportunistically, get hungry and go after the current
        // fish.
        var dist_to_fish = distance(f.x, f.y, 0, 0);
        if (true || dist_to_fish < 2500) {
          // trace(i + ' is hungry!!');
          f.hungry = true;
        } else if (f.hungry && dist_to_fish > 10000) {
          trace(i + ' isn\'t hungry any more');
          f.hungry = false;
        }

        if (dist_to_fish < closest_fish_dist)
          closest_fish_dist = dist_to_fish;

        // XXX if it can eat the fish, do it!

        // If it's close to its destination, pick another one.
        if (distance(f.x, f.y, f.destx, f.desty) < 400) {
          // Random destination.
          f.destx = Math.random() * WORLD_WIDTH - (WORLD_WIDTH / 2);
          f.desty = Math.random() * WORLD_HEIGHT - (WORLD_HEIGHT / 2);
        }

        // XXX animate hungry for big too.
        if (f.hungry) {
          f.mc_big.gotoAndStop(2);
          f.mc_radar.gotoAndStop(2);
        } else {
          f.mc_big.gotoAndStop(1);
          f.mc_radar.gotoAndStop(1);
        }

        var tx = f.hungry ? -f.x : (f.destx - f.x);
        var ty = f.hungry ? -f.y : (f.desty - f.y);

        // Where am I in relation to my destination? Swim towards it.
        var tdist = distance(0, 0, tx, ty);
        // XXX, also should be contingent on facing that way.
        // Should be a little faster than the current fish (it's
        // got a pinball in it. :))
        if (tdist > 0) {
          f.dx += (tx / tdist) * 2.2;
          f.dy += (ty / tdist) * 2.2;
        }

        // Terminal velocity for fish.
        var dlen = Math.sqrt((f.dx * f.dx) + (f.dy * f.dy));
        if (dlen > MAX_FISH_VELOCITY) {
          // Make normal.
          f.dx /= dlen;
          f.dy /= dlen;
          f.dx *= MAX_FISH_VELOCITY;
          f.dy *= MAX_FISH_VELOCITY;
        }

        // Try to face in the direction we're moving.
        var heading = getFishHeading(f.dx, f.dy, f.r, f.dr);
        f.dr = heading.dr;
        f.r = heading.r;

        // Now actually move this fish.
        f.x += f.dx;
        f.y += f.dy;

      }


      // Now can do all the fish drawing, finally.

      // If a fish is close by, then we start zooming out.
      if (fishscale > MIN_SCALE && closest_fish_dist < 2000) {
        fishscale = MIN_SCALE + (fishscale - MIN_SCALE) * .95;
      } else if (fishscale < 100 && closest_fish_dist >= 2000) {
        // XXX target scale could depend on the fish, since
        // some are bigger than others. Do it!
        fishscale = 100 - (100 - fishscale) * .95;
      }
      
      // at 0,0.
      fish_mc._rotation = (fishr * 180) / Math.PI;
      // always regular size
      fishToScreen(fish_mc, 0, 0, 100);

      // XXX this is wrong because game might be rotated around 0,0.
      ballToScreen(ball_mc, ballx, bally, fishr);

      // Draw main fish in radar.
      fish_mc_radar._rotation = (fishr * 180) / Math.PI;
      fishToRadar(fish_mc_radar, 0, 0);

      // other fish are triple-size
      for (var i = 0; i < other_fish.length; i++) {
        var f = other_fish[i];
        f.mc_big._rotation = (f.r * 180) / Math.PI;
        f.mc_radar._rotation = (f.r * 180) / Math.PI;
        fishToScreen(f.mc_big, f.x, f.y, 300);
        fishToRadar(f.mc_radar, f.x, f.y);
      }

      // TODO:
      //  - My fish might be eaten. Animate that happening. On the radar,
      //    animate the larger fish drawing chomping on the smaller one.
      //    as it chomps, make its scale (and the scale of anything else
      //    on the marine radar) explode as they scale out. Repopulate
      //    the world with new fish, maybe by fading in, or maybe by
      //    starting them off-screen.

    } else if (mode == REGURGITATE) {
      regurgitate();
    }
  }

  public function regurgitate() {

    /*
    if (!advance)
      return;
    advance = false;
    */

    // In this mode we are (quickly, since the user has lost
    // control) tweening between being in the fish in
    // old_fish_mc and the new fish in fish_mc.
    var frac = framesleft / REGURGITATE_FRAMES;
    framesleft--;

    if (framesleft >= 0) {
      // Eases into centering the ball at 0,0.
      // We scroll the old fish away to make it
      // look like the camera is just following
      // the ball now, but that we haven't lost
      // its velocity.
      var newballx = ballx * 0.8;
      var newbally = bally * 0.8;

      var dx = newballx - ballx;
      var dy = newbally - bally;

      ballx = newballx;
      bally = newbally;

      old_fishx += dx;
      old_fishy += dy;
      // trace(dx + ' ' + dy + ' / ' + old_fishx + ' ' + old_fishy);

      var fs = 100 + ((300 / (fishscale / 100)) * frac);
      var ofs = 100 - 75 * (1 - frac);
      old_fish_mc._alpha = frac * 100;

      ballToScreen(ball_mc, ballx, bally, 0);
      fishToScreen(old_fish_mc, old_fishx, old_fishy, ofs);
      fishToScreen(fish_mc, 0, 0, fs);

      // XXX radar too.

    } else {
      // because these are known safe coordinates.
      // we should basically already be there anyway.
      ballx = 0;
      bally = 0;

      old_fish_mc.removeMovieClip();
      old_fish_mc = null;

      // fish_mc._xscale = 100;
      // fish_mc._yscale = 100;
      fish_mc._alpha = 100;
      mode = PLAYING;
      initializeOthers();
    }
  }

  // 
  public function getFishHeading(dx, dy, r, dr) {
    // Compute the direction we'd like to be heading.
    var headingrad = Math.atan2(dy, dx);

    var newdr = headingrad - r;
    if (newdr < -Math.PI) newdr += Math.PI;
    else if (newdr > Math.PI) newdr -= Math.PI;
    dr += newdr * 0.1;

    var TERMINAL_ROTATION = 0.05;
    if (dr > TERMINAL_ROTATION) {
      dr = TERMINAL_ROTATION;
    } else if (dr < -TERMINAL_ROTATION) {
      dr = -TERMINAL_ROTATION;
    }

    // Use it.
    r += dr;
    if (r > Math.PI * 2) {
      r -= Math.PI * 2;
    }

    return { r: r, dr: dr };
  }

}

