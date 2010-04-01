class TriggerFallOff extends Trigger {
  public function activate() {
    _root.falloffthescreen.play();
    // doesn't really matter; shouldn't be visible
    _root.you.die('eaten', {solid:false, warpto:'paper2', floating:true,
	  wait:2 * 25});
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.centerhit(this);
  }
}
