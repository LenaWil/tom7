import flash.display.*;

// Shows only when in the danceoff.
// Displays success/failures.

class DanceoffIndicator extends Depthable {
  
  #include "constants.js"

  var bmback;
  var bmlite;

  var frames = 0;
  var dirty = true;

  public function init() {
    bmback = BitmapData.loadBitmap('danceindicator.png');
    bmlite = BitmapData.loadBitmap('dancelite.png');
    this._xscale = 200;
    this._yscale = 200;
    dirty = true;
    redraw();
  }

  // screen is 24x6
  var SWIDTH = 24;
  var SHEIGHT = 6;
  var s_off =
    '------------------------' +
    '------------------------' +
    '------------------------' +
    '------------------------' +
    '------------------------' +
    '------------------------';
    
  var s_danceoff =
    '--#-------------------#-' +
    '--#-##------------##--#-' +
    '-##---#-###---##-#-#--#-' +
    '#-#--##-#--#-#---###--#-' +
    '#-#-#-#-#--#-#---#------' +
    '-##-###-#--#--##--##--#-';

  var s_wrong =
    '--------##----##--------' +
    '--------###--###--------' +
    '----------####----------' +
    '----------####----------' +
    '--------###--###--------' +
    '--------##----##--------';

  var s_right =
    '###--##-####--###-#####-' +
    '####-##--##--##---##----' +
    '##-####--##--##---####--' +
    '##--###--##--##---##----' +
    '##---##--##--##---##----' +
    '##---##-####--###-#####-';

  // XXX version that swaps between
  // 'disco' and 'very'
  var s_disco =
    '-***--*--***--***--***--' +
    '-*--*-*-*----*----*---*-' +
    '-*--*-*-*----*----*---*-' +
    '-*--*-*--**--*----*---*-' +
    '-*--*-*----*-*----*---*-' +
    '-***--*-***---***--***--';

  var s_very =
    '##--##-#####-####--##--#' +
    '##--##-##----##--#-##--#' +
    '##--##-####--##--#---##-' +
    '##--##-##----####----##-' +
    '-####--##----##--#---##-' +
    '--##---#####-##--#---##-';

  var cur = s_off;

  public function setMessage(m, f) {
    cur = m;
    frames = f;
    dirty = true;
  }

  public function onEnterFrame() {
    if (frames > 0) {
      frames--;
      if (frames == 0) {
	cur = s_off;
	dirty = true;
      }
    }

    // Only redraws if dirty.
    redraw();
  }

  public function right(f) { setMessage(s_right, f); }
  public function disco(f) { setMessage(s_disco, f); }
  public function wrong(f) { setMessage(s_wrong, f); }
  public function dance(f) { setMessage(s_danceoff, f); }
  public function off() { setMessage(s_off, 0); }

  var deleteme = [];
  public function redraw() {
    if (dirty) {
      for (var o in deleteme)
	deleteme[o].removeMovieClip();

      var bg = this.createEmptyMovieClip('di_bg', this.getNextHighestDepth());
      bg._y = 0;
      bg._x = 0;
      bg.attachBitmap(bmback, bg.getNextHighestDepth());
      deleteme.push(bg);

      for (var y = 0; y < SHEIGHT; y++) {
	for (var x = 0; x < SWIDTH; x++) {
	  // Anything but hyphen turns it on.
	  if (cur.charCodeAt(y * SWIDTH + x) != 45) {
	    var mc = this.createEmptyMovieClip('di_' + y + '_' + x,
					       this.getNextHighestDepth());
	    mc._y = 5 + y * 9;
	    mc._x = 5 + x * 9;
	    mc.attachBitmap(bmlite, mc.getNextHighestDepth());
	    deleteme.push(mc);
	  }
	}
      }
    }
    dirty = false;
  }

}
