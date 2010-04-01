class TriggerGate extends Trigger {
  // Buttons can disable, as well as opening the gate.
  var enabled = true;

  public function activate() {
    _root.you.die('evaporate');
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return this.enabled && phys.centerhit(this);
  }
}
