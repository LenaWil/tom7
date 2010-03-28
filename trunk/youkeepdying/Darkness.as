class Darkness extends Depthable {
  public function onLoad() {
    // In front of foreground objects even
    this.setdepth(12000);
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push(this);
  }
}
