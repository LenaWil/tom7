import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;

class Game extends MovieClip {

  #include "constants.js"
  #include "util.js"

  var backgroundbm : BitmapData = null;
  // All block sprites.
  var blocksbm : BitmapData = null;
  var sfxmc : MovieClip = null;

  // All player sprites.
  var playerbmr = {};
  // Rotated.
  var playerbml = {};
  var playerbmu = {};
  var playerbmd = {};

  var gamebm : BitmapData = null;
  var timerbm : BitmapData = null;
  var barbm : BitmapData = null;
  var pointsbm : BitmapData = null;

  // Bitmap data for each block.
  var blockbms = [];

  var NORMAL = 0;
  var VSMOOTH = 1;
  var HSMOOTH = 2;
  var ICONS = 1;
  var DARK = 2;
  var DARKICONS = 3;

  var info : Info = null;
  var airfo : Airfo = null;
  var airframes = 0;

  var holdingSpace = false;
  var holdingZ = false;
  var allowX = true;
  var holdingX = false;
  var holdingUp = false;
  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;
  var holdingEsc = false;

  var dead = false;

  // Global animation offset. Resets to stay integral
  // and reasonably small.
  var animframe = 0;
  // Which way is the player facing?
  var facingleft = true;
  var inair = false;
  // Use this in TOPDOWN mode.
  var orientation = LEFT;
  var UP = 0, DOWN = 1, LEFT = 2, RIGHT = 3;
  var screamframes = 0;
  // Number of frames until next suffocate sound,
  // if suffocating.
  var suffocating = false;
  var suffocateframes = 0;

  // Size TILESW * TILESH.
  // Each cell points to a block or null.
  var grid = [];
  // All the blocks currently around.
  var blocks = [];

  // Most recent air computation.
  var air = [];
  // -1 if connected to outside
  var airea = 0;
  // Number of frames we've spent enclosed.
  var framesenclosed = 0;

  // The points coming up. The current one is first
  // in the list, so this is nonempty during play.
  var points = [];
  // Frames left in this point.
  var framesinpoint = 0;

  // Directions.
  var VERT = -1;
  var NONE = 0;
  var HORIZ = 1;

  // FPS computation.
  var framesdisplayed = 0;
  var starttime = 0;

  // XXX playerframes...

  /*
    A block has these fields:
    what: int
    ... the number of the block, from enum XXX

    x, y: int
    ... the grid coordinates of its top-left corner,
    including any growth.

    dir: direction
    The direction in which the block is not (necessarily)
    size 1. This is usually NONE for 1x1 blocks, but can
    be VERT or HORIZ to constrain its growth (or prevent
    it from falling, sliding, etc.) A block cannot be
    larger than size 1 in both dimensions.

    len: int
    the length along its long edge, in tiles. always >= 1.

    Essentially (x, y, dir, len) gives the full grid-aligned
    bounding box of this block. Invariant: No two blocks
    have overlapping bounding boxes.

    Every grid cell inside the bounding box points to this
    block.

    shrink1, shrink2: int

    ... shrinkage for the beginning and end point on the long
    dimension. 0 represents a block that fully fills its bounding
    rectangle. this has range [0, BLOCKW], and is the number of pixels
    shy of the full bounding rectangle on that side. shrink1 is
    the top for VERT and the left for HORIZ, obviously.

    Note that falling and pushing are implemented as shrinkage, in
    addition to growing (of course). Block-to-block calculations are
    always done on the bounding boxes. Shrinkage is only for drawing
    and for computing the player's position, which is integral.

    frames: int
    frame countdown timer for breaking bricks, maybe other purposes.
    optional.
   */

  // Logical left corner of the player.
  // Graphic is drawn at this spot -(PLAYERLAPX, PLAYERLAPY)
  // Always integral!
  var playerx = 0;
  var playery = 0;

  // Used when the point has physics.
  var playerdx = 0;
  var playerdy = 0;

  // Fractional pixels. Ignored for clipping, but
  // makes smoother motion when in free space.
  // Always in [-1, 1];
  var playerfx = 0;
  var playerfy = 0;

  public function initpoints() {
    points = [2, 1, 0];
    for (var i = 0; i < INITIALPOINTS; i++) {
      var p = Math.round(Math.random() * (NPOINTS - 1));
      if (p == PHURT) p = PSOKO;
      if (p == PKING) p = PFALL;
      points.unshift(p);
    }

    // Always start with a plain one.
    points.unshift(3);
    // points.unshift(8);
    updatemessage();

    framesinpoint = 10 * FPS;
    switchMusic(points[0]);
  }

