class Velometer extends Depthable {
  public function onLoad() {
    this.setdepth(80002);
  }

  var needle : MovieClip;

  public function setVelocity(dx : Number, dy : Number) {

    var rads = Math.atan2(dy, dx);

    var degs = (360 + rads * 57.2957795) % 360;

    this.needle._rotation = degs;

    var lambda = Math.sqrt(dx * dx + dy * dy);
    var lfrac = lambda / 16;
    if (lfrac > 1.0) lfrac = 1.0;
    this.needle.gotoAndStop(1 + Math.round(lfrac * 39));
  }

}
