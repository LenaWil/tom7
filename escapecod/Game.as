class Game extends MovieClip {
  
  // The fish I'm currently in. I just use this to animate.
  var fish_mc : Fish = null;

  // The movieclip of the ball. positioned manually on every frame.
  // Not scaled.
  var ball_mc : MovieClip = null;

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

  // Make the game be the named fish. This puts the ball at the origin
  // in game coordinates and then gives control to the player.
  //
  // Doesn't do anything with an existing fish movie clip. (If you
  // hang onto it, make sure to move it to a new depth, since 4000
  // is reserved for the current fish.)
  var ctr = 0;
  public function setFish(name) {
    ctr++;
    fish_mc = (Fish)
      _root.attachMovie("red", "fish" + ctr, 4000,
                        {_x: 300, _y: 300});

    // Caller should have established this or nearly so, so that
    // this doesn't jump.
    ballx = 0;
    bally = 0;

    // copy geometry from fish. game coords.
    borders = fish_mc.borders;
  }

  var modes = { playing: {} };
  var mode = modes.playing;

  // Initialize, the first time.
  public function onLoad() {
    balldx = 0;
    balldy = 0;
    gravityddx = 0;
    gravityddy = 4;

    ball_mc = _root.attachMovie("pinball", "pinball", 5000,
                                // XXX won't be right; should
                                // be set in first onEnterFrame though.
                                {_x: 0, _y: 0})

    setFish('red');

    mode = mode.playing;
  }

  public function onEnterFrame() {

    // Might be in several different modes.
    // 1. TODO: Zooming out and replacing the fish. No control.
    // 2. TODO: Zooming out and winning the game. No control.
    // 3. Normal play:
    if (mode == modes.playing) {
      //  - Check keyboard/mouse to get ball's intention
      //  - Simulate physics, resolving against geometry
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
