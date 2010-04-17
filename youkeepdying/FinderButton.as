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
    if (button != undefined) {
      _root[button].setPressed(true);
    }
  }

  public function deactivate() {
    if (gatetrigger != undefined)
      _root[gatetrigger].enabled = true;
    if (gate != undefined) {
      _root[gate].setState(true);
    }
    if (button != undefined) {
      _root[button].setPressed(false);
    }
  }

}
