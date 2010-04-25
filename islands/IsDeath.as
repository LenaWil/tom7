class IsDeath extends MovieClip {

  public function onLoad() {
    // this._visible = false;
    if (!_root.deaths) _root.deaths = [];
    _root.deaths.push(this);
  }
}
