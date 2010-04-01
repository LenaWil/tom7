// nb. class name "Button" is taken by AS2.0
class ButtonAnim extends Depthable {
  var pressed = false;

  public function onLoad() {
    // Behind player, items, dead bodies
    this.setdepth(1200);
    if (!_root.deleteme)
      _root.deleteme = [];
    _root.deleteme.push(this);

    if (pressed) {
      this.gotoAndPlay('down');
    } else {
      this.gotoAndPlay('up');
    }
  }

  public function setPressed(newpress) {
    // trace('setstate ' + newact);
    /* (no anims yet)
    if (newact && !down) {
      this.gotoAndPlay('goingon');
    } else if (!down && active) {
      this.gotoAndPlay('goingoff');
    }
    */
    pressed = newpress;
    if (pressed) {
      this.gotoAndPlay('down');
    } else {
      this.gotoAndPlay('up');
    } 
  }
}
