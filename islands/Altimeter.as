class Altimeter extends Depthable {
  public function onLoad() {
    this.setdepth(80000);
  }

  var msg : TextField;

  public function setAltitude(a : Number) {
    this.msg.text = '' + a;
  }

}
