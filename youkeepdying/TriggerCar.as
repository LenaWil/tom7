class TriggerCar extends Trigger {
  public function activate() {
    _root.car.play();
    _root.you.die('splatscreen');
  }
}
