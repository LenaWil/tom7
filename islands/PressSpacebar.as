class PressSpacebar extends MovieClip {

  public function onLoad() {
    Key.addListener(this);
    this._visible = false;
  }


  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
    case 32: // space

      Key.removeListener(this);
      this.removeMovieClip();

      var startframe = 'level1';      
      _root.attachMovie("altimeter", "altimeter", 20000, {_x : 660, _y : 12});
      _root.attachMovie("airplane", "airplane", 1, {_x:50, _y:150});

      _root.gotoAndStop('firstlevel');
      break;
    }
  }


}
