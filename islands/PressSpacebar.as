class PressSpacebar extends MovieClip {

  var titlemusic : Sound;
  var volume : Number = 0;

  public function onLoad() {
    titlemusic = new Sound(this);
    titlemusic.attachSound('titlemp3');
    titlemusic.setVolume(0);
    volume = 0;
    titlemusic.start(0, 99999);
    Key.addListener(this);
    this._visible = false;
  }

  public function onEnterFrame() {
    if (volume < 100) {
      volume++;
      titlemusic.setVolume(volume);
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

      var startframe = 'level1';      
      _root.attachMovie("altimeter", "altimeter", 20000, {_x : 660, _y : 12});
      _root.attachMovie("airplane", "airplane", 1, {_x:50, _y:150});

      _root.gotoAndStop('firstlevel');
      break;
    }
  }


}
