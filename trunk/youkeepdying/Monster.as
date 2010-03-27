
// Base class for monsters. Monsters are physics
// objects that are visible and also have trigger
// functionality (like Triggers)--the activate()
// member function is called if the player touches
// it. You usually want to implement an onEnterFrame
// that calls movePhysics, or it'll just sit there.
class Monster extends PhysicsObject {

  public function onLoad() {
    /* put in local trigger list, but create
       that list if it doesn't exist first. */
    if (!_root.triggers) {
      _root.triggers = [];
    }
    _root.triggers.push(this);
  }

  public function correctdir(dx, dy) {
    return true;
  }

  /* XXX .... */

}
