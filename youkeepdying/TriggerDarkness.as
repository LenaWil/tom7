class TriggerDarkness extends Trigger {
  public function activate() {
    _root.darkness.play();
    _root.you.die('eaten', {solid:false, floating:true});
  }
}
