
class LaserPointer extends MovieClip {

  var usetime : Number;
  var startframe : Number;

  public function onKeyDown() {
    var k = Key.getCode();
    /* letter p should toggle big mouse.. */
  }

  public function onMouseMove() {
    // these coordinates are relative to the current movieclip position
    this._x += _xmouse;
    this._y += _ymouse;
    this._alpha = 100;
    this._visible = true;
    usetime = 100;
    startframe = _root._currentFrame;
    // trace(_xmouse + " " + _ymouse);
    // updateAfterEvent();
  }

  public function onEnterFrame () {
    if (usetime > 0) {
      /* when leaving the frame, assume we want the mouse to fade out now */
      if (_root._currentFrame != startframe && usetime > 20) {
	// trace(_root._currentFrame + " =/= " + startframe);
	usetime = 20;
      }
      usetime --;
      if (usetime < 20) this._alpha = usetime * 5;
    } else {
      this._visible = false;
    }
  }

  public function onLoad() {

    /* don't lookat me by default. */
    this._visible = false;
    usetime = 0;
    startframe = _root._currentFrame;
    Key.addListener(this);
    Mouse.addListener(this);
    Mouse.hide();
  }

}
