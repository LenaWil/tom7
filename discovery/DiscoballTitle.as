class DiscoballTitle extends MovieClip {


  var TWOPI : Number = 3.141592653589 * 2.0;
  var stars = [];
  

  /*
  public function newPosition(t, i) {
    if (this.totalframes < 80) {
      this["m" + i]._x = 50.0 * Math.random();
      this["m" + i]._y = Math.random () * height;
      this["m" + i]._xscale = Math.random() * 20.0 + 90.0;
      this["m" + i]._yscale = Math.random() * 20.0 + 90.0;
      // rotations? based on energy too
      this["m" + i]._rotation = Math.random() * 360.0;
      this["m" + i]._alpha = Math.random() * 20.0 + 80.0;
    } else this["m" + i]._visible = false;
  }
  */

  var NUMSTARS = 250;
  public function onLoad() {
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
    for (var i = 0; i < stars.length; i++) {
      // Set position from theta, rho, and rotate theta.
      var star = stars[i];
      star.theta -= (TWOPI / (30.0 * 24.0));

        var oldx = star.m._x;
        star.m._x = Math.sin(star.theta) * 800.0
          * Math.sin(star.rho)
          + 400.0; 
        
        star.m._y = (star.rho / TWOPI) * 600.0 * 2.2 +
          Math.cos(star.theta) * 30.0;
        
        if (star.m._x > oldx) {
          star.m.swapDepths(1100 + i);
        } else {
          star.m.swapDepths(200 + i);
        }

    }
  }
};
