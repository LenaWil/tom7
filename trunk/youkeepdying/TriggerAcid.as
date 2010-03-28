class TriggerAcid extends Trigger {
  public function activate() {
    // _root.cloud.play();
    _root.you.die('dissolved_linedrawing', {solid:false, warpto:'cavestart'});
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.anyhit(this);
  }

}
