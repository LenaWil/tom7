class DiscoballTitle extends MovieClip {

  #include "constants.js"

  var titlemusic : Sound;

  var TWOPI : Number = 3.141592653589 * 2.0;
  var stars = [];
  var frames : Number = 0;
  
  var NUMSTARS = 250;
  public function onLoad() {
    Key.addListener(this);
    titlemusic = new Sound(this);
    // XXX should have title music
    titlemusic.attachSound('start.mp3');
    titlemusic.setVolume(0);
    titlemusic.start(0, 99999);

    // Populate stars.
    for(var i = 0; i < NUMSTARS; i ++) {
      // Each star has a horizontal and vertical angle (theta, rho).
      var star = 
        { m : _root.attachMovie("Star", "m" + i, i),
          theta : Math.random() * 2.0 * TWOPI - TWOPI,
          rho : Math.random() * TWOPI };
      stars.push(star);

    }
    this.swapDepths(1000);
  }

  public function onEnterFrame() {
    frames++;
    if (frames < 100) {
      titlemusic.setVolume(frames);
    }

    var alpha = 100;
    if (frames < 100) {
      alpha = frames;
    }

    for (var i = 0; i < stars.length; i++) {
      // Set position from theta, rho, and rotate theta.
      var star = stars[i];
      star.theta -= (TWOPI / (30.0 * 24.0));

      var oldx = star.m._x;
      star.m._x = Math.sin(star.theta) * 800.0
        * Math.sin(star.rho)
        + 400.0; 

      star.m._alpha = alpha;

      star.m._y = (star.rho / TWOPI) * 600.0 * 2.2 +
        Math.cos(star.theta) * 30.0;

      if (star.m._x > oldx) {
        star.m.swapDepths(1100 + i);
      } else {
        star.m.swapDepths(200 + i);
      }
    }
  }


  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
    case 32: // space

      Key.removeListener(this);

      // Kill stars
      for (var i = 0; i < stars.length; i++) {
        stars[i].m.removeMovieClip();
      }

      // better to fade out...
      this.titlemusic.stop();
      this.removeMovieClip();

      _root.gotoAndStop('game');

      // trace(GAMESCREENHEIGHT); ?? why doesn't this work?
      _root.status = _root.attachMovie('status', 'status', 15010,
                                       {_x: 0, _y: 576});
      _root.status.init();

      // XXX?
      
      if (true) {
        // Normal
        _root.you = _root.attachMovie('you', 'you', 1, {_x:50, _y:350});
        _root.you.init();
        _root.world.gotoRoom('start');
      } else {
        _root.you = _root.attachMovie('you', 'you', 1, {_x:50, _y:100});
        _root.world.gotoRoom('hole2');
      }

      break;
    }
  }

};
