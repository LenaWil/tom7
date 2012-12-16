import flash.display.*;
import flash.geom.Matrix;

class TitleScreen extends MovieClip {

  #include "constants.js"
  #include "util.js"

  var titlemusic : Sound;

  // Count of frames that have passed
  var frames : Number = 0;
  // If >= 0, then we're starting the game, but fading out
  var starting : Number = -1;

  var titlebitmap;
  var selectedbitmap;

  // fastmode!
  var FADEFRAMES = FASTMODE ? 1 : 10;
  var FADEOUTFRAMES = FASTMODE ? 1 : 10;

  var selection = 0;

  public function onLoad() {
    Key.addListener(this);

    trace('title onload');

    titlebitmap = loadBitmap3x('title.png');
    selectedbitmap = loadBitmap3x('selected.png');

    trace('hi');

    setframe(titlebitmap);
    moveSelection(false);
    // title music!
    if (MUSIC) {
      titlemusic = new Sound(this);
      titlemusic.attachSound('unlucky.wav');
      titlemusic.setVolume(100);
      titlemusic.start(0, 99999);
      trace('started title music');
    }

    // this.swapDepths(BGIMAGEDEPTH);
  }

  public function moveSelection(playsound) {
    if (_root.selmc) _root.selmc.removeMovieClip();

    _root.selmc = _root.createEmptyMovieClip('selmc', TITLESELDEPTH);
    _root.selmc.attachBitmap(selectedbitmap, TITLESELDEPTH);

    _root.selmc._x = TITLESELX;
    _root.selmc._y = TITLESELY + TITLESELHEIGHT * selection;

    if (playsound) {
      var sound = new Sound(this);
      sound.attachSound('menuchange.wav');
      sound.setVolume(60);
      sound.start(0, 1);
    }
  }

  public function setframe(which) {
    if (_root.titlemc) _root.titlemc.removeMovieClip();

    _root.titlemc = _root.createEmptyMovieClip('titlemc', BGIMAGEDEPTH);
    _root.titlemc.attachBitmap(which, BGIMAGEDEPTH);
  }

  public function onEnterFrame() {
    // This game is going for 8 bit realism, so
    // the "fade in" is just blank.

    // Fade in...
    frames++;
    if (frames < FADEFRAMES) {
      _root.titlemc._alpha = 0;

    } else {
      if (starting > 0) {
        starting--;

        if (!starting) {
          reallyStart();
        }
        _root.titlemc._alpha = 0;
      } else {
        _root.titlemc._alpha = 100;
      }
    }
  }

  // Called from TitleLaser when it's been on the
  // start button long enough.
  public function triggerStart() {
    trace('did it');

    // need to wait a while, fading out.
    starting = FADEOUTFRAMES;

    var sound = new Sound(this);
    sound.attachSound('menuchoose.wav');
    sound.setVolume(60);
    sound.start(0, 1);
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
    case 38: // up
      selection--;
      if (selection < 0) selection = 2;
      moveSelection(true);
      break;

    case 40: // down
      selection = (selection + 1) % 3;
      moveSelection(true);
      break;

    case Key.SPACE:
    case Key.ENTER:
      triggerStart();
      break;
    }
  }

  public function reallyStart() {
    Key.removeListener(this);
    trace('reallystart!');
    // Stop music!
    this.titlemusic.stop();

    _root.titlemc.removeMovieClip();
    _root.titlemc = undefined;

    _root.selmc.removeMovieClip();
    _root.selmc = undefined;

    _root['menuselection'] = selection;

    // Don't need title screen any more, obviously
    this.removeMovieClip();

    // Whole game takes place on this blank frame
    // in the root timeline.
    _root.gotoAndStop('game');

    _root.hockey = _root.attachMovie('hockey', 'hockey', 0);
    _root.hockey.init();
  }

};
