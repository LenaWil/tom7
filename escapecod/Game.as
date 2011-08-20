class Game extends MovieClip {
  
  // The fish I'm currently in. I just use this to animate.
  var fish_mc;

  // The movieclip of the ball. positioned manually on every frame.
  // Not scaled.
  var ball_mc : MovieClip = null;
  // in pixels. constant since we never scale the ball.
  var RADIUS = 25;

  // TODO: radar

  // These are all in "game" coordinates (not screen), which
  // is centered around the fish's registration point (center)
  // with scale = 1.0. We do all of the physics in this orientation,
  // but then draw it rotated and scaled and whatever.

  // All the border vectors. These are objects {x0, y0, x1, y1} where
  // a "floor" border has x0 < x1.
  var borders;

  // normalized gravity vector
  var gravityddx, gravityddy;
  // position of center of ball. Constant size.
  var ballx, bally;
  // velocity of ball.
  var balldx, balldy;

  // TODO: fish's acceleration. Should only matter when you're
  // on the wall. Or actually, should be significantly dampened when
  // you're not on the wall.



  var all_fishes = [ 'red' ];

  var PLAYING = 0;
  var mode = PLAYING;

  var advance = false;
  public function onKeyDown() {
    var k = Key.getCode();

    advance = true;

    /*
    switch(k) {
    case 192: // ~
      escKey = '~';
      if (!blockEsc) holdingEsc = true;
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
    */
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
      _root.attachMovie("red", "fish" + ctr, 4000,
                        {_x: 300, _y: 300});

    // Caller should have established this or nearly so, so that
    // this doesn't jump.
    ballx = 0;
    bally = 0;

    // copy geometry from fish. game coords.
    borders = fish_mc.borders;
    /*
    trace('fishmc:');
    for (var o in fish_mc) {
      trace(o);
    }
    */
  }

  // Initialize, the first time.
  public function onLoad() {
    Key.addListener(this);

    balldx = 0;
    balldy = 0;
    gravityddx = 0;
    gravityddy = 4;

    ball_mc = _root.attachMovie("pinball", "pinball", 5000,
                                // XXX won't be right; should
                                // be set in first onEnterFrame though.
                                {_x: 0, _y: 0})

    setFish('red');

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
    trace('resolveforce ' + startx + ' ' + starty + ' +' +
          dx + ' ' + dy + ' against' + borders.length);
    var collisions = [];
    var BOUNCE_RADIUS = RADIUS * 1.05;

    // Get the list of all possible collisions, in collision
    // space. XXX assumes the ball's motion vector has length
    // no more than its radius times 2.
    for (var i = 0; i < borders.length; i++) {
      var b = borders[i];
      // Transform the problem so that we are falling towards
      // a floor like this:

      //      tbx,tby
      //         \
      //          > tdx,tdy
      //
      //   -----------------  ty0 = ty1 = 0
      //   tx0 = 0        tx1

      // We save the width.
      var tx1 = b.w;
      
      // move ball so that its origin is wrt x0,y0
      var mbx = startx - b.x0;
      var mby = starty - b.y0;
      // (because to rotate the border to angle 0,
      // we'd rotate it the negative of its current angle)
      var rotb = rotateVec(mbx, mby, -b.rrad);
      var rotd = rotateVec(dx, dy, -b.rrad);

      var tbx = rotb.dx;
      var tby = rotb.dy;
      var tdx = rotd.dx;
      var tdy = rotd.dy;

      // Okay, now solve the problem. Does the circle
      // intersect the line segment? Find the closest
      // point on the line segment.
      // PERF: Could compute this before transforming,
      // since it's trivial to test whether two points are
      // within the radius. Then we can skip the transforms
      // most of the time.
      
      var newx = tbx + tdx;
      var newy = tby + tdy;

      var n = closestPoint(newx, newy, 0, 0, tx1, 0);

      var dist = distance(newx, newy, n.x, n.y);
      trace('closest: ' + n.x + ' ' + n.y + ' (' + dist + ')');

      /*
      if (dist < BOUNCE_RADIUS) {
        collisions.push({tbx: tbx, tby: tby,
              tdx: tdy, 


      }
      */
    }

    ballx = startx + dx;
    bally = starty + dy;
  }

  public function onEnterFrame() {

    // Might be in several different modes.
    // 1. TODO: Zooming out and replacing the fish. No control.
    // 2. TODO: Zooming out and winning the game. No control.
    // 3. Normal play:
    if (mode == PLAYING) {

      // XXX frame-by-frame mode
      if (!advance)
        return;
      advance = false;

      //  - Check keyboard/mouse to get ball's intention

      //  - Simulate physics, resolving against geometry
      balldx += gravityddx;
      balldy += gravityddy;
      // XXX terminal velocity checks

      resolveForce(ballx, bally, balldx, balldy);
      
      // Clip against all borders. The algorithm is not too bad:
      //  1. Maintain the invariant that the circle never intersects
      //     any line.
      //  2. If the circle was in front of the line before, and is
      //     atop it now, 
      // ...


      
      fish_mc._x = 300;
      fish_mc._y = 300;
      ball_mc._x = 300 + ballx;
      ball_mc._y = 300 + bally;

      //  - Check if we've made it into the exit area, transitioning
      //    states.

      // Update world:
      //  - For each fish in the world, run their AI to go after
      //    me or bloop around or whatever.
      //  - Same for my own fish. This affects the fish's acceleration
      //    parameters above (and gravity), but it doesn't have to be
      //    this frame since the fish's world location does not affect 
      //    game coordinates.
      //    (though world update could happen before physics resolution
      //     if we want.)
      //  - My fish might be eaten. Animate that happening. On the radar,
      //    animate the larger fish drawing chomping on the smaller one.
      //    as it chomps, make its scale (and the scale of anything else
      //    on the marine radar) explode as they scale out. Repopulate
      //    the world with new fish, maybe by fading in, or maybe by
      //    starting them off-screen.
      //  TODO: The marine radar requires clipping of movieclips within it.
      //     nice. You can do this with flash "masks". I learned a new thing!

    }
  }

}
