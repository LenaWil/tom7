
class Border extends Depthable {

  public function onLoad() {
    /* put above everything, also disconnects */
    this._alpha = 100;
    this.setdepth(99999);
  }

}
