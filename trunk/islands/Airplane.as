class Airplane extends Depthable {
  
  var dy : Number = 0;

  public function onLoad() {
    this.setdepth(1000);
  }

  public function onEnterFrame() {
    this._x += 10;
    this._y += dy;

    var altitude = 707 - this._y;
    _root.altimeter.setAltitude(altitude);

    this._rotation += 1;
    dy += .5;
    if (dy > 18) dy = 18;

    if (altitude <= 0) {
      _root.altimeter.removeMovieClip();
      _root.gotoAndStop('isntland');
    }

  }

}
