
// Spawn points. There should be exactly one per
// screen, since the player could in principle die
// on any screen (e.g. infections).
class Spawn extends MovieClip {

  // Facing direction for player (should be 1 or 2).
  // Default is facing right (1).
  //  2   1
  var dir : Number;

  var lastframe : Number;

  public function onLoad() {
    onEnterFrame();
  }

  public function onEnterFrame() {
    if (lastframe != _root._currentframe) {
      lastframe = _root._currentframe;
      trace('re-spawn');
      /* for debuggin' */
      // this._alpha = 15;
      /* should be invisible. */
      // this._visible = false;
      if (dir == undefined) dir = 1;

      _root["spawn"] = this;
    }
  }

}
