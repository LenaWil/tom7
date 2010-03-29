class TriggerBeehive extends Trigger {
  public function activate() {
    // _root.cloud.play();
    // _root.message.say('YOU KEEP DYING');
    _root.you.ail('bees',
                  'bees',
                  12 * 25,
                  {solid:true, infectious:'once'});
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.anyhit(this);
  }

}
