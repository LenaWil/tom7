class MrSpidey extends Monster {
  public function activate() {
    // XXX not good
    _root.you.die('evaporate', {solid:false});
  }

  var timer : Number = 20;
  var godir;
  public function onLoad() {
    godir = true;
    super.onLoad();
  }

  public function onEnterFrame() {
    movePhysics();

    if ((godir && this.collision_right) ||
        (!godir && this.collision_left)) {
      this.collision_right =
        this.collision_left = false;
      godir = !godir;
    }

    if (ontheground()) {
      this.gotoAndStop('onground');
    } else {
      this.gotoAndStop('inair');
    }
  }

  // Using fact that this is only called when
  // we're on the ground.
  public function wishjump() {
    timer--;
    if (timer <= 0) {
      timer = 20;
      return true;
    } else {
      return false;
    }
  }

  public function wishright() {
    return godir;
  }

  public function wishleft() {
    return !godir;
  }

}
