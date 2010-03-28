
// Base class for physics areas. Registers the area
// and hides it. The getConstants function is called
// for physics objects that have their centers in
// the area, and can modify the base constants.
class PhysicsArea extends MovieClip {

  public function onLoad() {
    /* for debuggin' */
    this._alpha = 15;
    /* should be invisible. */
    this._visible = false;

    if (!_root.physareas) _root.physareas = [];
    _root.physareas.push(this);
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.centerhit(this);
  }

  /* public function getConstants(phys : PhysicsObject, cs); */

}
