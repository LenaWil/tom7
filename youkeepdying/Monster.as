
// Base class for monsters. Monsters are physics
// objects that are visible and also have trigger
// functionality (like Triggers)--the activate()
// member function is called if the player touches
// it. You usually want to implement an onEnterFrame
// that calls movePhysics, or it'll just sit there.
//
// Make sure monsters (and all other physics objects)
// have their registration point in the upper left!
class Monster extends PhysicsObject {

  public function onLoad() {
    /* put in local trigger list, but create
       that list if it doesn't exist first. */

    // Subclass can override these if it wants, but
    // this is better than the 1,1 default.
    // trace(this._xscale + ' ' + this._yscale);
    this.width = this._width;
    this.height = this._height;
    // trace(this.width + ' ' + this.height);
    // this.dx = -5;

    if (!_root.triggers) {
      _root.triggers = [];
    }
    _root.triggers.push(this);
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.anyhit(this);
  }

  /* XXX .... */

}
