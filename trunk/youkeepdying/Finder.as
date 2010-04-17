
// Finders are like triggers, but they actively check
// conditions each frame (triggers are checked by
// the player, since only he can set them off).
class Finder extends MovieClip {

  public function onLoad() {
    /* for debuggin' */
    this._alpha = 15;
    /* should be invisible. */
    this._visible = false;

    if (!_root.finders) _root.finders = [];
    _root.finders.push(this);
  }

  // Override this. Called on an arbitrary physics object that's
  // triggering the finder, on every frame that the finder is
  // touched.
  public function activate(phys : PhysicsObject) {
  }

  // Called on every frame that the finder is not pressed.
  public function deactivate() {
  }

  // XXX This center-hit test is okay for small triggers (eg buttons)
  // but for large ones it won't work at all.
  public function isHit(phys : PhysicsObject, dx : Number, dy : Number) {
    var cx = this._x + this._width * .5;
    var cy = this._y + this._height * .5;
    return phys.hitTest(cx, cy, false);
  }

  var homeframe : Number = undefined;
  public function onEnterFrame() {
    // Don't run on the first frame, since objects
    // may not have moved themselves to the proper
    // position yet.
    if (homeframe == undefined) {
      homeframe = _root._currentframe;
    } else {
      // Me and the squares.
      if (isHit(_root.you, _root.you.dx, _root.you.dy)) {
        this.activate(_root.you);
        return;
      }

      for (var o in _root.squares) {
        var mc = _root.squares[o];
        if (isHit(mc, mc.dx, mc.dy)) {
          this.activate(mc);
          return;
        }
      }

      this.deactivate(mc);
    }
  }

}
