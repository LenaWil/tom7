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

    System.security.loadPolicyFile('http://spacebar.org/policy.xml');

    // To make this work I needed to make a policy (above) that allowed
    // everything (probably can be much more lenient). I also had to
    // change the publish settings to allow network access from local
    // disk, as opposed to file access.

    /*
    _root['message'].text = 'get xml...';
    var my_xml:XML = new XML();
    my_xml.onLoad = function() {
      _root['message'].text = 'Done: ' + my_xml.toString();
    };
    // my_xml.load("http://spacebar.org/test.xml");
    my_xml.load("http://spacebar.org/f/a/tinyworld/get/tutorial3");
    */


    var bm = BitmapData.loadBitmap('title.png');
    var titlebitmap : BitmapData = 
      new BitmapData(720, 800, false, 0x000000);
    var grow = new Matrix();
    grow.scale(10,10);
    titlebitmap.draw(bm, grow);
    
    titlemc = _root.createEmptyMovieClip('titlemc', 999);
    titlemc.attachBitmap(titlebitmap, 1000);


    // title music!
    titlemusic = new Sound(this);
    titlemusic.attachSound('theme.mp3');
    titlemusic.setVolume(100);
    titlemusic.start(0, 99999);
  }

  public function onEnterFrame() {
    // Fade in...
    frames++;
    if (frames < FADEFRAMES) {
      // titlemusic.setVolume(frames);
    }

    var alpha = 100;
    if (frames < FADEFRAMES) {
      alpha = frames * ALPHAMULT;
    }

    if (frames > FADEFRAMES) {
      if (starting > 0) {
	if (_root['backgroundmusic']) {
	  titlemusic.setVolume(starting * ALPHAOUTMULT);
	}
        starting--;
        alpha = starting * ALPHAOUTMULT;
        if (!starting) {
          reallyStart();
        }
      }
    }

    this._alpha = 100 - alpha;
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
    case 89: // Y
    case 50: // 2
      // XXX also Enter
    case 32: // space
    case 38: // up
      triggerStart();
      break;
    }
  }

  public function reallyStart() {
    Key.removeListener(this);
    trace('reallystart!');
    // Stop music!

    this.titlemusic.stop();

    this.swapDepths(0);
    this.removeMovieClip();

    // Whole game takes place on this blank frame
    // in the root timeline.
    _root.gotoAndStop('game');

  }

};
