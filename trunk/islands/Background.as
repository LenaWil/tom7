// Should probably be special (do parallax)
class Background extends Positionable {

  var parallax = [];
  //  var fixed = [];
  var clip : MovieClip;

  public function onLoad() {
    this.setdepth(100);
    this.gamex = 0;
    this.gamey = 0;

    var i = 1;
    for (var o in this) {
      trace(o);
      if (o.indexOf('parallax') == 0) {
        // XXX get from name
        parallax.push({ d : i ++, mc : this[o]});
        //        this[o]._alpha = 10;
      } /* else if (o.indexOf('fixed') == 0) {
        fixed.push({ x : this[o]._x, y : this[o]._y, mc : this[o]});
        } */
    }
  }

  // NO : // Compute parallax in terms of real _x values.  
  public function onEnterFrame() {
    var cx = this._width / 2;
    var cy = this._height / 2;
    for (var i = 0; i < parallax.length; i++) {
      var mc = parallax[i].mc;

      // How far we are off the center. If +1, then we are all the way
      // to the edge of the background to the right, if -1 then to
      // the left. 0 is center.
      var pctoffx = (_root.viewport.gamex - cx) / cx;
      var pctoffy = (_root.viewport.gamey - cy) / cy;

      mc._x = pctoffx * (parallax[i].d * .05) * this._width;
      mc._y = pctoffy * (parallax[i].d * .05) * this._height;
      // trace(mc + ' ' + pctoffx + ' ' + pctoffy + ' ## ' + mc._x + ' ' + mc._y);
    }

    /*
    for (var i = 0; i < fixed.length; i++) {
      var f = fixed[i];
      _root.viewport.unplace(this, f, 0, 0);
    }
    */
  }

  public function hit(x : Number, y : Number /* mc : MovieClip */) {
    // Basically just care about screen coordinates, assuming
    // everything is up to date.
    _root.viewport.place(this);
    return this.clip.hitTest(x, y, true);
  }

}
