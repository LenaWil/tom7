import flash.display.*;

/* Also Moths sign */

class AlsoMoths extends MovieClip {

  #include "constants.js"
  #include "frames.js"

  var frame;
  var anim: MovieClip = null;

  public function init(w, x, y) {
    frame = BitmapData.loadBitmap('alsomoths.png');
    anim = this.createEmptyMovieClip('anim',
                                     this.getNextHighestDepth());
    anim.attachBitmap(frame, anim.getNextHighestDepth());
  }

  public function onLoad() {
    this._xscale = 200;
    this._yscale = 200;
  }

}
