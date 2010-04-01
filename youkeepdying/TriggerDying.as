class TriggerDying extends Trigger {
  public function activate() {
    _root.dying.fall();
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.centerhit(this);
  }
}
