class TriggerWords extends Trigger {
  public function activate() {
    _root.touchthesewords.gotoAndPlay('red');
    // doesn't really matter; shouldn't be visible
    _root.you.die('spikes', {solid:true});
  }

  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    trace('??');
    return phys.centerhit(this); // && dy > -1;
  }
}
