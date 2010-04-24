class Airplane extends Positionable {
  
  var holdingUp = false;
  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;
  var holdingEsc = false;
  var blockEsc = false;
  var escKey = 'esc';

  var dy : Number = 0;

  public function onLoad() {
    Key.addListener(this);
    this.setdepth(1000);

    gamex = 20;
    gamey = 30;
  }

  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
    case 192: // ~
      escKey = '~';
      break;
    case 82: // r
      escKey = 'r';
      if (!blockEsc) holdingEsc = true;
      break;
    case 27: // esc
      escKey = 'esc';
      if (!blockEsc) holdingEsc = true;
      break;
    case 32: // space
    case 38: // up
      holdingUp = true;
      break;
    case 37: // left
      holdingLeft = true;
      break;
    case 39: // right
      holdingRight = true;
      break;
    case 40: // down
      holdingDown = true;
      break;
    }
  }

  public function onKeyUp() {
    var k = Key.getCode();
    switch(k) {
    case 192: // ~
    case 82: // r
    case 27: // esc
      holdingEsc = false;
      blockEsc = false;
      break;

    case 32:
    case 38:
      holdingUp = false;
      break;
    case 37:
      holdingLeft = false;
      break;
    case 39:
      holdingRight = false;
      break;
    case 40:
      holdingDown = false;
      break;
    }
  }

  public function onEnterFrame() {

    this.gamex += 15;
    this.gamey += dy;

    _root.viewport.setView(gamex - 50, gamey - 280);
    _root.viewport.place(this);
    _root.viewport.place(_root.background);

    var altitude = 1500 - this.gamey;
    _root.altimeter.setAltitude(altitude);

    this._rotation += 0.3;
    dy += .1;
    if (dy > 18) dy = 18;

    if (altitude <= 0) {
      _root.altimeter.removeMovieClip();
      _root.gotoAndStop('isntland');
    }

  }

}
