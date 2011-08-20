class Radar extends MovieClip {

  public static var WIDTH = 225;
  public static var HEIGHT = 175;
  
  var mask;
  var background = null;

  public function onLoad() {
    // XXX could create this with fillrect or something.
    // right now it has to be the same as the width/height constants
    // above...
    this.mask = this.createEmptyMovieClip('rm', 99997);

    this.mask._x = 0;
    this.mask._y = 0;

    this.mask.beginFill(0x7ABB30);
    this.mask.moveTo(0,0);
    this.mask.lineTo(0,HEIGHT);
    this.mask.lineTo(WIDTH,HEIGHT);
    this.mask.lineTo(WIDTH,0);
    this.mask.endFill();

    // this.attachMovie('radarmask', 'radarmask', 99997,
    // {_x: 0, _y: 0});
    this.setMask(this.mask);

    this.attachMovie('radarborder', 'radarborder', 10000,
                     {_x: 0, _y: 0});

    // Use this to set background colors.
    this['radarbg']._visible = false;
  }

  public function setBackground(hexcolor) {
    trace('radar.setbackground ' + hexcolor);
    if (this.background) {
      this.background.removeMovieClip();
    }
    this.background = this.createEmptyMovieClip('rm', 7000);
    this.background._x = 0;
    this.background._y = 0;

    this.background.beginFill(hexcolor);
    this.background.moveTo(0, 0);
    this.background.lineTo(0, HEIGHT);
    this.background.lineTo(WIDTH, HEIGHT);
    this.background.lineTo(WIDTH, 0);
    this.background.endFill();
  }

}
