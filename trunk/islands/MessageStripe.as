// Always present.
class MessageStripe extends Depthable {
  
  var message : TextField;
  var numbers : TextField;

  var timeleft : Number = 0;

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

  public function displayfor(n : Number) {
    this._visible = true;
    this.timeleft = n;
  }

  public function onEnterFrame() {
    if (timeleft > 0) {
      timeleft--;
      if (timeleft == 0)
	this._visible = false;
    }
  }

}
