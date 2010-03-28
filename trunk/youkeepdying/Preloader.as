class Preloader extends MovieClip {

  var frames : Number = 0; 

  public function onEnterFrame() {
    var total = Math.round(getBytesTotal());
    var now = Math.round(getBytesLoaded());

    trace('loading ' + now + ' / ' + total);

    var pct = now / total * 100;

    frames++;

    if (now < total) {
      this._alpha = 80.0 * Math.sin(frames / 9) + 20.0;
    } else {
      /* necessary if we want to trap escape key, etc. */
      fscommand("trapallkeys", "true");
      fscommand("showmenu", "false");
      Stage.showMenu = false;
      /* attach player--once! */
      _root.attachMovie("you", "you", 1, {_x:100, _y:200, _xscale:25, _yscale:25});
      /* this position is bogus; it's replaced as soon as the player moves. */
      // _root.attachMovie("familiar", "familiar", 99980, {_x:100, _y:180});
      /* attach menubar */
      // _root.attachMovie("menubar", "menubar", 99500, {_x:0, _y:0});
      /* this is the global memory, also a singleton */
      // _root["memory"] = new Memory();
      // stop();
      // XXX should be 'start'
      _root.gotoAndStop('factoryfloor');
    }

  }

}
