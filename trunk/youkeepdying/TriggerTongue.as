class TriggerTongue extends Trigger {
  public function activate() {
    _root.friend.play();
    _root.you.die('eaten', {solid:false, warpto:'stomach', floating:true});
    // Would be nice to kill umbrella too, after two frames.
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.centerhit(this) && phys.hasUmbrella();
  }
}
