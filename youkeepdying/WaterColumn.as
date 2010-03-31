class WaterColumn extends PhysicsArea {

  var force : Number;

  public function onLoad() {
    if (force == undefined) force = 0.4;
    super.onLoad();
  }

  public function getConstants(phys : PhysicsObject, cs) {
    cs.gravity += force;
  }
}
