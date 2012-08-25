import flash.display.*;
import flash.geom.Matrix;

class TitleScreen extends MovieClip {

  #include "constants.js"

  var titlemusic : Sound;

  // Count of frames that have passed
  var frames : Number = 0;
  // If >= 0, then we're starting the game, but fading out
  var starting : Number = -1;

  var titlebitmap;

  // var FADEFRAMES = 50;
  // var ALPHAMULT = 2;

  // fastmode!
  var FADEFRAMES = 10;
  var ALPHAMULT = 10;

  var FADEOUTFRAMES = 20;
  var ALPHAOUTMULT = 5;


  // XXX laserpointer!

  var titlelaser;
  public function onLoad() {
    Key.addListener(this);

    var bm = BitmapData.loadBitmap('titlescreen.png');
    var titlebitmap : BitmapData =
      new BitmapData(SCREENWIDTH, SCREENHEIGHT, false, 0x000000);
    var grow = new Matrix();
    grow.scale(2, 2);
    titlebitmap.draw(bm, grow);

    setframe(titlebitmap);

    // title music!
    // titlemusic = new Sound(this);
    // titlemusic.attachSound('dangerous.mp3');
    // titlemusic.setVolume(100);
    // titlemusic.start(0, 99999);

    this.swapDepths(BGIMAGEDEPTH);
  }

  public function setframe(which) {
    if (_root.titlemc) _root.titlemc.removeMovieClip();

    _root.titlemc = _root.createEmptyMovieClip('titlemc', BGIMAGEDEPTH);
    _root.titlemc.attachBitmap(which, BGIMAGEDEPTH);
  }

  public function onEnterFrame() {
    // Fade in...
    frames++;
    if (frames < FADEFRAMES) {
      // XXX titlemusic.setVolume(frames);
    }

    var alpha = 100;
    if (frames < FADEFRAMES) {
      alpha = frames * ALPHAMULT;
    }

    // Shouldn't add laser pointer until we're faded in?
    // (Or at least shouldn't start starting countdown
    // in laserpointer.)
    if (frames > FADEFRAMES) {
      if (starting > 0) {
        titlemusic.setVolume(starting * ALPHAOUTMULT);
        starting--;
        alpha = starting * ALPHAOUTMULT;
        if (!starting) {
          reallyStart();
        }
      }
    }

    _root.titlemc._alpha = alpha;
  }

  // Called from TitleLaser when it's been on the
  // start button long enough.
  public function triggerStart() {
    trace('did it');

    // need to wait a while, fading out.
    starting = FADEOUTFRAMES;
  }

  public function reallyStart() {
    Key.removeListener(this);
    trace('reallystart!');
    // Stop music!
    this.titlemusic.stop();

    _root.titlemc.removeMovieClip();
    _root.titlemc = undefined;

    // Don't need title screen any more, obviously
    this.removeMovieClip();
    // Also title laser pointer.
    titlelaser.removeMovieClip();

    // Whole game takes place on this blank frame
    // in the root timeline.
    _root.gotoAndStop('game');

    // _root.orange = _root.attachMovie('orange', 'orange', 1, {_x:210, _y:280});
    // no prefix for orange.
    // _root.orange.init(Cat.KIND_ORANGE);
    // _root.grey = _root.attachMovie('grey', 'grey', 2, {_x:315, _y:280});
    // _root.grey.init(Cat.KIND_GREY);

    // The laser pointer will be the actual controlling object.
    // _root.laser = _root.attachMovie('laser', 'laser', 3, {_x:50, _y:350});
    // _root.laser.init(_root.orange, _root.grey);


    // _root.world.gotoRoom('start');
    // _root.world.gotoRoom('glow');
    // _root.world.gotoRoom('forestlumpup');
    // _root.world.gotoRoom('mountain');
    // _root.world.gotoRoom('poolleft');
  }

  public function onKeyDown() {
    var k = Key.getCode();

    /*
    if (Key.isDown(Key.CONTROL) &&
        Key.getAscii() == ascii('m')) {
      _root['musicenabled'] = !_root['musicenabled'];

      if (_root['musicenabled']) {
        titlemusic.setVolume(100);
      } else {
        titlemusic.setVolume(0);
      }

      return;
    }
    */

    switch(k) {
    case Key.SPACE:
    case Key.ENTER:
      triggerStart();
      break;
    }
  }

};
