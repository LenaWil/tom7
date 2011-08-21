class Fish extends MovieClip {

  /*
  public var borders = [];
  public var exits = [];
  */

  var ctr = 0;

  // Hides its internal geometry, copying it into
  // state.
  public function onLoad() {
    // trace('fish onload');

    for (var o in this) {
      // trace(o);
      if (this[o] instanceof Solid ||
          this[o] instanceof Exit) {
        this[o]._visible = false;
      }
    }
  }


    /*
    if (this.borders.length > 0) {
      trace('onload (' + this + ', borders has shit in it already');
    }

    this.borders.splice(0, this.borders.length);
    this.exits.clear(0, this.borders.length);
    // this._alpha = 50;
    // Do unnamed instances show up?
    for (var o in this) {
      // trace(o);
      if (this[o] instanceof Solid) {
        var mc = this[o];

        // trace('found solid');

        // Because it's 100 units wide, and scale is
        // in percentage.
        var w = mc._xscale;
        var rrad = (mc._rotation / 360.0) * 2.0 * Math.PI;
        var x0 = mc._x;
        var y0 = mc._y;
        var x1 = x0 + Math.cos(rrad) * w;
        var y1 = y0 + Math.sin(rrad) * w;

        // trace(x0 + ' ' + y0 + ' ' + x1 + ' ' + y1);
        this.borders.push({x0 : x0, y0 : y0, x1 : x1, y1 : y1,
              w : w, rrad : rrad });
        // XXX how come I can't actually remove it?
        mc._visible = false;

          // XXX draw lines instead.
//        ctr++;
//         this.attachMovie("star", "star" + ctr, 8000 + ctr,
//                          {_x: x0, _y: y0});
// 
//         ctr++;
// 
//         this.attachMovie("star", "star" + ctr, 8000 + ctr,
//                          {_x: x1, _y: y1});

      } else if (this[o] instanceof Exit) {
        var mc = this[o];
        // Assuming these are axis aligned with the registration
        // in the top-left corner.
        this.exits.push({x0: mc._x, y0: mc._y,
              x1: mc._x + mc._xscale,
              y1: mc._y + mc._yscale});
        mc._visible = false;
      }
    }
*/
  //   }
}
