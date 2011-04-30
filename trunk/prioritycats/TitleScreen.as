import flash.display.*;
class TitleScreen extends MovieClip {

  #include "constants.js"

  var titlemusic : Sound;

  // Count of frames that have passed
  var frames : Number = 0;
  
  // Regular cat graphic, then pressing start button.
  var bg1, bg2;

  // XXX laserpointer!

  var bg: MovieClip = null;
  public function onLoad() {
    Key.addListener(this);

    bg1 = BitmapData.loadBitmap('title.png');
    // XXX draw this
    bg2 = BitmapData.loadBitmap('title.png');
    this.createEmptyMovieClip('bg',
                              this.getNextHighestDepth());    
    bg._y = 0;
    bg._x = 0;
    bg._xscale = 200;
    bg._yscale = 200;
    bg.attachBitmap(bg1, bg.getNextHightestDepth());

    // XXX TODO: title music!
    // titlemusic = new Sound(this);
    // titlemusic.attachSound('start.mp3');
    // titlemusic.setVolume(0);
    // titlemusic.start(0, 99999);

    this.swapDepths(BGIMAGEDEPTH);
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
  }


  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
    case 32: // space

      Key.removeListener(this);

      // better to fade out...
      // XXX this.titlemusic.stop();
      this.removeMovieClip();

      _root.gotoAndStop('game');

      // trace(GAMESCREENHEIGHT); ?? why doesn't this work?
      // _root.status = _root.attachMovie('status', 'status', 15010,
      // {_x: 0, _y: 576});
      // _root.status.init();

      if (true) {
        // Normal
        // How to attach multiple cats?
        _root.you = _root.attachMovie('you', 'you', 1, {_x:50, _y:350});
        _root.you.init();
        _root.world.gotoRoom('start');
      } else {
        _root.you = _root.attachMovie('you', 'you', 1, {_x:50, _y:100});
        _root.you.init();
        _root.world.gotoRoom('vipcorneru');
      }

      break;
    }
  }

};
