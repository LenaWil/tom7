
// Base class for trigger areas. If you want the
// trigger to do anything, you have to implement
// an "activate" method in a subclass.
class Trigger extends MovieClip {

  // If there's a required direction for activating
  // the trigger, specify here. Undefined means
  // any.
  //    4
  //  2   1
  //    3
  var dir : Number;

  public function onLoad() {
    /* for debuggin' */
    this._alpha = 15;
    /* should be invisible. */
    this._visible = false;

    /* put in local trigger list, but create
       that list if it doesn't exist first. */
    if (!_root["triggers"].length) {
      _root["triggers"] = [];
    }
    _root["triggers"].push(this);
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return correctdir(dx, dy) && phys.centerhit(this);
  }

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
