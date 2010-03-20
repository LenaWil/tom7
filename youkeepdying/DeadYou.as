class DeadYou extends PhysicsObject {

  var homeframe : Number;

  var floating;
  var solid;

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
    
    homeframe = _root._currentframe;
  }
}
