
/* XXXX need to support comment colors! */
import flash.geom.*;

class Bonus extends MovieClip {

  var oldframe : Number;

  public function onKeyDown() {
    var k = Key.getCode();

    var now = _root._currentFrame;

    /* letter b */
    if (k == 66) {
      _root.gotoAndStop("bonus");
      if (now == _root._currentFrame) {
	/* already on bonus frame. go back. */
	if (oldframe != undefined) _root.gotoAndStop(oldframe);
      } else {
	/* save old frame */
	oldframe = now;
      }
    }
  }

  public function onLoad() {

    /* don't lookat me by default. */
    this._visible = false;
    Key.addListener(this);
  }

}
