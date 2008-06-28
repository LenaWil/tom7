
/* A lookable thing is primarily meant to be
   looked at, so any other action fails with
   a message. */

class Lookable extends StaticThing {

  var canthandle;
  
  public function onLoad () {
    super.onLoad();

    /* only for looking, so set default tool */
    if (defaulttool == undefined) defaulttool = 1;

    if (canthandle == undefined) 
      canthandle = "I don't think that will do anything.";

    /* ?? XXX talk */
    if (handleverb == undefined) handleverb = "touch";
  }

  public function dohandle () {
    _root["player"].say(canthandle);
  }
  

}
