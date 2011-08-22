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
          this[o] instanceof Exit ||
          this[o] instanceof Repulsor) {
        this[o]._visible = false;
      }
    }
  }
}
