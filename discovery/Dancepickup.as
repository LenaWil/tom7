import flash.display.*;

// Pick this up to get a dance.
// The room determines the dance.

class Dancepickup extends PhysicsObject {

  var dx = 0;
  var dy = 0;

  var bgblock;

  var whatdance;

  public function givesDance() {
    return whatdance;
  }

  public function onLoad() {
    this.width = 32;
    this.height = 32;
    this._xscale = 200;
    this._yscale = 200;
    this.stop();
    bgblock = BitmapData.loadBitmap('dancepickup.png');
    
    var bg = this.createEmptyMovieClip('dp_bg', this.getNextHighestDepth());
    bg._y = 0;
    bg._x = 0;
    bg.attachBitmap(bgblock, bg.getNextHighestDepth());

    var fg = this.createEmptyMovieClip('dp_fg', this.getNextHighestDepth());
    fg._y = 2;
    fg._x = 2;

    switch (_root.world.getCurrentRoom()) {
    case 'xpickup':
      whatdance = 'x';
      break;
    case 'cpickup':
      whatdance = 'c';
      break;
    case 'vpickup':
      whatdance = 'v';
      break;
    case 'zpickup':
    default:
      whatdance = 'z';
      break;
    }
    fg.attachBitmap(_root.status.bitmapFor(whatdance),
                    this.getNextHighestDepth());

    _root.squares.push(this);
    this.setdepth(4050);
  }

  var MAXFADE = 20;
  var fadeframes = 0;

  public function take() {
    // Don't allow the player to keep taking it.
    if (fadeframes == 0)
      fadeframes = MAXFADE;
  }

  // Physics object so that it falls to land on a surface.
  public function onEnterFrame() {
    if (fadeframes > 0) {
      fadeframes--;
      this._alpha = 100 * fadeframes / MAXFADE;
      if (fadeframes == 0) {
        this._visible = false;
        // Hack, since I don't want to clean myself out of
        // the squares list.
        this._x = -100;
        this._y = -100;
      }
    }
    movePhysics();
  }
}
