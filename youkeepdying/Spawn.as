
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
    this._visible = false;
    onEnterFrame();
  }

  public function onEnterFrame() {
    if (lastframe != _root._currentframe) {
      lastframe = _root._currentframe;
      trace('re-spawn');

      // XXX look up state to see if we should be
      // displayed. Jump straight to 'there' if
      // we are (no reason to highlight the spawn's
      // location when just arriving on the board)
      this._visible = false;
      this.stop();

      /* for debuggin' */
      // this._alpha = 15;
      /* should be invisible. */
      // this._visible = false;
      if (dir == undefined) dir = 1;

      _root["spawn"] = this;
    }
  }

  // When first "unlocking" a spawn spot,
  // play this animation.
  // XXX maybe every time?
  public function becomeVisible() {
    this._visible = true;
    this.gotoAndPlay('appear');
  }

}
