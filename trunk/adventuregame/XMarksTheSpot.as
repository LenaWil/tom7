
class XMarksTheSpot extends Manipulable {

  var homeframe:Number;

  public function onLoad() {
    /* set y depth, so that player can go behind it. */
    // trace("staticthing swapdepths " + this._y);
    if (_root["memory"].getFlag("treasure_map")) {
      /* available ! */
      this._visible = true;
    } else {
      this._visible = false;
    }

    this.eyeballverb = "look at";
    this.handleverb = "dig in"
    this.showname = "the place where the x marks the spot";
    this.description = "It's not really there, but that's where the map marked.";

    this.setdepth(this._y);
    homeframe = _root._currentframe;
    super.onLoad();
  }

  public function dohandle () {
    _root["player"].say("I can't really dig with my hands.");
  }

  public function onEnterFrame() {
    if (_root._currentframe != homeframe) {
	/* destroy! */
      this.swapDepths(0);
      this.removeMovieClip();
    }
  }
}
