class TriggerElectricFence extends Trigger {
  public function activate() {
    _root.fencezap.play();
    _root.you.die('evaporate', {floating: true, solid: false});
  }
}
