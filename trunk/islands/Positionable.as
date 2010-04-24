/*
  The coordinate system of the game (one large playing surface) is
  not the same as the screen coordinate system, which is just a
  viewport into it. It'd be nice to have support for that in Flash,
  but it isn't there (or: I'm sure it is but I don't know how.)
  Instead, we keep track of objects that are in game coordinates
  as "Positionable". These things know how to move themselves to
  the right screen coordinates (possibly off the screen).
 */
class Positionable extends Depthable {

  // Game coordinates.
  var gamex : Number;
  var gamey : Number;

  public function setPos() {
    
  }

}
