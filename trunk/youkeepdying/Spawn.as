
// Spawn points. There should be exactly one per
// screen, since the player could in principle die
// on any screen (e.g. infections).
class Spawn extends MovieClip {

  // Facing direction for player (should be 1 or 2).
  // Default is facing right (1).
  //  2   1
  var dir : Number;

  public function onLoad() {
    /* for debuggin' */
    this._alpha = 15;
    /* should be invisible. */
    // this._visible = false;

    if (dir == undefined) dir = 1;

    /* put in local trigger list, but create
       that list if it doesn't exist first. */
    _root["spawn"] = this;
  }

}
