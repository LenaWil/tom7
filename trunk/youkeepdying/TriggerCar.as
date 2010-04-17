class TriggerCar extends Trigger {
  public function activate() {
    _root.car.play();
    _root.you.die('splatscreen');
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.centerhit(this) && !(phys.hasUmbrella() ||
                                     phys.hasCopysicle());
  }
}
