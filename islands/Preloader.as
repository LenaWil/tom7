/*
   Preloader for Islands.

*/
class Preloader extends MovieClip {

  var frames : Number = 0; 

  public function onLoad() {
    _root.stop();
  }

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

      /*
      _root.memory = new Memory();

      _root.attachMovie("message", "message", 29999, 
                        {_x:64, _y:14});

      _root.attachMovie("resetmessage", "resetmessage", 49999, 
                        {_x:550 / 2, _y:400 / 2});
      */

      _root.attachMovie("messagestripe", "messagestripe", 49999,
			{_x: -6, _y: 105});

      _root.viewport = new Viewport();

      // Usually, nosignal.
      // _root.gotoAndStop(startframe);
      _root.gotoAndStop('menu');

      this.swapDepths(0);
      this.removeMovieClip();
    }

  }

}
