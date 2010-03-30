
class MovingSpawn extends Spawn {

  var minx : Number;
  var maxx : Number;

  public function onLoad() {
    // behind player
    // this.setdepth(2000);
    this._visible = false;
    onEnterFrame();
  }

  var goright = true;
  public function onEnterFrame() {
    super.onEnterFrame();
    
    if (this.goright) {
      this.dx = 5;
      this._x += 5;
      if (this._x > this.maxx) {
	this._x = this.maxx;
	this.goright = false;
      }
    } else {
      this.dx = -5;
      this._x -= 5;
      if (this._x < this.minx) {
	this._x = this.minx;
	this.goright = true;
      }
    }
  }

}
