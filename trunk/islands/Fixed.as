class Fixed extends Depthable {
  public function onLoad() {
    this.setdepth(15);
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push(this);
  }

}