  public function initboard() {
    blocks = [];
    grid = [];

    // XXX Terrible unfun level generator!
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        if (Math.random() < 0.2) {
          var what = 0;
          if (Math.random() < 0.6) {
            // what = int((Math.random() * 1000) % NREG);
            what = BSILVER;
          } else {
            if (Math.random() < 0.5) {
              what = Math.random() < 0.5 ? BVERT : BHORIZ;
            } else {
              // XXX avoid picking special blocks!
              what = int((Math.random() * 1000) % NPICK);
              if (what == B0) {
                what = B2;
              } else if (what == B1) {
                what = B3;
              }
            }
          }

          var d = NONE;
          if (what == BVERT) d = VERT;
          else if (what == BHORIZ) d = HORIZ;
          else if (what == BSILVER) {
            d = (Math.random() < 0.5) ? VERT : HORIZ;
          }

          var block = { what: what,
                        x: x, y: y, len: 1,
                        dir: d,
                        shrink1: 0,
                        shrink2: 0 };
          blocks.push(block);
          grid.push(block);
        } else {
          grid.push(null);
        }
      }
    }

    // Randomly grow some vert/horiz ones.
    /*
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (blocks[i].dir == HORIZ) {
        // Try extending to left, right...
        var y = b.y;
        // This always extends all the way left until
        // it hits something...
        while (grid[y * TILESW + (b.x - 1 + TILESW) % TILESW] == null) {
          b.len++;
          b.x = (b.x - 1 + TILESW) % TILESW;
          grid[y * TILESW + b.x] = b;
          // trace('extended to ' + b.x + ',' + b.y +
          // ' for ' + b.len);
          if (Math.random() < 0.2) {
            b.shrink1 = int(Math.random() * (BLOCKW - 1));
            if (b.len >= 3) {
              // b.shrink2 = int(Math.random() * (BLOCKH - 1));
              b.shrink2 = 12;
            }
            // trace('stop early with shrinks ' + b.shrink1);
            break;
          }
        }

      } else if (blocks[i].dir == VERT) {

        // Try extending up
        var x = b.x;
        // This always extends all the way left until
        // it hits something...
        while (grid[((b.y - 1 + TILESH) % TILESH) * TILESW + x] == null) {
          b.len++;
          b.y = ((b.y - 1 + TILESH) % TILESH);
          grid[b.y * TILESW + x] = b;
          // trace('v-extended to ' + b.x + ',' + b.y +
          // ' for ' + b.len);
          if (Math.random() < 0.2) {
            b.shrink1 = int(Math.random() * (BLOCKW - 1));
            if (b.len >= 3) {
              // b.shrink2 = int(Math.random() * (BLOCKH - 1));
              b.shrink2 = 12;
            }
            // trace('stop early with shrinks ' + b.shrink1);
            break;
          }
        }

      }

    }
    */

  }

  // Current point.
  var backgroundmc = null;
  // Previous point can overlap a little.
  var oldbackgroundmc = null;

  var backgroundmusic = null;
  var oldbackgroundmusic = null;
  var musicparity = false;
  public function switchMusic(p) {

    // Does this leak??
    if (oldbackgroundmusic) oldbackgroundmusic.stop();
    if (oldbackgroundmc) oldbackgroundmc.removeMovieClip();
    oldbackgroundmc = backgroundmc;
    oldbackgroundmusic = backgroundmusic;
    // XXX fade out old?

    var d = musicparity ? BGMUSICDEPTH : BGMUSICDEPTH2;
    musicparity = !musicparity;
    backgroundmc = createMovieAtDepth('bgm' + d, d);
    backgroundmusic = new Sound(backgroundmc);
    if (MUSIC) {
      backgroundmusic.attachSound('' + p + '.wav');
      backgroundmusic.setVolume(100);
      backgroundmusic.start(0, 1);
    }
  }

  public function stopmusic() {
    backgroundmusic.stop();
    oldbackgroundmusic.stop();
  }

  public function onLoad() {
    Key.addListener(this);
    init();
  }

  public function splitBlocks() {
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (b != null) {
        if (b.dir == HORIZ) {

          if (b.len > 1) {
            deleteBlock(b);
            for (var x = 0; x < b.len; x++) {
              var xx = (b.x + x + TILESW) % TILESW;
              var newb = { what: b.what,
                           dir: b.dir,
                           len: 1,
                           shrink1: 0,
                           shrink2: 0,
                           x: xx, y: b.y };
              grid[b.y * TILESW + xx] = newb;
              blocks.push(newb);
            }
          }

        } else if (b.dir == VERT) {

          if (b.len > 1) {
            deleteBlock(b);
            for (var y = 0; y < b.len; y++) {
              var yy = (b.y + y + TILESH) % TILESH;
              var newb = { what: b.what,
                           dir: b.dir,
                           len: 1,
                           shrink1: 0,
                           shrink2: 0,
                           x: b.x, y: yy };
              grid[yy * TILESW + b.x] = newb;
              blocks.push(newb);
            }
          }

        }
      }
    }

  }

  public function growBlocks() {
    var parity = (framesinpoint % 2) == 0;

    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (b != null) {
        if (b.dir == HORIZ) {

          if (parity) {
            // even parity. grow left
            growLeft(b);
          } else {
            // odd parity. grow right...
            growRight(b);
          }

        } else if (b.dir == VERT) {

          if (parity) {
            // even parity. grow top
            if (b.shrink1 > 0) {
              b.shrink1--;
            } else {
              // If shrink is zero, try expanding up.
              var nby = (b.y - 1 + TILESH) % TILESH;
              if (grid[nby * TILESW + b.x] == null) {
                // claim it!
                b.len++;
                b.y = nby;
                grid[nby * TILESW + b.x] = b;
                b.shrink1 = 15;
              }
            }
          } else {
            // odd parity. grow down...
            growDown(b);
          }

        }
      }
    }
  }

  // TODO: Fall faster; accelerate!
  public function fallBlocks() {
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];

      // TODO: Also could turn NONE blocks into vert.
      // but be careful of breaking ones.
      if (b.dir == VERT) {

        var nblast = (b.y + b.len + TILESH) % TILESH;
        // Can fall if below us is clear; it's always safe
        // to shrink from the top if we're extending at the
        //s ame time.
        var canfall = b.shrink2 > 0 ||
          grid[nblast * TILESW + b.x] == null;

        if (canfall) {
          // OK, grow down.
          // (PERF: Don't need to repeat checks)
          growDown(b);

          // And shrink up.
          if (b.shrink1 < 15) {
            b.shrink1++;
          } else {
            grid[b.y * TILESW + b.x] = null;
            b.y = (b.y + 1 + TILESH) % TILESH;
            b.len--;
            b.shrink1 = 0;
          }
        }
      }
    }
  }

  public function growLeft(b) {
    if (b.shrink1 > 0) {
      b.shrink1--;
    } else {
      // If shrink is zero, try expanding to the left.
      var nbx = (b.x - 1 + TILESW) % TILESW;
      if (grid[b.y * TILESW + nbx] == null) {
        // claim it!
        b.len++;
        b.x = nbx;
        grid[b.y * TILESW + nbx] = b;
        b.shrink1 = 15;
      }
    }
  }

  // Assumes is HORIZ.
  public function growRight(b) {
    if (b.shrink2 > 0) {
      b.shrink2--;
    } else {
      // Try expanding length.
      var nblast = (b.x + b.len + TILESW) % TILESW;
      if (grid[b.y * TILESW + nblast] == null) {
        b.len++;
        grid[b.y * TILESW + nblast] = b;
        b.shrink2 = 15;
      }
    }
  }

  // Assumes is VERT.
  public function growDown(b) {
    var nblast = (b.y + b.len + TILESH) % TILESH;
    if (b.shrink2 > 0) {
      b.shrink2--;
    } else if (grid[nblast * TILESW + b.x] == null) {
      b.len++;
      grid[nblast * TILESW + b.x] = b;
      b.shrink2 = 15;
    }
  }

  public function breakingBlocks() {
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (b.what == BBREAK) {
        b.frames--;
        if (b.frames == 0) {
          deleteBlock(b);
        }
      }
    }
  }

  // XXX not real; just used below; fix
  public function blockPixels(b) {
    if (b.len == 1) return BLOCKW;
    else if (b.len > 2) return 3 * BLOCKW;
    else if (b.len == 1)
      return (16 - b.shrink1) +
        (16 - b.shrink2);
  }

  public function shrinkBlocks() {
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (b.dir == HORIZ) {

        // Just shrink from right edge.
        if (b.len > 1 && blockPixels(b) > BLOCKW + 1) {
          if (b.shrink2 == 15) {
            b.shrink2 = 0;
            var blast = (b.x + b.len - 1 + TILESW) % TILESW;
            grid[b.y * TILESW + blast] = null;
            b.len--;
          } else {
            b.shrink2++;
          }
        }

      } else if (b.dir == VERT) {

        // Just shrink from bottom edge.
        if (b.len > 1 && blockPixels(b) > BLOCKH + 1) {
          if (b.shrink2 == 15) {
            b.shrink2 = 0;
            var blast = (b.y + b.len - 1 + TILESH) % TILESH;
            grid[blast * TILESW + b.x] = null;
            b.len--;
          } else {
            b.shrink2++;
          }
        }

      }
    }
  }

  public function blockPhysics() {

    // Maybe not if frozen?
    breakingBlocks();

    // Growth.
    if (points[0] == PGROWTH) {
      growBlocks();
    } else if (points[0] == PSPLIT) {
      splitBlocks();
    } else if (points[0] == PSHRINK) {
      shrinkBlocks();
    } else if (points[0] == PFALL) {
      fallBlocks();
    } else {

      // Grow spikes more slowly...
      if (points[0] != PHURT ||
          animframe % 2 == 0) {
        normalizeBlocks();
      }
    }
  }

  // We try to keep the blocks at normal sizes (full blocks),
  // since air can't pass through slivers and there are some
  // unintuitive choking hazards.
  public function normalizeBlocks() {

    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (b.dir == HORIZ) {
        if (b.shrink1 > 0)
          growLeft(b);

        if (b.shrink2 > 0)
          growRight(b);

      } else if (b.dir == VERT) {

        if (b.shrink1 > 0)
          growUp(b);

        if (b.shrink2 > 0)
          growDown(b);

      }
    }
  }

  public function growUp(b) {
    // even parity. grow top
    if (b.shrink1 > 0) {
      b.shrink1--;
    } else {
      // If shrink is zero, try expanding up.
      var nby = (b.y - 1 + TILESH) % TILESH;
      if (grid[nby * TILESW + b.x] == null) {
        // claim it!
        b.len++;
        b.y = nby;
        grid[nby * TILESW + b.x] = b;
        b.shrink1 = 15;
      }
    }
  }

  public function thinkPhysics() {
    var dx = 0, dy = 0;
    if (holdingDown) {
      dy++;
      holdingDown = false;
    } else if (holdingUp) {
      dy--;
      holdingUp = false;
    }

    if (holdingLeft) {
      dx--;
      holdingLeft = false;
    } else if (holdingRight) {
      dx++;
      holdingRight = false;
    }

    // Move screen then...
    if (dx != 0 || dy != 0) {
      var newg = [];
      for (var y = 0; y < TILESH; y++) {
        for(var x = 0; x < TILESW; x++) {
          var ox = (x - dx + TILESW) % TILESW;
          var oy = (y - dy + TILESH) % TILESH;
          newg[y * TILESW + x] = grid[oy * TILESW + ox];
        }
      }
      grid = newg;

      for (var i = 0; i < blocks.length; i++) {
        var b = blocks[i];
        if (b != null) {
          b.x = (b.x + dx + TILESW) % TILESW;
          b.y = (b.y + dy + TILESH) % TILESH;
        }
      }

      playerx += dx * BLOCKW;
      playery += dy * BLOCKH;
      playerx = (playerx + GAMEW) % GAMEW;
      playery = (playery + GAMEH) % GAMEH;

      // Invalid now, just want to make failures obvious..
      air = [];
    }
  }

  public function addHoriz(b) {
    blocks.push(b);
    for (var x = 0; x < b.len; x++) {
      grid[b.y * TILESW + ((b.x + x + TILESW) % TILESW)] = b;
    }
  }

  // Clear the cell at x,y, which may involve splitting up
  // a long brick. tx,ty already modded
  public function clearCell(tx, ty) {
    var idx = ty * TILESW + tx;
    var b = grid[idx];

    if (b == null)
      return;

    // Delete it no matter what.
    deleteBlock(b);

    // And this cell is now empty.
    grid[idx] = null;

    // Nothing to do if NONE, but otherwise, we
    // might create segments.
    if (b.dir == HORIZ) {

      /*
      var txx = (tx >= b.x) ? tx : (tx + TILESW);
      if (b.x != txx) {
        // Left segment.
        var newb = { x: b.x, y: b.y,
                     dir: HORIZ, len: txx - b.x,
                     what: b.what,
                     shrink1: 0, shrink2: 0 };
        addHoriz(newb);
      }
      */

      // XXX also right segment.

    } else if (b.dir == VERT) {

      // XXX fix verts
      /*
      for (var y = 0; y < b.len; y++) {
        var yy = (b.y + y) % TILESH;
        var newb = { x: b.x, y: yy,
                     dir: NONE, len: 1,
                     what: BBREAK,
                     frames: BREAKFRAMES,
                     shrink1: 0, shrink2: 0 };
        grid[yy * TILESW + b.x] = newb;
        blocks.push(newb);
      }
      */

    }

  }

  public function makeSpike(tx, ty, d) {
    var idx = ty * TILESW + tx;
    var b = { what: BSPIKE,
              dir: d,
              len: 1,
              x: tx,
              y: ty,
              shrink1: 0, shrink2: 0 }
    grid[idx] = b;
    blocks.push(b);
  }

  public function beginSpikes() {
    // Ensure that the whole border is spikes.
    for (var y = 0; y < TILESH; y++) {
      clearCell(0, y);
      makeSpike(0, y, HORIZ);
      clearCell(TILESW - 1, y);
      makeSpike(TILESW - 1, y, HORIZ);
    }

    for (var x = 0; x < TILESW; x++) {
      clearCell(x, 0);
      makeSpike(x, 0, VERT);
      clearCell(x, TILESH - 1);
      makeSpike(x, TILESH - 1, VERT);
    }
  }

  public function spikePhysics() {
    var parity = (animframe % 10) == 0;

    if (!parity) return;

    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (b.what == BSPIKE) {
        if (b.dir == HORIZ) {
          growLeft(b);
          growRight(b);

        } else if (b.dir == VERT) {
          growUp(b);
          growDown(b);
        }
      }
    }

    // Delay so that new spikes don't immediately spawn
    // more...
    var tomake = [];

    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        var b = grid[y * TILESW + x];
        if (b == null) {
          // Check for adjacent perpendicular spike, and spawn if we
          // find one.
          var a = [{dx: 1, dy: 0, d:HORIZ},
                   {dx: -1, dy: 0, d:HORIZ},
                   {dy: 1, dx: 0, d:VERT},
                   {dy: -1, dx: 0, d:VERT}];
          for (var i = 0; i < a.length; i++) {
            var z = a[i];
            var tx = (x + z.dx + TILESW) % TILESW;
            var ty = (y + z.dy + TILESH) % TILESH;
            var b2 = grid[ty * TILESW + tx];
            if (b2.what == BSPIKE &&
                b2.dir != z.d) {
              // Make spike!
              tomake.push({x:x, y:y, d:z.d});
              break;
            }
          }
        }
      }
    }

    for (var i = 0; i < tomake.length; i++) {
      makeSpike(tomake[i].x, tomake[i].y, tomake[i].d);
    }

  }

  var gameoverframes = 0;
  public function gameover(win) {

    if (_root.gameovermc) {
      if (gameoverframes > 0) {
        gameoverframes--;
      } else {
        stopmusic();
        _root.gameovermc.removeMovieClip();
        _root.gameovermc = undefined;
        _root.gamemc.removeMovieClip();
        _root.timermc.removeMovieClip();
        _root.pointsmc.removeMovieClip();
        _root.backgroundmc.removeMovieClip();
        info.destroy();
        airfo.destroy();

        _root.gotoAndStop('title');
        this.swapDepths(0);
        this.removeMovieClip();
        return;
      }
    } else {
      gameoverframes = win ? (10 * FPS) : (3 * FPS);
      var gameoverbm = loadBitmap2x(win ? 'youwin.png' : 'youlost.png');
      _root.gameovermc = createGlobalMC('go', gameoverbm, GAMEOVERDEPTH);
      _root.gameovermc._x = 0;
      _root.gameovermc._y = 0;

      // Because it can be mid-level..
      stopmusic();

      if (win) {
        switchMusic(9);
      } else {
        switchMusic(4);
      }
    }
  }

  public function deconf() {
    // Is the player inside any brick from it growing
    // into him? If so and we can deconflict, do so.

    // trace('-- deconf --');

    playerx +=
      deconfhoriz(playerx + RIGHTFOOT,
                  1,
                  playery + HEAD,
                  playery + FEET);

    playerx +=
      deconfhoriz(playerx + LEFTFOOT,
                  -1,
                  playery + HEAD,
                  playery + FEET);

    playery +=
      deconfvert(playery + FEET, 1,
                 playerx + LEFTFOOT,
                 playerx + RIGHTFOOT);

    playery +=
      deconfvert(playery + HEAD, -1,
                 playerx + LEFTFOOT,
                 playerx + RIGHTFOOT);
  }

  public function deconfhoriz(px, dx, y1, y2) {
    for (var count = 0; count < BLOCKW / 2; count++) {
      var xx = px - (count * dx);

      // Once both are clear, stop. (Usually we hit this
      // on the first iteration.)
      if (!pixelIsSolid(xx, y1) &&
          !pixelIsSolid(xx, y2)) {
        if (count > 0) {
          // trace('deconf to ' + count + ' * ' + -dx);
          playerfx = 0;
        }
        return count * -dx;
      }
    }

    // If we didn't get clear, don't move at all.
    return 0;
  }

  public function deconfvert(py, dy, x1, x2) {
    for (var count = 0; count < BLOCKW / 2; count++) {
      var yy = py - (count * dy);

      // Once both are clear, stop. (Usually we hit this
      // on the first iteration.)
      if (!pixelIsSolid(x1, yy) &&
          !pixelIsSolid(x1, yy)) {
        if (count > 0) {
          // trace('ydeconf to ' + count + ' * ' + -dy);
          playerfy = 0;
        }
        return count * -dy;
      }
    }

    // If we didn't get clear, don't move at all.
    return 0;
  }

  public function onEnterFrame() {
    framesdisplayed++;
    animframe++;
    if (animframe > 1000000) animframe = 0;

    if (dead) {
      if (screamframes == 0) {
        gameover(false);

        return;
      }

      // so that it's drawn accurately
      computeAir();
      // they're relentless
      spikePhysics();
      blockPhysics();
      redraw();
      return;
    }

    // XXX off by one?
    if (framesinpoint == 0) {
      framesinpoint = 10 * FPS;
      nextpoint();
    } else {
      framesinpoint--;
    }

    if (points[0] == PHURT) {
      spikePhysics();
      checkSpikes();
    }

    if (points[0] == PTHINK) {
      thinkPhysics();
    } else {
      playerPhysics();
      playerActions();
      checkPickup();
      blockPhysics();
      deconf();
    }

    // must happen after thinkphysics...
    computeAir();
    if (points[0] != PTHINK) {
      breathe();
    }

    redraw();
  }

  public function breathe() {

    // Slop so that user sees it coming...
    if (framesenclosed > 10) {
      var breath = framesenclosed / FRAMESPERAIR;
      if (breath > airea) {
        suffocating = false;
        scream();
      } else if (breath > (airea * 0.30)) {
        suffocating = true;

        if (suffocateframes == 0) {
          playBreatheSound();
          suffocateframes = BREATHEEVERY;
        }
      }
    } else {
      suffocating = false;
      suffocateframes = 0;
    }
  }

  public function scream() {
    // Scream already in progress. We need to wait
    // for the blocks to dissolve, for example.
    if (screamframes > 0)
      return;

    screamframes = 12;
    playCrySound();

    // Could be cooler...

    var ty = Math.floor((playery + HEAD) / BLOCKW);
    ty = (ty + TILESH) % TILESH;
    var tx = Math.floor((playerx + BLOCKW / 2) / BLOCKW);
    tx = (tx + TILESW) % TILESW;

    // Up.
    for (var y = 0; ty - y >= 0; y++)
      punchBlock(tx, ty - y);

    // Down
    for (var y = 1; ty + y < TILESH; y++)
      punchBlock(tx, ty + y);


    // Left
    for (var x = 0; tx - x >= 0; x++)
      punchBlock(tx - x, ty);

    // Right
    for (var x = 1; tx + x < TILESW; x++)
      punchBlock(tx + x, ty);

    computeAir();
  }

  public function updatemessage() {
    if (points.length == 0) {
      info.setMessage('- no more points -');
      return;
    }
    switch (points[0]) {
    case PKING:
      info.setMessage('Point Zero Rules!');
      break;
    case PHURT:
      info.setMessage('Point One Hurts.');
      break;
    case PSPLIT:
      info.setMessage('Point Two Splits.');
      break;
    case PSWAP: // XXX
    case PNORM:
      info.setMessage('Use arrow keys, space, z and x.');
      break;
    case PSHRINK:
      info.setMessage('Point Four Shrinks.');
      break;
    case PTHINK:
      info.setMessage('Point Five Thinks.');
      break;
    case PFALL:
      info.setMessage('Point Seven Falls.');
      break;
    case PGROWTH:
      info.setMessage('Point Eight Grows.');
      break;
    case PSOKO:
      info.setMessage('Point Nine Flies.');
      break;
    }
  }

  public function nextpoint() {
    points.shift();
    updatemessage();

    if (points.length == 0) {
      // but in heaven
      dead = true;
      gameover(true);
      return;
    }

    framesinpoint = 10 * FPS;
    switchMusic(points[0]);

    // Initialization...
    if (points[0] == PHURT) {
      beginSpikes();
    }
  }

  // This is for testing pixel-level physics like the player
  // clipping and some effects (e.g. stars, if I do that).
  // Consider treating breaking blocks as non-solid?
  public function pixelIsSolid(px, py) {
    // Wrap around physics...
    px = px % GAMEW;
    py = py % GAMEH; // (py + 1) % GAMEH;

    var tx = Math.floor(px / BLOCKW);
    var ty = Math.floor(py / BLOCKH);

    var b = grid[ty * TILESW + tx];
    if (!b) return false;

    // Pickups are not solid.
    if (b.what >= B0 && b.what <= B9)
      return false;

    // Don't allow standing on spikes.
    if (b.what == BSPIKE)
      return false;

    // wraps around the screen .. shouldn't be too hard
    // Assume all blocks are solid for now.
    if (b.dir == HORIZ) {
      // Then if it's the first or last block, we need
      // to test the shrinkage.
      var xoff = px - tx * BLOCKW;
      var blast = (b.x + b.len - 1) % TILESW;
      if (tx == b.x) {
        return xoff >= b.shrink1;
      } else if (tx == blast) {
        // Number of solid pixels.
        var solid = BLOCKW - b.shrink2;
        return xoff < solid;
      }

      return true;
    } else if (b.dir == VERT) {
      var yoff = py - ty * BLOCKH;
      var blast = (b.y + b.len - 1) % TILESH;
      if (ty == b.y) {
        return yoff >= b.shrink1;
      } else if (ty == blast) {
        var solid = BLOCKH - b.shrink2;
        return yoff < solid;
      }

      return true;
    } else {
      // This always means 1x1 block.
      return true;
    }
  }

  // Takes pixel location of the foot.
  public function footOnBlock(px, py) {
    // Actual pixel to test is one beneath our foot.
    return pixelIsSolid(px, py + 1);
  }

  public function onGround() {
    // Test if the player is on the ground and
    // can do ground stuff like jump.

    var feety = playery + BLOCKH;

    // Might test one or two tiles, but even if there
    // is just one tile, we have to test twice because
    // it might have nonzero horizontal shrinkage.
    var px1 = playerx + LEFTFOOT;
    var px2 = playerx + RIGHTFOOT;

    // Only can be a collision if we're standing on a
    // bounding box.
    return footOnBlock(px1, feety) ||
      footOnBlock(px2, feety);
  }

  // startx, y1, y2 always integers. endx is fractional.
  // dx must be 1 or -1. we move startx to endx but clip
  // against x + offset.
  // there exists positive k such that startx + k * dx = endx.
  // Precondition: Player is not stuck.
  public function trymovinghoriz(offset,
                                 startx, endx, dx,
                                 y1, y2) {
    var ix = Math.round(endx);
    // Integer sweep, which gets us perfect physics.
    // Velocities have to be low for this to be efficient, however.
    // PERF less maths...
    for (var x = startx; x != ix; x += dx) {
      if (pixelIsSolid(x + dx + offset, y1) ||
          pixelIsSolid(x + dx + offset, y2)) {
        // TODO: Should probably return block touched,
        // for pushing etc.
        return { x: x, hit: true, fx: 0 };
      }
    }

    return { x: ix, hit: false, fx: endx - ix };
  }

  // Symmetrically for y.
  public function trymovingvert(offset,
                                starty, endy, dy,
                                x1, x2) {
    var iy = Math.round(endy);
    // PERF less maths...
    for (var y = starty; y != iy; y += dy) {
      if (pixelIsSolid(x1, y + dy + offset) ||
          pixelIsSolid(x2, y + dy + offset)) {
        // TODO: Same about block touched.
        return { y: y, hit: true, fy: 0 };
      }
    }

    return { y: iy, hit: false, fy: endy - iy };
  }

  var jumpframes = 0;
  public function playerPhysics() {
    var YGRAV = 0.48;
    var XGRAV = 0;
    var XMU = 0.9;
    var XGROUNDMU = 0.7;
    var YMU = 0.9;
    // Basically only used in topdown mode.
    var YGROUNDMU = 0.7;

    var TERMINALX = 6;
    var TERMINALY = 7;

    var GTERMINALX = 4.5;

    var TOPDOWN = false;

    if (points[0] == PSOKO) {
      YGRAV = 0;
      XGRAV = 0;
      TOPDOWN = true;
      TERMINALY = TERMINALX = GTERMINALX;
      YGROUNDMU = XGROUNDMU = 0.5;
    }

    var ddy = 0;
    // XXX same on-ground treatment for xgrav?
    var ddx = XGRAV;

    var og = TOPDOWN || onGround();

    // First, changes in acceleration.
    if (!TOPDOWN && og && jumpframes == 0) {
      if (holdingSpace) {
        playJumpSound();
        jumpframes = 6;
        ddy -= 2;
      }
    } else {
      ddy += YGRAV;
    }

    // Bigger jump if holding space
    if (!TOPDOWN && holdingSpace) {
      if (jumpframes > 0) {
        jumpframes--;
        ddy -= 1;
      } else {
        // Clear impulse
        holdingSpace = false;
      }
    } else {
      jumpframes = 0;
    }

    if (holdingRight) {
      orientation = HORIZ;
      facingleft = false;
      if (og) {
        ddx += 0.7;
      } else {
        ddx += 0.4;
      }
    } else if (holdingLeft) {
      orientation = HORIZ;
      facingleft = true;
      if (og) {
        ddx -= 0.7;
      } else {
        ddx -= 0.4;
      }
    }

    if (TOPDOWN) {
      if (holdingUp) {
        orientation = VERT;
        if (og) {
          ddy -= 0.7;
        } else {
          ddy -= 0.4;
        }
      } else if (holdingDown) {
        orientation = VERT;
        if (og) {
          ddy += 0.7;
        } else {
          ddy += 0.4;
        }
      }
    }

    inair = !TOPDOWN && !og;

    // Apply friction if not holding any useful key.
    if (!holdingRight && !holdingLeft &&
        (!TOPDOWN || (!holdingUp && !holdingDown))) {
      if (og) {
        playerdx *= XGROUNDMU;
        playerdy *= YGROUNDMU;
      }
    }

    // Now changes in velocity.
    playerdx += ddx;
    playerdy += ddy;

    /*
    if (og && ! ) {
      playerdx *= XGROUNDMU;
    } else {
      playerdx *= XMU;
    }

    playerdy *= YMU;
    */

    // velocity caps...
    if (og) {
      if (playerdx > GTERMINALX) playerdx = GTERMINALX;
      if (playerdx < -GTERMINALX) playerdx = -GTERMINALX;
    } else {
      if (playerdx > TERMINALX) playerdx = TERMINALX;
      if (playerdx < -TERMINALX) playerdx = -TERMINALX;
    }
    if (playerdy > TERMINALY) playerdy = TERMINALY;
    if (playerdy < -TERMINALY) playerdy = -TERMINALY;

    // Now changes in position.
    var rx = playerx + playerdx + playerfx;

    var xobj = null;
    if (rx - playerx > 0) {
      xobj = trymovinghoriz(RIGHTFOOT,
                            playerx,
                            rx,
                            1,
                            playery + HEAD,
                            playery + FEET);
    } else if (rx - playerx < 0) {
      xobj = trymovinghoriz(LEFTFOOT,
                            playerx,
                            rx,
                            -1,
                            playery + HEAD,
                            playery + FEET);
    }
    if (xobj) {
      playerx = xobj.x;
      playerfx = xobj.fx;
      // Or small bounce?
      if (xobj.hit) playerdx = 0;
    } else {
      // playerx doesn't change.
      // we keep fx as is, too, as it was not consumed
      playerfx = 0;
    }

    var ry = playery + playerdy + playerfy;

    var yobj = null;
    if (ry - playery > 0) {
      yobj = trymovingvert(FEET,
                           playery,
                           ry,
                           1,
                           playerx + LEFTFOOT,
                           playerx + RIGHTFOOT);
    } else if (ry - playery < 0) {
      yobj = trymovingvert(HEAD,
                           playery,
                           ry,
                           -1,
                           // Like the feet on the top of your
                           // head.
                           playerx + LEFTFOOT,
                           playerx + RIGHTFOOT);
    }
    if (yobj) {
      playery = yobj.y;
      playerfy = yobj.fy;
      // Or small bounce if hitting head?
      if (yobj.hit) {
        playerdy = 0;
        // Can't keep jetpacking up if we hit our
        // head...
        jumpframes = 0;
        holdingSpace = false;
      }
    } else {
      // as above.
      playerfy = 0;
    }

    playerx = (playerx + GAMEW) % GAMEW;
    playery = (playery + GAMEH) % GAMEH;

    // same for fx?
    if (Math.abs(playerdx) < 0.01) playerdx = 0;
    if (Math.abs(playerdy) < 0.01) playerdy = 0;
  }

  public function getPlayerActionBlock(width, depth) {
    // Get action brick first...
    var ty, tx;
    // probably no punching up though.
    var d = NONE;
    if (holdingDown) {
      ty = Math.floor((playery + FEET + depth) / BLOCKW);
      ty = (ty + TILESH) % TILESH;
      tx = Math.floor((playerx + (facingleft ? LEFTFOOT : RIGHTFOOT)) /
                      BLOCKW);
      tx = (tx + TILESW) % TILESW;
      d = VERT;
    } else {

      ty = Math.floor((playery + CENTER) / BLOCKW);
      ty = (ty + TILESH) % TILESH;
      if (facingleft) {
        tx = Math.floor((playerx + LEFTFOOT - width) / BLOCKW);
        tx = (tx + TILESW) % TILESW;
        var b = grid[ty * TILESW + tx];
      } else {
        tx = Math.floor((playerx + RIGHTFOOT + width) / BLOCKW);
        tx = (tx + TILESW) % TILESW;
      }
      d = HORIZ;
    }
    return { x: tx, y: ty, d: d };
  }

  public function playerActions() {
    if (holdingZ) {
      var t = getPlayerActionBlock(PUNCHW, PUNCHD);
      var b = grid[t.y * TILESW + t.x];

      if (b != null) {
        punchBlock(t.x, t.y);
      }
      holdingZ = false;
    } else if (holdingX) {
      var t = getPlayerActionBlock(CREATEW, CREATED);
      var b = grid[t.y * TILESW + t.x];

      if (b == null) {
        // Create block here.
        var newb = { what: (t.d == VERT) ? BBLUE : BRED,
                     dir: t.d, len: 1,
                     shrink1: 0, shrink2: 0,
                     x: t.x, y: t.y };
        grid[t.y * TILESW + t.x] = newb;
        blocks.push(newb);
      } else {
        // Block grows.
        if (b.dir == VERT) {
          // only down
          growDown(b);
        } else if (b.dir == HORIZ) {
          if (facingleft) {
            growLeft(b);
          } else {
            growRight(b);
          }
        }
      }
    }

  }

  // turns the whole thing into broken.
  // TODO: consider breaking a piece out of long ones.
  public function punchBlock(tx, ty) {
    var b = grid[ty * TILESW + tx];

    // Not allowed to reset break timer, or smash
    // spikes.
    if (b.what == BBREAK || b.what == BSPIKE)
      return;

    if (b.dir == NONE) {
      b.what = BBREAK;
      b.frames = BREAKFRAMES;
    } else if (b.dir == HORIZ) {
      deleteBlock(b);
      for (var x = 0; x < b.len; x++) {
        var xx = (b.x + x) % TILESW;
        var newb = { x: xx, y: b.y,
                     dir: NONE, len: 1,
                     what: BBREAK,
                     frames: BREAKFRAMES,
                     shrink1: 0, shrink2: 0 };
        grid[b.y * TILESW + xx] = newb;
        blocks.push(newb);
      }
    } else if (b.dir == VERT) {
      deleteBlock(b);
      for (var y = 0; y < b.len; y++) {
        var yy = (b.y + y) % TILESH;
        var newb = { x: b.x, y: yy,
                     dir: NONE, len: 1,
                     what: BBREAK,
                     frames: BREAKFRAMES,
                     shrink1: 0, shrink2: 0 };
        grid[yy * TILESW + b.x] = newb;
        blocks.push(newb);
      }
    }
  }

  // remove block at tx, ty from array. Doesn't
  // mess up b itself, though it will be disconnected
  // unless you keep ahold of it
  public function deleteBlock(b) {
    // First, swap to end of blocks array so we can
    // easily delete it.
    var last = blocks.length - 1;
    // Don't go all the way to last, in case it's already there
    for (var i = 0; i < last; i++) {
      if (blocks[i] == b) {
        blocks[i] = blocks[last];
        blocks[last] = b;
        break;
      }
    }

    // Now we can assume it's at the last index (#last) in the
    // array.

    if (b.dir == NONE) {
      grid[b.y * TILESW + b.x] = null;
    } else if (b.dir == HORIZ) {
      for (var x = 0; x < b.len; x++) {
        var xx = (b.x + x) % TILESW;
        grid[b.y * TILESW + xx] = null;
      }
    } else if (b.dir == VERT) {
      for (var y = 0; y < b.len; y++) {
        var yy = (b.y + y) % TILESH;
        grid[yy * TILESW + b.x] = null;
      }
    }

    // Get rid of it now.
    blocks.pop();
  }

  public function playJumpSound() {
    var NJUMP = 4;
    var j = new Sound(sfxmc);
    var idx = (int(Math.random() * 1000)) % NJUMP;
    j.attachSound('jump' + (idx + 1) + '.wav');
    j.setVolume(30);
    j.start(0, 1);
  }

  public function playCrySound() {
    var cry = new Sound(sfxmc);
    cry.attachSound('cry2.wav');
    cry.setVolume(75);
    cry.start(0, 1);
  }

  public function playGetSound() {
    var got = new Sound(sfxmc);
    got.attachSound('get.wav');
    got.setVolume(75);
    got.start(0, 1);
  }

  public function playBreatheSound() {
    var cry = new Sound(sfxmc);
    cry.attachSound('breathing.wav');
    cry.setVolume(45);
    cry.start(0, 1);
  }

  public function init() {
    trace('init game');

    var animframe = 0;
    var facingleft = true;
    var inair = false;
    var orientation = LEFT;
    var screamframes = 0;
    var suffocating = false;
    var suffocateframes = 0;
    air = [];
    airea = 0;
    framesenclosed = 0;
    points = [];
    framesinpoint = 0;
    framesdisplayed = 0;
    playerdx = 0;
    playerdy = 0;
    playerfx = 0;
    playerfy = 0;

    sfxmc = createMovieAtDepth('sfx', SFXDEPTH);

    blocksbm = loadBitmap2x('blocks.png');
    barbm = loadBitmap2x('bar.png');
    playerbmr =
      { stand: loadBitmap2x('player.png'),
        jump: loadBitmap2x('playerjump.png'),
        cry1: loadBitmap2x('playercry1.png'),
        run1: loadBitmap2x('playerrun1.png'),
        run2: loadBitmap2x('playerrun2.png'),
        run3: loadBitmap2x('playerrun3.png') };

    playerbml = flipAllHoriz(playerbmr);

    blockbms = [];

    // Cut it up into the bitmaps.
    var NVARIATIONS = 4;
    for (var i = 0; i < NBLOCKS; i++) {
      blockbms.push([]);
      for (var a = 0; a < NVARIATIONS; a++) {
        // Just shift the whole graphic so that only
        // the desired block shows.
        var cropbig = new Matrix();
        cropbig.translate(-BLOCKW * SCALE * i, -BLOCKH * SCALE * a);
        var b = new BitmapData(BLOCKW * SCALE, BLOCKH * SCALE, true, 0);
        b.draw(blocksbm, cropbig);
        blockbms[i].push(b);
      }
    }

    // Create faded version of points and icons.
    for (var i = 0; i < NPOINTS; i++) {
      blockbms[B0 + i][DARK] =
        darkenWhite(blockbms[B0 + i][NORMAL]);
      blockbms[B0 + i][DARKICONS] =
        darkenWhite(blockbms[B0 + i][ICONS]);
    }

    gamebm = new BitmapData(BLOCKW * SCALE * TILESW,
                            BLOCKW * SCALE * TILESH,
                            true, 0);
    _root.gamemc = createGlobalMC('game', gamebm, GAMEDEPTH);
    _root.gamemc._x = BOARDX * SCALE;
    _root.gamemc._y = BOARDY * SCALE;

    timerbm = new BitmapData(BLOCKW * SCALE * TILESW,
                             BLOCKW * SCALE * TILESH,
                             true, 0);
    _root.timermc = createGlobalMC('timer', timerbm, TIMERDEPTH);
    _root.timermc._x = TIMERX * SCALE;
    _root.timermc._y = TIMERY * SCALE;

    pointsbm = new BitmapData(BLOCKW * SCALE * TILESW,
                              BLOCKW * SCALE * TILESH,
                              true, 0);
    _root.pointsmc = createGlobalMC('points', pointsbm, POINTSDEPTH);
    _root.pointsmc._x = POINTSX * SCALE;
    _root.pointsmc._y = POINTSY * SCALE;

    backgroundbm = loadBitmap2x('background.png');
    _root.backgroundmc = createGlobalMC('bg', backgroundbm, BGIMAGEDEPTH);
    _root.backgroundmc._x = 0;
    _root.backgroundmc._y = 0;

    // _root.playermc = createMovieAtDepth('player', PLAYERDEPTH);

    info = new Info();
    info.init();

    // info.setMessage("You are now playing.");

    airfo = new Airfo();
    airfo.init();
    airfo.hide();

    initboard();
    initpoints();

    // XXX find safe spot for player
    playerx = Math.floor(GAMEW / 2);
    playery = Math.floor(GAMEH / 2);

    dead = false;

    // _root.pucksmc = createMovieAtDepth('ps', PUCKSOUNDDEPTH);

    // redraw();
    starttime = (new Date()).getTime();
  }

  // Called for both b[width - 1] and (logically) b[-1],
  // since the cap has width.
  public function hstartcap(b, bx) {
    var capm = new Matrix();
    var xx = (bx * BLOCKW + b.shrink1) * SCALE;
    var yy = b.y * BLOCKW * SCALE;
    capm.translate(xx, yy);
    var capc = new Rectangle(xx, yy,
                             CAPW * SCALE, BLOCKH * SCALE);
    gamebm.draw(blockbms[b.what][NORMAL], capm, null, null, capc);
  }

  public function hendcap(b, bx) {
    var capm = new Matrix();
    var solid = BLOCKW - b.shrink2;
    // Where we want to draw the end cap.
    var capxx = (bx * BLOCKW + solid - CAPW) * SCALE;
    var capyy = b.y * BLOCKW * SCALE;

    capm.translate(capxx - (BLOCKW - CAPW) * SCALE, capyy);
    var capc = new Rectangle(capxx, capyy,
                             CAPW * SCALE, BLOCKH * SCALE);
    gamebm.draw(blockbms[b.what][NORMAL], capm, null, null, capc);
  }

  public function vstartcap(b, by) {
    var capm = new Matrix();
    var xx = b.x * BLOCKW * SCALE;
    var yy = (by * BLOCKH + b.shrink1) * SCALE;
    capm.translate(xx, yy);
    var capc = new Rectangle(xx, yy,
                             BLOCKW * SCALE, CAPW * SCALE);
    gamebm.draw(blockbms[b.what][NORMAL], capm, null, null, capc);
  }

  public function vendcap(b, by) {
    var capm = new Matrix();
    var solid = BLOCKH - b.shrink2;
    // Where we want to draw the end cap.
    var capxx = b.x * BLOCKW * SCALE;
    var capyy = (by * BLOCKH + solid - CAPW) * SCALE;

    capm.translate(capxx, capyy - (BLOCKH - CAPW) * SCALE);
    var capc = new Rectangle(capxx, capyy,
                             BLOCKW * SCALE, CAPW * SCALE);
    gamebm.draw(blockbms[b.what][NORMAL], capm, null, null, capc);
  }

  public function drawtimer() {
    clearBitmap(timerbm);
    var frac = framesinpoint / (10 * FPS);
    var skipfrac = 1.0 - frac;
    var skippixels = int(skipfrac * TIMERW);
    var keeppixels = TIMERW - skippixels;

    var m = new Matrix();
    m.translate(0, 0);
    var c = new Rectangle(skippixels * SCALE, 0,
                          keeppixels * SCALE, TIMERH * SCALE);
    timerbm.draw(barbm, m, null, null, c);
  }

  public function drawpoints() {
    // Remember, current point is at the head of the list.
    var nshow = Math.min(points.length, TILESW - 2);
    var starttx = TILESW - nshow;
    clearBitmap(pointsbm);
    for (var i = 0; i < nshow; i++) {
      var top = (i == 0) ? NORMAL : DARK;
      var bot = (i == 0) ? ICONS : DARKICONS;
      var m = new Matrix();
      var x2x = ((starttx + i) * BLOCKW) * SCALE;
      m.translate(x2x, 0);
      pointsbm.draw(blockbms[B0 + points[i]][top], m);
      var mi = new Matrix();
      mi.translate(x2x, (BLOCKH - POINTSOVERLAP) * SCALE);
      pointsbm.draw(blockbms[B0 + points[i]][bot], mi);
    }
    // XXX show arrow?
    // XXX show ellipses
  }

  public function redraw() {
    // initboard();

    info.redraw();

    var total_ms = (new Date()).getTime() - starttime;
    var total_s = total_ms / 1000.0;
    var computed_fps = framesdisplayed / total_s;
    // info.setMessage('FPS ' + computed_fps);

    /*
    info.setMessage('dx: ' + toDecimal(playerdx, 1000) +
                    ' dy: ' + toDecimal(playerdy, 1000) +
                    ' fx: ' + toDecimal(playerfx, 1000) +
                    ' fy: ' + toDecimal(playerfy, 1000));
    */

    /*
    var breath = framesenclosed / FRAMESPERAIR;

    info.setMessage(// 'arrow keys, space, z, x. airea: ' +
                    'FPS ' + toDecimal(computed_fps, 100)
                    + ' ' + toDecimal(breath, 10) + '/' +
                    airea);
    */

    drawtimer();
    // PERF don't need to do this every frame!
    drawpoints();

    // debug mode showing mask?

    // redraw the tile bitmap. This is already positioned
    // in the right place so that 0,0 is actually the start
    // of the game area.
    clearBitmap(gamebm);
    drawBlocks();

    // Also show if almost out?
    if (true || /* CHEATS || */
        points[0] == PTHINK ||
        points[0] == PHURT) {
      drawAir();
    }

    // Now draw player.
    // When player is wrapping around screen, need
    // to draw up to 4 playermcs...
    // TODO: Consider placing on odd screen pixels?
    var pobj = facingleft ? playerbml : playerbmr;

    // assumes 0 <= playerx < width etc.
    var xx = playerx - PLAYERLAPX;
    var yy = playery - PLAYERLAPY;

    var pbm = pobj.stand;
    if (screamframes > 0) {
      screamframes--;
      // XXX animate
      pbm = pobj.cry1;
    } else if (inair) {
      pbm = pobj.jump;
    } else if (Math.abs(playerdx) >= 1) {
      pbm = pobj[['run1', 'run2',
                  'run3', 'run2'][Math.round(animframe / 2) % 4]];
    }

    // PERF could compute that some of these are impossible,
    // but native clipping code is perhaps faster than any
    // logic we could do
    drawAt(gamebm, pbm, xx, yy);
    drawAt(gamebm, pbm, xx - GAMEW, yy);
    drawAt(gamebm, pbm, xx, yy - GAMEH);
    drawAt(gamebm, pbm, xx - GAMEW, yy - GAMEH);

    // just leave at depth.
    // setDepthOf(_root.rinkmc, iceDepth(playery));

  }

  public function checkSpikes() {
    // player's head
    var ty = Math.floor((playery + CENTER) / BLOCKW);
    ty = (ty + TILESH) % TILESH;
    var tx = Math.floor((playerx + CENTER) / BLOCKW);
    tx = (tx + TILESW) % TILESW;

    var b = grid[ty * TILESW + tx];
    if (b != null && b.what == BSPIKE) {
      playCrySound();
      dead = true;
      screamframes = 45;
    }
  }

  public function checkPickup() {
    // player's head
    var ty = Math.floor((playery + CENTER) / BLOCKW);
    ty = (ty + TILESH) % TILESH;
    var tx = Math.floor((playerx + CENTER) / BLOCKW);
    tx = (tx + TILESW) % TILESW;

    var idx = ty * TILESW + tx;
    var b = grid[idx];
    if (b != null && b.what >= B0 && b.what <= B9) {
      playGetSound();
      // Goes next.
      var p = b.what - B0;
      var cur = points.shift();
      points.unshift(p);
      points.unshift(cur);
      deleteBlock(b);
    }
  }

  public function oneBreatheHole(tx, ty) {
    var b = grid[ty * TILESW + tx];
    if (b == null) {
      return {x: tx, y: ty};
    } else if (b.dir == HORIZ) {
      if (b.shrink1 > 0 && b.x == tx) {
        var txx = (tx - 1 + TILESW) % TILESW;
        if (grid[ty * TILESW + txx] == null) return {x: txx, y: ty};
      } else if (b.shrink2 > 0) {
        var blast = (b.x + b.len - 1 + TILESW) % TILESW;
        if (blast == tx) {
          var txx = (tx + 1 + TILESW) % TILESW;
          if (grid[ty * TILESW + txx] == null) return {x: txx, y: ty};
        }
      }
    } else if (b.dir == VERT) {
      if (b.shrink1 > 0 && b.y == ty) {
        var tyy = (ty - 1 + TILESH) % TILESH;
        if (grid[tyy * TILESW + tx] == null) return {x: tx, y: tyy};
      } else if (b.shrink2 > 0) {
        var blast = (b.y + b.len - 1 + TILESH) % TILESH;
        if (blast == ty) {
          var tyy = (ty + 1 + TILESH) % TILESH;
          if (grid[tyy * TILESW + tx] == null) return {x: tx, y: tyy};
        }
      }
    }
    return null;
  }

  // Pick a breathing hole that is advantageous to the player.
  // That way, being momentarily stuck in a shrunk block doesn't
  // kill you if you have air right next to that.
  public function getBreatheHole() {
    // player's head

    var tx, ty;
    var a = [{x: playerx + LEFTFOOT + 1, y: playery + HEAD},
             {x: playerx + LEFTFOOT + 1, y: playery + FEET - 1},
             {x: playerx + RIGHTFOOT - 1, y: playery + HEAD},
             {x: playerx + RIGHTFOOT - 1, y: playery + FEET - 1}]
    for (var i = 0; i < a.length; i++) {
      ty = Math.floor(a[i].y / BLOCKH);
      ty = (ty + TILESH) % TILESH;
      tx = Math.floor(a[i].x / BLOCKW);
      tx = (tx + TILESW) % TILESW;
      var ob = oneBreatheHole(tx, ty);
      if (ob) return ob;
    }

    // Then anything, and we're gonna be toast...
    return {x: tx, y: ty};
  }

  public function computeAir() {
    air = [];

    var ob = getBreatheHole();
    var tx = ob.x;
    var ty = ob.y;

    airea = 0;
    var todo = [{x:tx, y:ty}];
    while (todo.length > 0) {
      var n = todo.pop();
      if (n.x < 0 || n.y < 0 ||
          n.x >= TILESW || n.y >= TILESH) {
        // Connected to outdoors. Done.
        air = [];
        airea = -1;
        framesenclosed = 0;
        if (suffocating) {
          airframes = 20;
        }
        return;
      }
      var idx = n.y * TILESW + n.x;
      if (air[idx] == undefined) {
        if (grid[idx] == null) {
          // open spot
          todo.push({x: n.x + 1, y: n.y});
          todo.push({x: n.x - 1, y: n.y});
          todo.push({x: n.x, y: n.y + 1});
          todo.push({x: n.x, y: n.y - 1});
          airea++;
          air[idx] = 1;
        } else {
          air[idx] = 2;
        }
      }
      // (otherwise we've already done it.)
    }

    // Didn't escape..
    if (points[0] != PTHINK) {
      framesenclosed++;
    }
  }

  private function bAir(x, y) {
    var yy = (y + TILESH) % TILESH;
    var xx = (x + TILESW) % TILESW;
    // trace('wa ' + xx + '/' + yy);
    return grid[yy * TILESW + xx] != null;
  };

  public function drawAir() {
    // Air info.
    if (airea == -1) {
      if (airframes > 0) {
        airfo.setMessage('air: @#');
        airfo.show();
        airfo.position(playerx - 6, playery - 16);
        airframes--;
      } else {
        airfo.hide();
      }
    }

    if (airea == -1)
      return;

    if (suffocating) {
      var breath = framesenclosed / FRAMESPERAIR;
      var f = 1.0 - (breath / airea);
      if (f < 0) f = 0;
      if (f > 1) f = 1;
      var pct = Math.round(f * 10);
      if (!isNaN(pct)) {
        airfo.setMessage('air: ' + pct + '0%');
        // XXX I think it would look better along the
        // air boundary?
        airfo.position(playerx - 6, playery - 16);
        airfo.show();
      } else {
        airfo.hide();
      }
    } else {
      airfo.hide();
    }

    var airbms = blockbms[BAIRBORDER];
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        var idx = y * TILESW + x;
        if (air[idx] == 1) {
          var px = x * BLOCKW;
          var py = y * BLOCKH;

          if (bAir(x + 1, y)) {
            drawAtClip(gamebm, airbms[VSMOOTH],
                       BLOCKW - 3, 0,
                       px + BLOCKW - 3, py,
                       3, BLOCKH);
          }

          if (bAir(x - 1, y)) {
            drawAtClip(gamebm, airbms[VSMOOTH],
                       0, 0, px, py, 2, BLOCKH);
          }

          if (bAir(x, y - 1)) {
            drawAtClip(gamebm, airbms[HSMOOTH],
                       0, 0, px, py,
                       BLOCKW, 2);
          }

          if (bAir(x, y + 1)) {
            drawAtClip(gamebm, airbms[HSMOOTH],
                       0, BLOCKH - 3,
                       px, py + BLOCKH - 3,
                       BLOCKW, 3);
          }

          // TODO outside corners, easy
        }
      }
    }
  }

  public function drawAtClip(dest, bm,
                             srcx, srcy,
                             dstx, dsty,
                             w, h) {
    var m = new Matrix();
    m.translate((dstx - srcx) * SCALE,
                (dsty - srcy) * SCALE);
    var c = new Rectangle(dstx * SCALE, dsty * SCALE,
                          w * SCALE, h * SCALE);
    dest.draw(bm, m, null, null, c);
  }

  public function drawBlocks() {
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      // trace(b.what);

      // XXX don't use for 1x1 that's falling. It blinks
      // into a different appearance, which looks bad.
      if (b.dir == NONE || b.len == 1) {
        // common, assumed 1x1. can't have shrinkage.
        var place = new Matrix();
        place.translate(b.x * BLOCKW * SCALE,
                        b.y * BLOCKW * SCALE);

        if (b.what == BBREAK) {
          var frac = (BREAKFRAMES - b.frames) / BREAKFRAMES;
          var fm = Math.round(frac * (NBREAKANIM - 1));
          gamebm.draw(blockbms[BBREAK][fm], place);
        } else {
          gamebm.draw(blockbms[b.what][NORMAL], place);
        }

      } else if (b.dir == HORIZ) {

        // Draw midsection using smoothie.
        for (var x = 1; x < b.len - 1; x++) {
          var place = new Matrix();
          var sx = (b.x + x) % TILESW;
          place.translate(sx * BLOCKW * SCALE,
                          b.y * BLOCKW * SCALE);

          gamebm.draw(blockbms[b.what][HSMOOTH], place);
        }

        // And gap...
        // (this only needs to be drawn once, because in the case
        // where the cap wraps, the gap is empty.)
        var gapm = new Matrix();
        var xdone = b.shrink1 + CAPW;
        var xx = (b.x * BLOCKW + xdone) * SCALE;
        var yy = b.y * BLOCKW * SCALE;
        gapm.translate(xx, yy);
        var gapc = new Rectangle(xx, yy, (BLOCKW - xdone) * SCALE,
                                 BLOCKH * SCALE);
        gamebm.draw(blockbms[b.what][HSMOOTH], gapm, null, null, gapc);

        // And end cap...
        // Position of last block.
        // var bx = (b.x + b.len - 1) % TILESW;
        var blast = (b.x + b.len - 1) % TILESW;

        var gapm = new Matrix();
        var xneed = (BLOCKW - b.shrink2) - CAPW;
        if (xneed > 0) {
          var xx = (blast * BLOCKW) * SCALE;
          var yy = b.y * BLOCKW * SCALE;
          gapm.translate(xx, yy);
          var gapc = new Rectangle(xx, yy,
                                   xneed * SCALE,
                                   BLOCKH * SCALE);
          gamebm.draw(blockbms[b.what][HSMOOTH], gapm, null, null, gapc);
        }

        // Caps last, since for short segments, gaps could overlap
        // overlapping caps.

        // Now draw start cap, clipped.
        hstartcap(b, b.x);
        if (b.x == TILESW - 1) {
          hstartcap(b, -1);
        }

        hendcap(b, blast);
        if (blast == 0) {
          hendcap(b, TILESW);
        }

      } else if (b.dir == VERT) {

        // Draw midsection using smoothie.
        for (var y = 1; y < b.len - 1; y++) {
          var place = new Matrix();
          var sy = (b.y + y) % TILESH;
          place.translate(b.x * BLOCKW * SCALE,
                          sy * BLOCKH * SCALE);

          gamebm.draw(blockbms[b.what][VSMOOTH], place);
        }

        var blast = (b.y + b.len - 1) % TILESH;


        // And gap...
        // (this only needs to be drawn once, because in the case
        // where the cap wraps, the gap is empty.)
        var gapm = new Matrix();
        var ydone = b.shrink1 + CAPW;
        var xx = b.x * BLOCKW * SCALE;
        var yy = (b.y * BLOCKH + ydone) * SCALE;
        gapm.translate(xx, yy);
        var gapc = new Rectangle(xx, yy,
                                 BLOCKW * SCALE,
                                 (BLOCKH - ydone) * SCALE);
        gamebm.draw(blockbms[b.what][VSMOOTH], gapm, null, null, gapc);

        // And end cap...
        // Position of last block.
        var gapm = new Matrix();
        var yneed = (BLOCKH - b.shrink2) - CAPW;
        if (yneed > 0) {
          var xx = b.x * BLOCKW * SCALE;
          var yy = (blast * BLOCKH) * SCALE;
          gapm.translate(xx, yy);
          var gapc = new Rectangle(xx, yy,
                                   BLOCKW * SCALE,
                                   yneed * SCALE);
          gamebm.draw(blockbms[b.what][VSMOOTH], gapm, null, null, gapc);
        }

        // Caps last, since for short segments, gaps could overlap
        // overlapping caps.

        // Now draw start cap, clipped.
        vstartcap(b, b.y);
        if (b.y == TILESH - 1) {
          vstartcap(b, -1);
        }

        vendcap(b, blast);
        if (blast == 0) {
          vendcap(b, TILESH);
        }

      }

    }
  }

  // Takes game pixels x,y
  public function drawAt(dest, bm, x, y) {
    var m = new Matrix();
    m.translate(x * SCALE, y * SCALE);
    dest.draw(bm, m);
  }

  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
    case 49:
      if (CHEATS) {
        stopmusic();
        initpoints();
        initboard();
      }
      break;
    case 50:
      if (CHEATS) {
        stopmusic();
        framesinpoint = 10;
      }
      break;
    case 192: // ~
    case 27: // esc
      holdingEsc = true;
      break;
    case 90: // z
      holdingZ = true;
      break;
    case 88: // x
      if (allowX) {
        holdingX = true;
      }
      break;
    case 32:
      holdingSpace = true;
      break;
    case 38:
      holdingUp = true;
      break;
    case 37:
      holdingLeft = true;
      break;
    case 39:
      holdingRight = true;
      break;
    case 40:
      holdingDown = true;
      break;
    }
  }

  public function onKeyUp() {
    var k = Key.getCode();
    switch(k) {
    case 192: // ~
    case 27: // esc
      holdingEsc = false;
      break;
    case 90: // z
      holdingZ = false;
      break;
    case 88: // x
      holdingX = false;
      allowX = true;
      break;
    case 32:
      holdingSpace = false;
      break;
    case 38:
      holdingUp = false;
      break;
    case 37:
      holdingLeft = false;
      break;
    case 39:
      holdingRight = false;
      break;
    case 40:
      holdingDown = false;
      break;
    }
  }

}
