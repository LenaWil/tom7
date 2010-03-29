class Floor extends MovieClip {
  var homeframe : Number;

  public function onLoad() {
    trace('floor is born');
    this.swapDepths(99);
    // this._visible = false;
    homeframe = _root._currentframe;
    if (!_root.blocks) _root.blocks = [];
    _root.blocks.push(this);
  }

  public function onEnterFrame() {
    if (_root._currentframe != homeframe) {
      this.swapDepths(0);
      this.removeMovieClip();
    }
  }
}
