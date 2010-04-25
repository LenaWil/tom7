class Magmafield extends Depthable {
  var MAXBALLS = 10;
  var nballs = 0;
  
  public function onLoad() {
    this._visible = false;
  }

  var which : Number = 0;
  public function onEnterFrame() {
    // XXX on leaving frame, kill all ballz
    if (nballs < MAXBALLS && Math.random() < 0.1) {
      which++;
      which %= 2;

      var idx = _root.global.decorationidx();
      if (idx != undefined) {
	nballs++;
	var ball =
	  _parent.attachMovie("magmaball" + (which + 1), "magmaballs" + idx, 
			      _root.global.FIRSTDECORATION + idx, {
			      par: this,
			      idx: idx,
			      _rotation: Math.random() * 360,
			      _x: this._x + Math.random() * this._width, 
			      _y:this._y + Math.random() * this._height});
      }
    }
  }

  public function kill(mc: Magmaball) {
    _root.global.giveup(mc.idx);
    nballs--;
    _parent.removeMovieClip(mc);
  }

}
