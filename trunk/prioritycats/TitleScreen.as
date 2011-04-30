import flash.display.*;
class TitleScreen extends MovieClip {

  #include "constants.js"

  var titlemusic : Sound;

  // Count of frames that have passed
  var frames : Number = 0;
  // If >= 0, then we're starting the game, but fading out
  var starting : Number = -1;

  // Regular cat graphic, then pressing start button.
  var bg1, bg2;

  // XXX laserpointer!

  var bg: MovieClip = null;
  public function onLoad() {
    // Key.addListener(this);

    bg1 = BitmapData.loadBitmap('title.png');
    // XXX draw this for real
    bg2 = BitmapData.loadBitmap('titlestart.png');

    setframe(bg1);

    // XXX TODO: title music!
    // titlemusic = new Sound(this);
    // titlemusic.attachSound('start.mp3');
    // titlemusic.setVolume(0);
    // titlemusic.start(0, 99999);

    this.swapDepths(BGIMAGEDEPTH);
  }

  public function setframe(which) {
    if (bg) bg.removeMovieClip();
    this.createEmptyMovieClip('bg',
                              this.getNextHighestDepth());    
    bg._y = 0;
    bg._x = 0;
    bg._xscale = 200;
    bg._yscale = 200;
    bg.attachBitmap(which, bg.getNextHightestDepth());
  }

  public function onEnterFrame() {
    // Fade in...
    frames++;
    if (frames < 100) {
      // XXX titlemusic.setVolume(frames);
    }

    var alpha = 100;
    if (frames < 100) {
      alpha = frames;
    }

    // Shouldn't add laser pointer until we're faded in?
    // (Or at least shouldn't start starting countdown
    // in laserpointer.)
    if (frames > 100) {
      if (starting > 0) {
        starting--;
        this._alpha = starting;
        if (!starting) {
          reallyStart();
        }
      }
    }
  }

  // Called from TitleLaser when it's been on the
  // start button long enough.
  public function triggerStart() {
    // swap background.
    setframe(bg2);

    // need to wait a while, fading out.
    starting = 100;
  }


  public function reallyStart() {
    // Key.removeListener(this);

    // better to fade out...
    // XXX this.titlemusic.stop();

    // Don't need title screen any more.
    this.removeMovieClip();
    // XXX Also title laser pointer.

    // Whole game takes place on this blank frame
    // in the root timeline.
    _root.gotoAndStop('game');

    // trace(GAMESCREENHEIGHT); ?? why doesn't this work?
    // _root.status = _root.attachMovie('status', 'status', 15010,
    // {_x: 0, _y: 576});
    // _root.status.init();

    if (true) {
      // Normal
      // How to attach multiple cats?
      // I think the laser pointer will be the actual controlling
      // object.
      _root.you = _root.attachMovie('you', 'you', 1, {_x:50, _y:350});
      _root.you.init();
      _root.world.gotoRoom('start');
    } else {
      _root.you = _root.attachMovie('you', 'you', 1, {_x:50, _y:100});
      _root.you.init();
      _root.world.gotoRoom('vipcorneru');
    }
  }

};
