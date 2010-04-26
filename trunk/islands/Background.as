class Background extends Positionable {

  var parallax = [];
  var clip : MovieClip;
  var island : MovieClip;

  public function destroy() {
    this._visible = false;
    this.swapDepths(0);
    this.removeMovieClip();
    _root.background = undefined;
  }

  public function onLoad() {
    this.setdepth(100);
    _root.background = this;
    this.gamex = 0;
    this.gamey = 0;

    var i = 1;
    for (var o in this) {
      trace(o);
      if (o.indexOf('parallax') == 0) {
        // XXX get depth from name
        parallax.push({ d : i ++, mc : this[o]});
      }
    }

  }

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
    }
  }

  public function hit(x : Number, y : Number /* mc : MovieClip */) {
    //    if (x < MINX || x > MAXX || y < MINY || y > MAXY) return true;
    // Basically just care about screen coordinates, assuming
    // everything is up to date.
    _root.viewport.place(this);
    return this.clip.hitTest(_root.viewport.placex(x), 
                             _root.viewport.placey(y), true);
  }

  public function hitland(x : Number, y : Number) {
    _root.viewport.place(this);
    return this.island.hitTest(_root.viewport.placex(x), 
                               _root.viewport.placey(y), true);
  }

  public function hitpart(part : MovieClip, x : Number, y : Number) {
    _root.viewport.place(this);
    return part.hitTest(_root.viewport.placex(x), 
                        _root.viewport.placey(y), true);
  }

}
