import flash.display.*;

// This is the game status bar, which keeps track of
// what dances have been discovered, plus the current
// health.

class Status extends Depthable {
  
  #include "constants.js"

  // Just the unique one-letter code, which is the same
  // as the key you press to select it, and how it's
  // show on screen. Graphics in dance<CHAR>.png and
  // dance<CHAR>-seleted.png.
  var dancedata = [ 'z', 'x', 'c' ];

  var dances = {};

  // Z is the start dance, "robo walk".
  // X is breakdance, which makes you shorter.

  // TODO:
  // stomp (breaks floors)

  var currentdance = 'z';
  var hasdance = { z: true /* , x: true, c: true */ };

  // True once the boss has been defeated, and then true
  // forever.
  var boss_defeated = false;

  var newdancebm;

  public function learnDance(name) {
    // XXX should display a good indication of this!
    hasdance[name] = true;
    redraw ();
  }

  public function switchDance(d) {
    if (hasdance[d]) {
      currentdance = d;
      redraw();
      _root.you.setdimensions(d);
    }
  }

  public function getCurrentDance() {
    return currentdance;
  }

  public function selectDance(key) {
    switch(key) {
    case 90: // z
      switchDance('z');
      break;
    case 88: // x
      switchDance('x');
      break;
    case 67: // c
      switchDance('c');
      break;
    case 86: // v
      switchDance('v');
      break;
    case 66: // b
      switchDance('b');
      break;
    default:
      // nothing.
      break;
    }
  }

  public function init() {
    for (var i = 0; i < dancedata.length; i++) {
      dances[dancedata[i]] = {
        bmoff: BitmapData.loadBitmap('dance' + dancedata[i] + '.png'),
        bmon: BitmapData.loadBitmap('dance' + dancedata[i] + '-selected.png')
      };
    }
    newdancebm = BitmapData.loadBitmap('gotdance1.png');
    redraw();
  }

  public function bitmapFor(d) {
    return dances[d].bmon;
  }

  var gotnewdanceframes = 0;
  var dirty = true;
  public function showGotDance() {
    gotnewdanceframes = 3 * 24;
    dirty = true;
  }

  public function onEnterFrame() {
    // New dance bar.
    if (gotnewdanceframes > 0) {
      gotnewdanceframes--;
      if (gotnewdanceframes == 0) {
        dirty = true;
      }
    }

    if (dirty) {
      redraw();
      dirty = false;
    }
  }

  var deleteme = [];
  public function redraw() {
    var xx = 2;
    for (var o in deleteme)
      deleteme[o].removeMovieClip();
    for (var i = 0; i < dancedata.length; i++) {
      var d = dancedata[i];
      if (hasdance[d]) {
        var mc = this.createEmptyMovieClip('dance_status' + d,
                                           this.getNextHighestDepth());
        mc._xscale = 200;
        mc._yscale = 200;
        mc._y = 0;
        mc._x = xx;
        xx += WIDTH;
        mc.attachBitmap((d == currentdance) ?
                        dances[d].bmon :
                        dances[d].bmoff,
                        mc.getNextHighestDepth());
        deleteme.push(mc);
      }
    }

    // gotdance bar
    if (gotnewdanceframes > 0) {
      var gd = this.createEmptyMovieClip('dance_status' + d,
                                         this.getNextHighestDepth());
      xx += 6;
      gd._xscale = 200;
      gd._yscale = 200;
      gd._y = 0;
      gd._x = xx;
      gd.attachBitmap(newdancebm,
                      gd.getNextHighestDepth());
      deleteme.push(gd);
    }
    

    // XXX health bar
  }

}
