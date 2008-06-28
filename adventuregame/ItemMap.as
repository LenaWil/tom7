
class ItemMap extends Gettable {

  public function onLoad () {
    this.handleverb = "swipe";

    this.setdepth(this._y);

    if (_root["memory"].getFlag("microwave")) {
      spawn ();
    } else {
      hide ();
    }

    super.onLoad();
  }

  public function spawn () {
    /* did we already take it? */
    if (!_root["memory"].getFlag(globalname)) {
      this._visible = true;
    }
  }

  public function hide () {
    if (!_root["memory"].getFlag(globalname)) {
      this._visible = false;
    }
  }

}
