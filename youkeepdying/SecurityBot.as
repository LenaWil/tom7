class SecurityBot extends Monster {
  public function activate() {
    _root.you.die('evaporate', {solid:false});
  }

  var godir;
  var startx : Number;
  public function onLoad() {
    startx = this._x;
    godir = true;
    super.onLoad();
  }

  public function onEnterFrame() {
    movePhysics();

    if ((godir && this.collision_right) ||
        (!godir && this.collision_left) ||
        (godir && !this.rightfootonground()) ||
        (!godir && !this.leftfootonground())) {
      this.collision_right =
        this.collision_left = false;
      godir = !godir;
    }
  }


  public function wishright() {
    return godir;
  }

  public function wishleft() {
    return !godir;
  }

}
