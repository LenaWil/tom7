
class World extends MovieClip {
  
  var grid = [];
  
  var ball;
  var extent;
  var dx;
  var dy;

  public function onLoad() {
    ball = this['ball'];
    extent = this['extent'];
    dx = 1;
    dy = -1;
  }
  
  public function onEnterFrame() {
    // update ball position.
    ball._x += dx;
    ball._y += dy;

    // trace(ball._x + ' ' + ball._y);

    if (false)
    trace(ball._x + ' ' + ball._y + ': ' + 
	  this._height + ' ' + this._width);

    if (ball._y < 0) {
      ball._y = 0;
      dy = -dy;
    }
    if (ball._y > extent._height) {
      ball._y = extent._height;
      dy = -dy;
    }
    if (ball._x < 0) {
      ball._x = 0;
      dx = -dx;
    }
    if (ball._x > extent._width) {
      ball._x = extent._width;
      dx = -dx;
    }

    for(var o in this) {
      if (o != 'ball' && o != 'extent' && this[o].isblock) {
	// collide?
	var block = this[o];
	if (ball._x >= block._x &&
	    ball._y >= block._y &&
	    ball._x <= (block._x + block._width) &&
	    ball._y <= (block._y + block._height)) {
	  block.isblock = false;
	  block._visible = false;
	  dx = -dx;
	  dy = -dy;
	}
      }
    }

  }

}
