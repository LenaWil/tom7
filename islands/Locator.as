class Locator extends Depthable {

  // Point at an object. Everything is screen coordinates.
  // Place the locator in the place you want it, before
  // calling this.
  public function pointAt(mc : MovieClip) {

    var myx = this._x;
    var myy = this._y;
    
    var thatx = mc._x;
    var thaty = mc._y;

    var x = thatx - myx;
    var y = thaty - myy;

    // actually, don't need to normalize.
    // var lambda = Math.sqrt(x * x + y * y);

    // nb, y,x!
    var rads = Math.atan2(y, x);

    var degs = (360 + rads * 57.2957795) % 360;

    this._rotation = degs;
  }
}
