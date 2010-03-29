class DeadYou extends PhysicsObject {

  var homeframe : Number;

  var floating;
  var solid;
  var dfade = 0;

  var width = 64.65;
  var height = 43.75;

  var ailment : Object = undefined;

  // Called from last frame of animation, if
  // we want to detach immediately.
  public function bye() {
    stop();
    destroy();
  }

  // Called from last frame of animation, if
  // we want to stick around indefinitely.
  public function stay() {
    stop();
  }

  public function onEnterFrame() {
    // If we changed off the frame on which
    // this body was born, destroy.
    if (_root._currentframe != homeframe) {
      destroy();
      return;
    }

    if (!floating) {
      movePhysics();
    }

    if (this.ailment) {
      // no timers or anything on infectious
      // ailments for now...
      this.ailment.mc._x = this._x;
      this.ailment.mc._y = this._y;
    }

    if (dfade) {
      this._alpha -= dfade;
    }
  }

  public function fade(f) {
    dfade = f;
  }

  public function destroy() {
    // Remove us from solid squares; we should only
    // be there if solid is true, but harmless to
    // do it unconditionally...
    for (var i = 0; i < _root.squares.length; i++) {
      var b = _root.squares[i];
      if (b == this) {
        _root.squares.splice(i, 1);
        break;
      }
    }
    this.swapDepths(0);
    this.removeMovieClip();
  }

  // This must be called before the object's first frame!
  public function init(shouldfloat, issolid) {
    floating = shouldfloat;
    solid = issolid;

    if (floating) {
      dx = 0;
      dy = 0;
    }

    if (solid) {
      if (_root.squares == undefined)
        _root.squares = [];
      _root.squares.push(this);
    }

    // Ensure deletion when exiting board.
    if (!_root.deleteme) _root.deleteme = [];
    _root.deleteme.push_back(this);
    
    homeframe = _root._currentframe;
  }
}
