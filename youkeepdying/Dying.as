class Dying extends Monster {
  public function activate() {
    if (dy > 4) {
      _root.you.die('blended', {solid:false});
    }
  }

  public function defaultconstants() {
    var c = super.defaultconstants();
    c.gravity = 2.0;
    c.terminal_velocity = 12.0;
    return c;
  }

  var hanging = true;
  public function onLoad() {
    super.onLoad();
  }

  public function fall() {
    hanging = false;
  }

  public function onEnterFrame() {
    if (hanging)
      return;

    movePhysics();
  }

}
