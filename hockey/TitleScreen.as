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
    titlemusic = new Sound(this);
    titlemusic.attachSound('themesong.mp3');
    titlemusic.setVolume(100);
    titlemusic.start(0, 99999);

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
      titlemusic.setVolume(frames * 10);
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

    // Whole game takes place on this blank frame
    // in the root timeline.
    _root.gotoAndStop('game');

    _root.you = _root.attachMovie('you', 'you', YOUDEPTH,
                                  { _x:SCREENWIDTH/2,
                                    _y:SCREENHEIGHT/2 });
    _root.you.init();

    /*
    _root.world = _root.attachMovie('world', 'world', WORLDDEPTH,
                                    { _x: 0, _y: 0 });
    _root.world.init();
    */
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
