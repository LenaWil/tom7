
/* a manipulable thing can be acted upon by
   sentences. */
class Manipulable extends Depthable {

  var showname : String;
  var eyeballverb : String;
  var handleverb : String;

  var description : String;

  /* which tool to use if we just click? */
  var defaulttool : Number;

  public function onPress () {
    var ph = _root["menubar"].phase;

    if (ph == 0) {

      _root["menubar"].reset ();

    } else if (ph == 1 || ph == 2) {
      var to = _root["menubar"].tool;

      if (to == 1) doeyeball ();
      else if (to == 2) dohandle ();
      else if (to == 3) dotalk ();
      /* other tools... */

      /* for phase 2 (default), don't reset
	 the tool/sentence because we are
	 still hovering over the object? 
	 (unless it was picked up or moved or
	 something, in which case it's even
	 weirder to keep the default) */
      /* if (ph != 2) */ _root["menubar"].reset ();
    } 
    /* subject verb object... */
  }

  public function dohandle () {
    _root["player"].say("Pure virtual function call.");
  }

  public function dotalk () {
    if (showname == undefined)
      _root["player"].say("I don't think it can hear me.");
    else _root["player"].say("Hello, " + showname + "!");
  }

  public function doeyeball () {
    if (description == undefined) {
      /* XXX probably should always have a description... */
      _root["player"].say("It's some kind of item.");
    } else {
      _root["player"].say(description);
    }
  }


  public function onRollOver() {
    var ph = _root["menubar"].phase;
    if (ph == 1) {
      /* picked tool, looking for subject */
      _root["menubar"].subject = this;
      _root["menubar"].updatesentence ();
    } else if (ph == 0 && defaulttool != undefined && defaulttool > 0) {
      /* mouse free; so temporarily set default action */
      _root["menubar"].phase = 2;
      _root["menubar"].tool = defaulttool;
      _root["menubar"].subject = this;
      _root["menubar"].updatesentence ();
    }
  }

  public function onRollOut () {
    /* conservatively, always update it */
    var ph = _root["menubar"].phase;
    if (ph == 0) {
      _root["menubar"].reset ();
    } else if (ph == 1) {
      /* don't lose tool here */
      _root["menubar"].subject = undefined;
      _root["menubar"].updatesentence ();
    } else if (ph == 2) {
      /* unset default tool */
      _root["menubar"].reset ();
    }

  }
}
