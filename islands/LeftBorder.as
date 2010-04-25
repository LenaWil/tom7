class LeftBorder extends MovieClip {

  public function onLoad() {
    // this._visible = false;
    _root.leftborder = this._x + this._width;
    trace('leftborder: ' + (this._x + this._width));
  }

}
