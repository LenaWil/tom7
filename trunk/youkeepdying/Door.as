
class Door extends MovieClip {

  // Configured in editor. Must be unique to this room.
  var doorname : String;
  // If we hit this door, which frame do we switch to?
  var frametarget : String;
  // Which door in that frame to warp to?
  var doortarget : String;
  // Which direction should the player be facing to enter this
  // door?
  //    4
  //  2   1
  //    3
  var dir : Number;

  var tall;

  public function onLoad() {
    /* for debuggin' */
    // this._alpha = 50;
    /* should be invisible. */
    this._visible = false;

    if (this._height > this._width) tall = true;

    if (this.frametarget && this.doortarget) {
      /* put in local door list, but create
         that list if it doesn't exist first. */
      if (!_root["doors"].length) {
        _root["doors"] = [];
      }
      _root["doors"].push(this);
    } else {
      /* Don't bother putting it in the door list
         if it doesn't take us anywhere, because
         then we avoid the hit tests on every frame. */

      // XXX for debugging, show doors that have no
      // destination
      // trace(this.doorname + ' bogus: ' + this);
      // this._visible = true;
      // this._rotation = 45;
    }
  }

  // Probably something sensible to check wrt
  // tall/wide. How can I enter a tall door
  // with direction downward?
  public function correctdir(dx, dy) {
    switch(this.dir) {
    case 1: return dx > 0;
    case 2: return dx < 0;
    case 3: return dy > 0;
    case 4: return dy < 0;
    default: return true; // any?
    }
  }

  /* XXX .... */

}
