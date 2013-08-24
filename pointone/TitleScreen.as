import flash.display.*;
import flash.geom.Matrix;

class TitleScreen extends MovieClip {

  var titlemusic : Sound;

  // Count of frames that have passed
  var frames : Number = 0;
  // If >= 0, then we're starting the game, but fading out
  var starting : Number = -1;

  // fastmode!
  var FADEFRAMES = 10;
  var ALPHAMULT = 10;

  var FADEOUTFRAMES = 20;
  var ALPHAOUTMULT = 5;

  public function ascii(c : String) : Number {
    return 1 * c.charCodeAt(0);
  }

  var titlemc;

  public function onLoad() {
    Key.addListener(this);
    this._visible = false;

    var bm = BitmapData.loadBitmap('title.png');
    var titlebitmap : BitmapData = 
      new BitmapData(600, 700, false, 0x000000);
    var grow = new Matrix();
    grow.scale(2, 2);
    titlebitmap.draw(bm, grow);
    
    titlemc = _root.createEmptyMovieClip('titlemc', 999);
    titlemc.attachBitmap(titlebitmap, 1000);
    titlemc._alpha = 0;

    // title music!
    /*
    titlemusic = new Sound(this);
    titlemusic.attachSound('theme.mp3');
    titlemusic.setVolume(100);
    titlemusic.start(0, 99999);
    */
  }

  public function onEnterFrame() {
    // Fade in...
    frames++;
    if (frames < FADEFRAMES) {
      // titlemusic.setVolume(frames);

      if (frames < FADEFRAMES) {
	titlemc._alpha = frames * ALPHAMULT;
      }
     
    } else if (frames == FADEFRAMES) {
      titlemc._alpha = 100;
    } else {
      // Faded in. Might fade out...

      if (starting > 0) {
	var alpha = 100;
	if (_root['backgroundmusic']) {
	  titlemusic.setVolume(starting * ALPHAOUTMULT);
	}
	starting--;
	titlemc._alpha = starting * ALPHAOUTMULT;
	if (!starting) {
	  reallyStart();
	}
      }

    }
  }

  public function triggerStart() {
    // need to wait a while, fading out.
    starting = FADEOUTFRAMES;
  }

  public function onKeyDown() {
    var k = Key.getCode();

    if (Key.isDown(Key.CONTROL) &&
        Key.getAscii() == ascii('m')) {
      _root['musicenabled'] = !_root['musicenabled'];
      // say('music ' + (_root['musicenabled'] ? 'enabled' : 'disabled'));

      if (_root['musicenabled']) {
        titlemusic.setVolume(100);
      } else {
        titlemusic.setVolume(0);
      }

      return;
    }

    switch(k) {
    case Key.ENTER:
    case Key.SPACE:
      // _root['firstmusic'] = 'ballad';
      // _root['firstlevel'] = 'tutorial8';
      triggerStart();
      break;
    }
  }

  public function reallyStart() {
    Key.removeListener(this);
    trace('reallystart!');
    // Stop music!

    // this.titlemusic.stop();

    this.swapDepths(0);
    this.removeMovieClip();

    // Whole game takes place on this blank frame
    // in the root timeline.
    _root.gotoAndStop('game');

  }

};
