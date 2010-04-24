class Crab extends Positionable {

  var dx : Number = 0;
  var dy : Number = 0;
  
  public function onLoad() {
    this.setdepth(900);
  }
  
  
  public function onEnterFrame() {
    this.dy += 0.1;
    
    this.gamex += this.dx;
    this.gamey += this.dy;

    this._rotation += 10;

    if (this.dy > 12) this.dy = 12;
    if (this.dy < -12) this.dy = -12;
    if (this.dx > 12) this.dx = 12;
    if (this.dx < -12) this.dx = -12;

    //    trace(this.gamex + ' ' + this.gamey);

    _root.viewport.place(this);
  }

}
