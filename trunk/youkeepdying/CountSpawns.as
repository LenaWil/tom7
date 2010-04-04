// Counts spawns for stats page.
class CountSpawns extends Depthable {

  var msg : TextField;

  public function onEnterFrame() {
    this.msg.text = 
      _root.memory.nspawnsfound + '/' + 
      _root.memory.reachablespawns.length;
  }

  public function onLoad() {
    // in background
    this.setdepth(200);
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push(this);
  }

}
