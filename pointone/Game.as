import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;

class Game extends MovieClip {

  #include "constants.js"
  #include "util.js"

  // Nominal FPS. Must match timeline setting.
  var FPS = 30;

  var backgroundbm : BitmapData = null;
  // All block sprites.
  var blocksbm : BitmapData = null;

  // All player sprites.
  var playerbm : BitmapData = null;
  var playerbml : BitmapData = null;

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

  var holdingSpace = false;
  var holdingZ = false;
  var allowX = true;
  var holdingX = false;
  var holdingUp = false;
  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;
  var holdingEsc = false;

  // Global animation offset. Resets to stay integral
  // and reasonably small.
  var animframe = 0;
  // Which way is the player facing?
  var facingleft = true;

  // Size TILESW * TILESH.
  // Each cell points to a block or null.
  var grid = [];
  // All the blocks currently around.
  var blocks = [];

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
    points = [1];
    for (var i = 0; i < 20; i++) {
      var p = Math.round(Math.random() * (NPOINTS - 1));
      if (p == 1) p = 9;
      points.unshift(p);
    }
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
	      what = int((Math.random() * 1000) % NBLOCKS);
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

  public function onLoad() {
    Key.addListener(this);
    init();
  }

  /*
  public function playCutsceneSound(wav, times) {
    var oof = new Sound(_root.cutscenesmc);
    trace(wav);
    oof.attachSound(wav);
    oof.setVolume(100);
    oof.start(0, times);
  }
  */

