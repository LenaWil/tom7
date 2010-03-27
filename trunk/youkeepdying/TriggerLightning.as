class TriggerLightning extends Trigger {
  public function activate() {
    _root.cloud.play();
    _root.you.die('evaporate', {solid:false});
  }
}
