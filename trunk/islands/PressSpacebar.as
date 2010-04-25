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

      _root.attachMovie("altimeter", "altimeter", 80000, {_x : 690, _y : 12});
      _root.attachMovie("angleometer", "angleometer", 80001, {_x : 600, _y : 12});
      _root.attachMovie("velometer", "velometer", 80002, {_x : 510, _y : 12});
      _root.attachMovie("airplane", "airplane", 1, {_x:50, _y:150});
      _root.viewport.place(_root.airplane);
      _root.viewport.place(_root.background);

      _root.gotoAndStop('firstlevel');
      break;
    }
  }


}
