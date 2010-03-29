class TriggerHeadSpike extends Trigger {
  public function activate() {
    // _root.cloud.play();
    // _root.message.say('YOU KEEP DYING');
    _root.you.ail('bleeding',
                  'spikes',
                  6 * 25,
                  {solid:true});
  }

  // Have to be moving upward to cause bleeding damage
  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return dy < 0 && phys.anyhit(this);
  }

}
