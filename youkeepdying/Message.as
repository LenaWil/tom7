// Always present.
class Message extends Depthable {
  
  var ticksleft : Number;

  var msg : TextField;

  public function say(s : String) {
    // trace(s);
    this._visible = true;
    this.msg.text = s;
    // 1600ms
    ticksleft = 45;
  }

  public function onEnterFrame() {
    if (ticksleft > 0) {
      ticksleft--;
      if (ticksleft == 0) {
        this.msg.text = '';
        this._visible = false;
      }
    }
  }

}
