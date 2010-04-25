class Magmaball extends Depthable {
  var idx : Number;
  var par : Magmafield;

  public function onLoad() {
    
  }

  var frames : Number = 0;

  public function onEnterFrame() {
    frames++;
    if (frames > 100) {
      par.kill(this);
      this.removeMovieClip();
      return;
    } else {
      this._y--;
      this._xscale --;
      this._yscale --;
      this._alpha --;
    }
  }
}
