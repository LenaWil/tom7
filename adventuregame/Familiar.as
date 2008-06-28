
/* the player's familiar is a movieclip that follows him
   around, but is not scaled. */
class Familiar extends Depthable {

  var spoken : String;
  var speakframesleft : Number;

  public function onLoad() {
    /* position all sayboxes appropriately */
    
    var xx = this["saybox"]._x;
    var yy = this["saybox"]._y;

    this["sayboxl"]._x = xx - 2;
    this["sayboxr"]._x = xx + 2;
    this["sayboxl"]._y = yy;
    this["sayboxr"]._y = yy;

    this["sayboxul"]._x = xx - 2;
    this["sayboxur"]._x = xx + 2;
    this["sayboxul"]._y = yy - 2;
    this["sayboxur"]._y = yy - 2;

    this["sayboxu"]._y = yy - 2;
    this["sayboxd"]._y = yy + 2;
    this["sayboxu"]._x = xx;
    this["sayboxd"]._x = xx;

    this["sayboxdl"]._y = yy + 2;
    this["sayboxdr"]._y = yy + 2;
    this["sayboxdl"]._x = xx - 2;
    this["sayboxdr"]._x = xx + 2;

  }

  public function relocate() {
    
    /* XXX need to..
       - place appropriately so it doesn't seem to change
         distance from player when walking up/down
       - stretch saybox appropritely for short/long text
       - treat right side of screen too
       - not use baked-in constants
    */

    /* start centered */
    var xx = _root["player"]._x - (this["saybox"]._width / 2);

    /* getting near left edge? then snap to left edge. */
    if (_root["player"]._x < (this["saybox"]._width / 2))
      xx = 8;

    
    /* XXX determine this programatically... 
       _root._width is way too huge; huh??
    */
    var rootwidth = 550;

    /* right edge? */
    if ((xx + this["saybox"]._width) > rootwidth)
      xx = rootwidth - this["saybox"]._width;

    this._x = xx;

    /* the y coordinate is always based on the player's location */

    this._y = _root["player"]._y - (_root["player"].sizebox._height * _root["player"]._yscale / 125);

    if (this._y < 18) this._y = 18;
  }

  /* count down frames until the saybox
     is erased. */
  public function onEnterFrame() {
    if (speakframesleft > 0) {
      speakframesleft --;
      if (speakframesleft == 0) {
	/* PERF make invisible too? */
	spoken = "";
      }
    }
  }

}
