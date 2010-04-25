// Always present.
class MessageStripe extends Depthable {
  
  var message : TextField;
  var numbers : TextField;

  public function onLoad() {
    this._visible = false;
    message.text = '';
    numbers.text = '';
  }

  public function setmessage(s : String) {
    this.message.text = s;
  }

  public function setnumbers(s : String) {
    this.numbers.text = s;
  }

}
