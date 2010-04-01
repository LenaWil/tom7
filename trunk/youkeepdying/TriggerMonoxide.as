class TriggerMonoxide extends Trigger {

  public function activate() {
    // _root.cloud.play();
    _root.you.ail('carbon monoxide',
                  'spikes',
                  6 * 25,
                  {solid:false, floating:true});
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    return phys.anyhit(this);
  }

}
