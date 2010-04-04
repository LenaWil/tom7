// Counts signs for stats page.
class CountSigns extends Depthable {

  var msg : TextField;

  public function onEnterFrame() {
  }

  public function onLoad() {
    // in background
    this.setdepth(200);
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push(this);

    // Can do initialization once here, since there
    // are no signs on the screen itself.
    this.msg.text = 
      _root.memory.nconstructionfound + '/' + 
      _root.memory.underconstruction.length;
  }

}
