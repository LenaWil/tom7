
/* a movieclip with a 'setdepth' function */
class Depthable extends MovieClip {

  /* puts the movieclip at depth n, preserving the
     relative depth of all other clips. */
  public function setdepth(n : Number) {
    var target = n + 100;
    setdepthof(this, target);
  }

  public function setdepthof(m : MovieClip, n : Number) {
   
    /* see if there is something there. */
    var other : MovieClip = _root.getInstanceAtDepth(n);
    // trace("setdepth " + m + " to: " + n);
    /* don't swap with self, duh */
    if(other == m) return;

    if(other != undefined) {
      // trace("cascaded @ " + n + " because " + other);
      setdepthof(other, n - 1);
    }
    m.swapDepths(n);
  }

}
