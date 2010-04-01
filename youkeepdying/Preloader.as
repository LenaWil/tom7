class Preloader extends MovieClip {

  var frames : Number = 0; 

  public function onEnterFrame() {
    var total = Math.round(_root.getBytesTotal());
    var now = Math.round(_root.getBytesLoaded());

    trace('loading ' + now + ' / ' + total);

    var pct = now / total * 100;

    frames++;

    // Maybe should have some lower bound on this so you
    // get to see the fun loading screen?!@?
    if (now < total) {
      this._alpha = 80.0 * Math.sin(frames / 9) + 20.0;
    } else {
      /* necessary if we want to trap escape key, etc. */
      fscommand("trapallkeys", "true");
      fscommand("showmenu", "false");
      Stage.showMenu = false;

      _root.attachMovie("message", "message", 29999, 
                        {_x:64, _y:14});
      /* this is the global memory, also a singleton */
      // _root["memory"] = new Memory();
      // stop();

      // Usually, nosignal.
      var startframe = 'nosignal';

      // Nosignal spanws the player via Instructions.
      if (startframe != 'nosignal') {
        /* attach player--once! */
        _root.attachMovie("you", "you", 1,
                          {_x:250,
                           _y:50, 
                           _xscale:25,
                           _yscale:25});
      }

      _root.gotoAndStop(startframe);

      this.swapDepths(0);
      this.removeMovieClip();
    }

  }

}
