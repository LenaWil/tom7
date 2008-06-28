
class Action extends Depthable {

  var toolnum;

  /* XXX when hovering, animate it */

  /* animate click, too */
  public function onPress () {
     if (toolnum == 0 || toolnum == undefined) {
	trace("Tool doesn't have a number!");
     }
     _root["menubar"].tool = toolnum;
     _root["menubar"].subject = undefined;
     _root["menubar"].object = undefined;
     _root["menubar"].phase = 1; /* got tool */

     _root["menubar"].updatesentence();
  }

  public function onRollOver () {
     /* if we have nothing selected, then hovering
        can preview */
     if (_root["menubar"].phase == 0) {
	_root["menubar"].tool = toolnum;
	_root["menubar"].updatesentence ();
     }
  }

  public function onRollOut () {
    if (_root["menubar"].phase == 0) {
      _root["menubar"].tool = undefined;
      _root["menubar"].updatesentence ();
    }
  }

}
