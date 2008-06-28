
class Menubar extends Depthable {

  var defaultverb = ["error", "eyeball", "handle", "talk to"];

  /* Which tool is currently selected?
     0 : nothing
     1 : eyeball
     2 : handle
  */
  var tool : Number;

  /* How far are we in making a sentence?
     0 : nothing         (subject,object = undef)
     1 : picked a tool   (subject,object = undef)
     2 : hovering default action  (tool, subject set)
  */
  var phase : Number;

  
  var subject : MovieClip;
  var object  : MovieClip;

  /* This is displayed in the bottom of the
     menu bar, to explain the current action. */
  var sentence : String;

  public function onLoad() {
    /* somewhat translucent */
    // this._alpha = 60;
    /* put at menu height */
    this.setdepth(99500);
    reset ();
  }

  public function reset () {
    phase = 0;
    tool = undefined;
    subject = undefined;
    object = undefined;
    updatesentence (undefined);
  }

  public function getverb(su : Object) {
    var verb;
    if (su != undefined) {
     if (tool == 1) verb = su.eyeballverb;
     if (tool == 2) verb = su.handleverb;
    }

    /* but if it wasn't set, go to default */
    if (verb == undefined) verb = defaultverb[tool];
    return verb;
  }

  public function updatesentence() {
    if (tool == undefined) {
      sentence = "(nothing)";
    } else {
      if (phase == 0) {
	/* we have a tool, but haven't clicked it.
	   in this case we have to use the default verb. */
	sentence = defaultverb[tool];
      } else if (phase == 1 || phase == 2) {
	/* clicked a tool, or hovering for
	   default action. */
	
	if (subject == undefined) {
	  /* haven't moused over any subject, so
	     we have to use the default verb */
	  sentence = defaultverb[tool];
	} else {
	  /* mousing over something, so use its
	     custom verb and its name */
	  
	  var verb = getverb(subject);

	  if (subject.showname == undefined) {
	    sentence = verb + " that thing";
	  } else {
	    sentence = verb + " " + subject.showname;
	  }

	}
      }
    }

    sentence = phase + " : " + sentence;

    if (sentence.length > 16) {
      var small : TextFormat = new TextFormat ();
      small.size = 12;
      this["display_sentence"].setTextFormat(undefined, undefined, small);
      sentence = sentence + " (long)";
      this["display_sentence"].alpha = 20;
    }
    this["display_sentence"].text = sentence;
    
  }

}
