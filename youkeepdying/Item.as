class Item extends PhysicsObject {
  var xhold : Number;
  var yhold : Number;

  public function onLoad() {
    this.width = this._width;
    this.height = this._height;

    this.setdepth(7999);
    if (!_root.items) _root.items = [];
    _root.items.push(this);
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    // Items use bounding boxes
    return phys.centerin(this);
  }

  public function onEnterFrame() {
    movePhysics();
  }
}
