class TriggerSpikes extends Trigger {
  public function activate() {
    _root.you.die('spikes', {solid:true});
  }
}
