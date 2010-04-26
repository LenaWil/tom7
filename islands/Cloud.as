class Cloud extends Depthable {
  var idx : Number;
  var par : PressSpacebar;

  var depth : Number;
  /*
  var colors = [0xFF0000, 0xFFFFFF,
		0x0000FF, 0xFF00FF,
		0xFFFF00]
  */
  var colors = [0xFFFFFF, 0xDDDDFF, 0xFFDDFF,
		0xFFFFFF, 0xBBBBFF, 0xFFBBFF]

  public function onLoad() {
    this._xscale = depth * 3;
    this._yscale = depth * 3;
    if (depth > 80) {
      this._alpha = 100 - (depth - 80);
    }
    
    var color = new Color(this);
    color.setRGB(colors[(Math.round(Math.random() * colors.length)) % colors.length]);
  }

  public function onEnterFrame() {
    this._x -= 16 * (depth / 50);
    if (this._x < -this._width) {
      par.kill(this);
      this.removeMovieClip();
    }
  }
}
