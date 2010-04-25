class Angleometer extends Depthable {
  public function onLoad() {
    this.setdepth(80001);
  }

  var needle : MovieClip;

  public function setDegs(d : Number) {
    this.needle._rotation = d;
  }

}
