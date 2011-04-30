class DiscoballTitle extends MovieClip {

  #include "constants.js"

  var titlemusic : Sound;

  var frames : Number = 0;
  
  public function onLoad() {
    Key.addListener(this);
    titlemusic = new Sound(this);

    // XXX TODO: title music!
    titlemusic.attachSound('start.mp3');
    titlemusic.setVolume(0);
    titlemusic.start(0, 99999);

    this.swapDepths(1000);
  }

  public function onEnterFrame() {
    // Fade in...
    frames++;
    if (frames < 100) {
      titlemusic.setVolume(frames);
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
      this.titlemusic.stop();
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
