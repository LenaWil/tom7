class TriggerRewarp extends Trigger {
  public function activate() {
    _root.you.die('dissolved_linedrawing', 
		  { solid:false, 
		    warpto:_root.you.resetframe, 
		    floating:true });
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.centerhit(this);
  }
}
