class Depthable extends flash.display.MovieClip {
  /* Puts movieclip at depth n, preserving the
     relative depth of all other clips. */
  public function setdepth(n : Number) {
    var target = n + 100;
    setdepthof(this, target);
  }

  public function setdepthof(m : MovieClip, n : Number) {
    var other : MovieClip = _root.getInstanceAtDepth(n);
    if (other == n) return;
    if (other != undefined) {
      setdepthof(other, n - 1);
    }
    m.swapDepths(n);
  }
}
