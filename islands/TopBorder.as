class TopBorder extends MovieClip {

  public function onLoad() {
    // this._visible = false;
    _root.topborder = this._y + this._height;
    trace('topborder: ' + (this._y + this._height));
  }

}
