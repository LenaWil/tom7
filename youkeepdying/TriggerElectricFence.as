class TriggerElectricFence extends Trigger {
  public function activate() {
    _root.you.die('evaporate');
  }
}
