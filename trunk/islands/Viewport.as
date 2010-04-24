// The viewport just tells us what part of the game we're looking at.

class Viewport {

  var width : Number = 800;
  var height : Number = 600;

  // Top-left of viewport, in game
  // coordinates.
  var gamex : Number = 0;
  var gamey : Number = 0;

  public function setView(x : Number, y : Number) {
    gamex = x;
    gamey = y;
  }

  // Give the location of the plane, the angle in degrees, and the
  // cos/sin of its
  // angle. Slowly moves the view so that the plane is on the
  // outside facing in.
  public function setForPlane(planex : Number, planey : Number,
                              degs : Number,
                              cost : Number, sint : Number) {

    // As percentages.
    var desiredx = 0.5, desiredy = 0.5;
    /*
    if (degs >= 0 && degs <= 45) {
      desiredy = (45 - degs) / 90;
    } else if (degs >= 45 && degs <= 135) {
      desiredy = 0;
    } else if (degs > 135 && degs <= 225) {
      desiredy = (degs - 135) / 90;
    } else if (degs > 315 && degs <= 360) {
      desiredy = (360 - degs) / 90 + 0.5;
    } else {
      desiredy = 1;
    }

    if (degs < 45 || degs > 315) {
      desiredx = 0;
    } else if (degs > 135 && degs < 225) {
      desiredx = 1;
    } else if (degs >= 45 && degs <= 135) {
      desiredx = (degs - 45) / 90;
    } else if (degs >= 225 && degs <= 315) {
      desiredx = (1 - (degs - 225) / 90);
    }
    */
    //   trace(degs + ': ' + desiredy);

    // var gox = planex - ((460 - 74) - 250 * cost);
    //     var desiredy = planey - ((360 - 79) - 250 * sint);
    var gox = planex - (.1 * width + (width * .8 * desiredx));
    var goy = planey - (.1 * height + (height * .8 * desiredy));

    var curx = gamex;
    var cury = gamey;

    var newx = (gox * .3 + curx * .7); // 2;
    var newy = (goy * .3 + cury * .7); // 2;

    gamex = newx;
    gamey = newy;
    
    //    gamex = planex - width / 2;
    //    gamey = planey - height / 2;
  }

  /*
  public function transx(x : Number) {
    return x - gamex;
  }

  public function transy(y : Number) {
    return y - gamey;
  }
  */

  public function place(obj : Positionable) {
    obj._x = obj.gamex - gamex;
    obj._y = obj.gamey - gamey;
  }

  public function placex(gx) {
    return gx - gamex;
  }

  public function placey(gy) {
    return gy - gamey;
  }

  // Move the object within its parent (which must have been just placed)
  // so that it is a the screen coordinates x, y.
  public function unplace(parent : Positionable, obj : MovieClip, 
                          x : Number, y : Number) {
    obj._x = x - parent._x;
    obj._y = y - parent._y;
  }
  
}
