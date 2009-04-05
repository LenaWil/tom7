class Block extends MovieClip {
  
  var isblock;
  var fadetime;
  var birthtime;

  public function onLoad() {
    fadetime = 0;
    birthtime = 0;
    isblock = true;
    // this.gotoAndStop(2);
    this.stop();
  }

  public function fade() {
    this.play();
    // fadetime = 50;
    // birthtime = 300;
    // this.gotoAndStop(2);
  }

  public function onEnterFrame() {
    /*
    if (fadetime > 0) {
      this._alpha = 10 + fadetime * 2;
      fadetime--;
    } else if (!isblock) {
      // reborn?

    }
    */
  }
}
