class ElectricGate extends Depthable {
  var active = true;

  public function onLoad() {
    // In front of player but behind foreground objects.
    this.setdepth(8000);
    if (!_root.deleteme)
      _root.deleteme = [];
    _root.deleteme.push(this);

    if (active) {
      this.gotoAndPlay('on');
    } else {
      this.gotoAndPlay('off');
    }
  }

  public function setState(newact) {
    // trace('setstate ' + newact);
    if (newact && !active) {
      this.gotoAndPlay('goingon');
    } else if (!newact && active) {
      this.gotoAndPlay('goingoff');
    }
    active = newact;
  }
}
