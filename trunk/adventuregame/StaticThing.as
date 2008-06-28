
class StaticThing extends Manipulable {
  var homeframe:Number;

  public function onLoad() {
    /* set y depth, so that player can go behind it. */
    // trace("staticthing swapdepths " + this._y);
    this.setdepth(this._y);
    homeframe = _root._currentframe;
  }

  public function onEnterFrame() {
    if (_root._currentframe != homeframe) {
	/* destroy! */
      this.swapDepths(0);
      this.removeMovieClip();
    }
  }
}
