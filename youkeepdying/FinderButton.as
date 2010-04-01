
class FinderButton extends Finder {
  // The name of the Button movieclip, 
  // which animates along with the trigger.
  var button : String;

  // The name of the gate movieclip, which
  // animates too.
  var gate : String;

  // The name of the gate (death) trigger,
  // which we turn on and off.
  var gatetrigger : String;

  // Since buttons open (and in that sense
  // disable) gates, the sense of "activate"
  // may seem backwards.
  public function activate(p) {
    if (gatetrigger != undefined)
      _root[gatetrigger].enabled = false;
    if (gate != undefined)
      _root[gate].setState(false);
    // XXX button anim.
  }

  public function deactivate() {
    if (gatetrigger != undefined)
      _root[gatetrigger].enabled = true;
    if (gate != undefined) {
      _root[gate].setState(true);
    }
    // XXX button anim.
  }

}
