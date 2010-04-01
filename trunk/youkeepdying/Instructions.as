class Instructions extends ForegroundObject {

  var frames : Number = 0;
  var firstgotkeys : Number = -1;

  public function onLoad() {
    super.onLoad();
    this.gotoAndStop('nosignal');
  }

  public function onEnterFrame() {
    frames++;

    // After one second, clear
    // the message and spawn the
    // player.
    if (frames == 25) {
      // don't spawn more players if we return to this
      // screen!!
      if (_root.you == undefined) {
        _root.attachMovie("you", "you", 1,
                          {_x:250,
                              _y:50, 
                              _xscale:25,
                              _yscale:25});
      }
      this.gotoAndStop('blank');
    }

    if (frames == 2 * 25 + 25) {
      this.gotoAndStop('instructions');
    }

    if (frames == 5 * 25 + 25 && !_root.you.gotkeys) {
      this.gotoAndStop('nokeys');
    }

    if (firstgotkeys < 0 && _root.you.gotkeys) {
      firstgotkeys = frames;
      this.gotoAndStop('blank');
    }

    if (frames > 10 * 25 && firstgotkeys > 0 &&
        frames - firstgotkeys > 35) {
      this.gotoAndStop('go');
    }

    // Have to have moved, then stayed on this screen for
    // 1 minute
    if (firstgotkeys > 0 &&
        frames - firstgotkeys > 60 * 25) {
      this.gotoAndStop('ykd');
      _root.you.die('evaporate', {solid:false, floating:true});
      // reset, or you'll keep dying...
      frames = 0;
      firstgotkeys = 0;
    }

  }

}