  public function growBlocks() {
    var parity = (framesinpoint % 2) == 0;

    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      if (b.dir == HORIZ) {

	if (parity) {
	  // even parity. grow left
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
	} else {
	  // odd parity. grow right...
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
	  if (b.shrink2 > 0) {
	    b.shrink2--;
	  } else {
	    // Try expanding length;
	    var nblast = (b.y + b.len + TILESH) % TILESH;
	    if (grid[nblast * TILESW + b.x] == null) {
	      b.len++;
	      grid[nblast * TILESW + b.x] = b;
	      b.shrink2 = 15;
	    }
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
      if (b.dir == VERT) {
	  
	var nblast = (b.y + b.len + TILESH) % TILESH;
	// Can fall if below us is clear; it's always safe
	// to shrink from the top if we're extending at the
	//s ame time.
	var canfall = b.shrink2 > 0 ||
	  grid[nblast * TILESW + b.x] == null;

	if (canfall) {
	  // OK, grow down.
	  if (b.shrink2 > 0) {
	    b.shrink2--;
	  } else {
	    // We already know we have room.
	    b.len++;
	    grid[nblast * TILESW + b.x] = b;
	    b.shrink2 = 15;
	  }

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

  public function blockPhysics() {

    // Growth.
    if (points[0] == PGROWTH) {
      growBlocks();
    }

    if (points[0] == PFALL) {
      fallBlocks();
    }

  }

  public function onEnterFrame() {
    framesdisplayed++;
    animframe++;
    if (animframe > 1000000) animframe = 0;

    // XXX off by one?
    if (framesinpoint == 0) {
      nextpoint();
    } else {
      framesinpoint--;
    }

    playerPhysics();
    
    blockPhysics();

    redraw();
  }

  public function nextpoint() {
    points.shift();
    framesinpoint = 10 * FPS;

    // because not implemented end of game
    if (points.length > 0) {
      switchMusic(points[0]);
    }
  }

  // This is for testing pixel-level physics like the player
  // clipping and some effects (e.g. stars, if I do that).
  public function pixelIsSolid(px, py) {
    // Wrap around physics...
    px = px % GAMEW;
    py = (py + 1) % GAMEH;

    var tx = Math.floor(px / BLOCKW);
    var ty = Math.floor(py / BLOCKH);
    
    var b = grid[ty * TILESW + tx];
    if (!b) return false;
    
    // Not sure if B* should count as solid for jumping?
    // Probably not..

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

  public function playerPhysics() {
    var YGRAV = 0.48;
    var XGRAV = 0;
    var XMU = 0.9;
    var XGROUNDMU = 0.7;
    var YMU = 0.9;

    var TERMINALX = 6;
    var TERMINALY = 7;

    var GTERMINALX = 4.5;

    var ddy = 0;
    // XXX same on-ground treatment for xgrav?
    var ddx = XGRAV;

    var og = onGround();

    // First, changes in acceleration.
    if (og) {
      if (holdingSpace) {
	ddy -= 7;
      }
    } else {
      ddy += YGRAV;
    }

    if (holdingRight) {
      if (og) {
	facingleft = false;
	ddx += 0.7;
      } else {
	ddx += 0.4;
      }
    } else if (holdingLeft) {
      if (og) {
	facingleft = true;
	ddx -= 0.7;
      } else {
	ddx -= 0.4;
      }
    } else if (og) {
      playerdx *= XGROUNDMU;
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
      if (yobj.hit) playerdy = 0;
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

  /*
  public function playHurtSound(player, damage) {
    // XXX replace clip?
    // trace(player.smc);
    var oof = new Sound(player.smc);
    var idx = (int(Math.random() * 1000)) % NHURT;
    oof.attachSound('hurt' + (idx + 1) + '.wav');
    // oof.attachSound('hurt1.wav');
    setSoundVolume(player.x, player.y, oof, 75);
    oof.start(0, 1);
  }

  public function setSoundVolume(x, y, sound, maxvol) {
    // As distance from center of screen
    // Maybe should base this on the player cursor?
    var cx = (scrollx + SCREENW/2) - x;
    var cy = (scrolly + SCREENH/2) - y;

    // in pixels
    var dx = Math.sqrt(cx * cx + cy * cy);

    // fraction between 0 and 1, 0 loudest
    var fade = dx / SCREENW*1.3;
    if (fade < 0.05) fade = 0.05;
    if (fade > 0.95) fade = 0.95;

    fade = 1.0 - fade;

    // trace('fade ' + fade + ' = ' + (80 * fade));
    sound.setVolume(maxvol * fade);

    // in [-1, 1]
    var p = -cx / (SCREENW/2);
    if (p > 0.90) p = 0.90;
    if (p < -0.90) p = -0.90;

    // Very hard to follow the sounds if panning too much.
    sound.setPan(p * 10);
  }
  */

  public function init() {
    trace('init game');

    blocksbm = loadBitmap2x('blocks.png');    
    playerbm = loadBitmap2x('player.png');
    barbm = loadBitmap2x('bar.png');
    playerbml = flipHoriz(playerbm);

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

    info.setMessage("You are now playing.");

    initboard();
    initpoints();

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
    info.setMessage('dx: ' + toDecimal(playerdx, 1000) + 
		    ' dy: ' + toDecimal(playerdy, 1000) +
		    ' fx: ' + toDecimal(playerfx, 1000) +
		    ' fy: ' + toDecimal(playerfy, 1000));

    drawtimer();
    // PERF don't need to do this every frame!
    drawpoints();

    // XXX debug mode showing mask

    // redraw the tile bitmap. This is already positioned
    // in the right place so that 0,0 is actually the start
    // of the game area.
    clearBitmap(gamebm);
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      // trace(b.what);
      if (b.dir == NONE || b.len == 1) {
	// common, assumed 1x1. can't have shrinkage.
	var place = new Matrix();
	place.translate(b.x * BLOCKW * SCALE,
			b.y * BLOCKW * SCALE);

	gamebm.draw(blockbms[b.what][NORMAL], place);

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


    // Now draw player.
    // When player is wrapping around screen, need
    // to draw up to 4 playermcs...
    // TODO: Consider placing on odd screen pixels?
    // _root.playermc._x = (BOARDX + playerx - PLAYERLAPX) * SCALE;
    // _root.playermc._y = (BOARDY + playery - PLAYERLAPY) * SCALE;
    // XXX animate.
    // XXX PERF this replaces the bitmap right?

    // assumes 0 <= playerx < width etc.
    var pbm = facingleft ? playerbml : playerbm;
    var xx = playerx - PLAYERLAPX;
    var yy = playery - PLAYERLAPY;
    
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

  // Takes game pixels x,y
  public function drawAt(dest, bm, x, y) {
    var m = new Matrix();
    m.translate(x * SCALE, y * SCALE);
    dest.draw(bm, m);
  }

  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
    case 192: // ~
    case 27: // esc
      holdingEsc = true;
      break;
    case 90: // z
      initpoints();
      initboard();
      holdingZ = true;
      break;
    case 88: // x
      framesinpoint = 10;
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
