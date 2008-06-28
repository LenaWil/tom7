
class Gettable extends Manipulable {

  var reacharea : String;
  var globalname : String;
  var gottext : String;

  public function onLoad () {
    super.onLoad();

    /* default tool is still look; since getting things
       is fun, we can make people do a little work */
    if (defaulttool == undefined) defaulttool = 1;

    if (handleverb == undefined) handleverb = "get";

    /* remember if already "gotten" and then
       don't appear */
    if (_root["memory"].getFlag(globalname)) {
      // trace("already have gettable");
      this.swapDepths(0);
      this.removeMovieClip();
    } 
  }

  public function dohandle () {
    /* can the player reach it from where he is? */

    var m : MovieClip = _root[this["reacharea"]];

    if(m == undefined || _root["player"].anyhit(m)) {
      if (gottext == undefined) {
	_root["player"].say("Let's inventory!");
      } else {
	_root["player"].say(gottext);
      }

       _root["memory"].setFlag(globalname);
      this.swapDepths(0);
      this.removeMovieClip();
    } else {
      _root["player"].say("I can't reach it from here.");
    }
  }
  

}
