class SecurityBot extends Monster {
  public function activate() {
    _root.you.die('evaporate');
  }

  public function onEnterFrame() {
    movePhysics();
  }

  // XXX
  public function wishright() {
    return true;
  }

}
