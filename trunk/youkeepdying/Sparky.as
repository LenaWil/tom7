class Sparky extends Monster {
  public function activate() {
    // XXX not good
    _root.you.die('evaporate', {solid:false});
  }

  // var timer : Number = 20;
  var ydir;
  public function onLoad() {
    ydir = true;
    super.onLoad();
  }

  public function setVelocity(C) {
    if (ydir) this.dy = 9.8;
    else this.dy = -9.8;
    this.dx = 0;
  }

  public function onEnterFrame() {
    movePhysics();

    if ((ydir && this.collision_down) ||
        (!ydir && this.collision_up)) {
      this.collision_up =
        this.collision_down = false;
      ydir = !ydir;
    }

    // this._rotation++;
  }

}
