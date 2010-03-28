class AirColumn extends PhysicsArea {

  var grav : Number;

  public function onLoad() {
    if (grav == undefined) grav = 0.4;
    super.onLoad();
  }

  public function getConstants(phys : PhysicsObject, cs) {
    if (phys.hasUmbrella())
      cs.gravity = grav;
  }
}
