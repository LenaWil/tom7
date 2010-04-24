class ForegroundObject extends Depthable {
  public function onLoad() {
    this.setdepth(9999);
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push(this);
  }
}
