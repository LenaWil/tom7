class TriggerStar extends Trigger {
  public function activate() {
    _root.star.play();
    _root.you.die('blended', {false:true, floating:true});
  }

  // Have to be moving upward to die by star
  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return dy < 0 && phys.anyhit(this);
  }

}
