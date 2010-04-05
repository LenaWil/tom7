// Always present.
class ResetMessage extends Depthable {
  
  var msg : TextField;

  public function onLoad() {
    this._visible = false;
  }

  public function setmessage(s : String) {
    this.msg.text = s;
  }

}
