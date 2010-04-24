// The viewport just tells us what part of the game we're looking at.

class Viewport {

  var width : Number = 800;
  var height : Number = 600;

  // Top-left of viewport, in game
  // coordinates.
  var gamex : Number = 0;
  var gamey : Number = 0;

  public function setView(x : Number, y : Number) {
    gamex = x;
    gamey = y;
  }

  /*
  public function transx(x : Number) {
    return x - gamex;
  }

  public function transy(y : Number) {
    return y - gamey;
  }
  */

  public function place(obj : Positionable) {
    obj._x = obj.gamex - gamex;
    obj._y = obj.gamey - gamey;
  }
  

}
