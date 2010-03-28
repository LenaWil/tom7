class TriggerFan extends Trigger {
  public function activate() {
    _root.fan.gotoAndPlay('bleeding');
    _root.you.die('blended', {solid:false});
  }
}
