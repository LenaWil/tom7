
class Floor extends MovieClip {
  var homeframe:Number;

  public function onLoad() {
    /* for debuggin */
    // this._alpha = 50;
    /* floor always has depth 99. nb this detaches the
       movieclip, so that it will stay when we gotoFrame */
    this.swapDepths(99);
    /* should be invisible. */
    this._visible = false;
    homeframe = _root._currentframe;
    // trace("floor loaded.");
  }

  public function onEnterFrame() {
    // trace("homeframe: " + homeframe + " / " + _root._currentframe);
    if (_root._currentframe != homeframe) {
      /* destroy! */
      this.swapDepths(0);
      this.removeMovieClip();
    }
  }

}
