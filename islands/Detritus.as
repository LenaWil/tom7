class Detritus extends Positionable {

  var idx : Number;
  var gamex : Number;
  var gamey : Number;
  var theta : Number;
  var dx : Number;
  var dy : Number;

  public function onLoad() {
    this._rotation = theta;
    this.dx += Math.random() * 12 - 6;
    this.dy += Math.random() * 32 - 20;
    if (dy > 6) dy = 6;
    this.theta += Math.random() * 30 - 15;
    this.gamex += Math.random() * 5 - 2.5;
    this.gamey += Math.random() * 5 - 2.5;
  }

  var frames : Number = 0;

  public function onEnterFrame() {
    frames++;
    if (frames > 100) {
      _root.global.giveup(this.idx);
      this.removeMovieClip();
      return;
    } else {
      this.gamex += dx;
      this.gamey += dy;
      dy ++;
      this._rotation ++;
      _root.viewport.place(this);
      this._xscale --;
      this._yscale --;
      this._alpha --;
    }
  }

}
