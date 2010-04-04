
// Spawn points. There should be exactly one per
// screen, since the player could in principle die
// on any screen (e.g. infections).
class Spawn extends Depthable {

  // Only used in subclasses.
  var dx : Number = 0;
  var dy : Number = 0;

  // Facing direction for player (should be 1 or 2).
  // Default is facing right (1).
  //  2   1
  var dir : Number;

  var lastframe : Number;

  public function onLoad() {
    // behind player
    // this.setdepth(2000);
    this._visible = false;
    onEnterFrame();
  }

  public function onEnterFrame() {
    if (lastframe != _root._currentframe) {
      lastframe = _root._currentframe;

      if (_root.memory.activatedThisSpawn()) {
        // No reason to play the spawn-spawn animation
        // when just arriving on the board.
        this.gotoAndStop('there');
        this._visible = true;
      } else {
        // Not found yet.
        this._visible = false;
        this.stop();
      }

      /* for debuggin' */
      // this._alpha = 15;
      /* should be invisible. */
      // this._visible = false;
      if (dir == undefined) dir = 1;

      _root.spawn = this;
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
