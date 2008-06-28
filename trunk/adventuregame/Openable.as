
/* an object with two states, that
   transitions between them (or from
   one to the other only) by the
   handle action. The object keeps its
   state even when leaving the room. 
   This is usually used for openable
   doors.

   frames:
     0 : "closed" (default)
     1 : "open"

*/

class Openable extends StaticThing {

  var globalname : String;
  var opentext : String;
  var reacharea : String;

  var openverb : String;
  var closeverb : String;

  /* one-way transition, optional text */
  var cannotclose : Boolean;
  var noclosetext : String;

  public function onLoad () {
    super.onLoad();

    /* defaults */
    if (openverb == undefined)
      openverb = "open";
    if (closeverb == undefined)
      closeverb = "close";

    if (description == undefined)
      description = "It's a door.";
    if (eyeballverb == undefined)
      eyeballverb = "look at";
    if (showname == undefined)
      showname = "door";
    if (defaulttool == undefined)
      defaulttool = 2; /* hand */

    if (isopen()) {
      handleverb = closeverb;
      this.gotoAndStop(2);
    } else {
      handleverb = openverb;
      this.gotoAndStop(1);
    }
  }

  public function isopen() {
    return _root["memory"].getFlag(globalname);
  }

  /* stubs, for overriding */
  public function open () {}
  
  public function close () {}

  public function dohandle () {
    var m : MovieClip = _root[this.reacharea];

    if(m == undefined || _root["player"].anyhit(m)) {
      if (opentext == undefined) {
	/* by default say nothing.. */
      } else {
	/* only when opening */
	if (this._currentframe == 1) {
	  _root["player"].say(opentext);
	}
      }

      if (this._currentframe == 1) {
	_root["memory"].setFlag(this.globalname);
	handleverb = closeverb;
	this.gotoAndStop(2);
	open ();
      } else {
	if (this.cannotclose == undefined ||
	    !this.cannotclose) {
	  _root["memory"].clearFlag(this.globalname);
	  handleverb = openverb;
	  this.gotoAndStop(1);
	  close ();
	} else {
	  /* can't close! */
	  if (this.noclosetext != undefined) {
	    _root["player"].say(noclosetext);
	  }
	}
      }

    } else {
      _root["player"].say("I can't reach it from here.");
    }


  }

}
