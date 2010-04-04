
// When you see one, it records this fact.
// Otherwise, inert.
class ConstructionSign extends Depthable {

  var lastframe : Number;

  public function onLoad() {
    // behind player
    this.setdepth(300);
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push(this);
  }

  public function onEnterFrame() {
    if (lastframe != _root._currentframe) {
      lastframe = _root._currentframe;

      _root.memory.findThisSign();
    }
  }

  // Always play the animation when the spawn
  // is used. XXX it's weird that the dot re-fades
  // in each time, but it's usually covered by the
  // player.
  public function becomeVisible() {
    _root.memory.activateThisSpawn();
    this._visible = true;
    this.gotoAndPlay('appear');
  }

}
