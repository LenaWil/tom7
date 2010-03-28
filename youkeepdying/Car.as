class Car extends Depthable {
  public function onLoad() {
    // Behind player, but in front of stage (go over wire)
    this.setdepth(1000);
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push(this);
  }
}
