class Foreground extends Depthable {

  var homeframe:Number;

  public function onLoad() {
    /* support multiple foreground objects
       by using some variable offset here */
    this.setdepthof(this, 98969);
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
