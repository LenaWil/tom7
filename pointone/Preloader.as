/* Preloader for all game. */
class Preloader extends MovieClip {

  var frames : Number = 0; 

  public function onLoad() {
    _root.stop();
  }

  public function onEnterFrame() {
    var total = Math.round(_root.getBytesTotal());
    var now = Math.round(_root.getBytesLoaded());

    var pct = now / total * 100;

    frames++;


    if (now < total) {
      // this._alpha = 80.0 * Math.sin(frames / 9) + 20.0;
    } else {
      // trace('preloader start');

      /* necessary if we want to trap escape key, etc. */
      fscommand("trapallkeys", "true");
      fscommand("showmenu", "false");
      Stage.showMenu = false;

      _root['musicenabled'] = true;

      // XXXXX title!
      // _root.gotoAndStop('game');
      _root.gotoAndStop('title');

      this.swapDepths(0);
      this.removeMovieClip();
    }

  }

}
