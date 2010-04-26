class PressSpacebar extends MovieClip {

  var titlemusic : Sound;
  var volume : Number = 0;

  var planestarty : Number;
  var plane : MovieClip;

  // XXX use music obj!
  public function onLoad() {
    titlemusic = new Sound(this);
    titlemusic.attachSound('titlemp3');
    titlemusic.setVolume(0);
    volume = 0;
    titlemusic.start(0, 99999);
    Key.addListener(this);
    this._visible = false;
    planestarty = _root.plane._y;
    trace(planestarty);
  }

  var MAXCLOUDS = 25;
  var which : Number = 0;
  var nclouds : Number = 0;
  var frames : Number = 0;
  public function onEnterFrame() {
    frames++;
    if (volume < 100) {
      volume++;
      titlemusic.setVolume(volume);
    }

    // Add clouds
    if (nclouds < MAXCLOUDS && Math.random() < 0.1) {
      which = Math.round(Math.random() * 64) % 2;
      // trace(which);

      var idx = _root.global.decorationidx();
      if (idx != undefined) {
        nclouds++;
        var depth = 50 + 50 * (idx / _root.global.MAXDECORATIONS);
        var cloud =
          _root.attachMovie("cloud" + (which + 1), "cloud" + idx, 
                            _root.global.FIRSTDECORATION + idx, {
                            par: this,
                                depth: depth,
                                idx: idx,
                                _x: 900, 
                                _y: Math.random() * 600});
      }
    }

    // Move plane pleasantly
    _root.plane._y = planestarty + 16 * Math.sin(frames / 80);
    _root.plane._rotation = -8 * Math.sin(frames / 80);
    // trace(frames + ' ' + _root.plane._y);
  }

  public function kill(mc: Cloud) {
    _root.global.giveup(mc.idx);
    nclouds--;
    _root.removeMovieClip(mc);
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

      _root.global.nextLevel();

      break;
    }
  }


}
