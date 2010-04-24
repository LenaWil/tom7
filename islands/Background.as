// Should probably be special (do parallax)
class Background extends Positionable {

  var parallax = [];

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
      }
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

      mc._x = pctoffx * (parallax[i].d * .1) * this._width;
      mc._y = pctoffy * (parallax[i].d * .1) * this._height;
      // trace(mc + ' ' + pctoffx + ' ' + pctoffy + ' ## ' + mc._x + ' ' + mc._y);
    }
  }

}
