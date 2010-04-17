class UnderwaterArea extends PhysicsArea {

  public function onLoad() {
    super.onLoad();
  }

  public function getConstants(phys : PhysicsObject, cs) {
    cs.gravity = .3;
    cs.maxspeed = 3.5;
    cs.terminal_velocity = 7;
    cs.decel_ground = 1.5;
    cs.decel_air = 0.7;
  }
}
