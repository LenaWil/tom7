class BottomBorder extends MovieClip {

  public function onLoad() {
    // this._visible = false;
    _root.bottomborder = this._y;
    trace('bottomborder: ' + this._y);
  }

}
