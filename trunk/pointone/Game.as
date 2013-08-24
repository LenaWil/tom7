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

  // Bitmap data for each block.
  var blockbms = [];

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

  // Size TILESW * TILESH.
  // Each cell points to a block or null.
  var grid = [];
  // All the blocks currently around.
  var blocks = [];

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

  public function initboard() {
    blocks = [];
    grid = [];

    // XXX Terrible unfun level generator!
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
	if (Math.random() < 0.2) {
	  var what = 0;
	  if (Math.random() < 0.8) {
	    what = int((Math.random() * 1000) % NREG);
	  } else {
	    what = int((Math.random() * 1000) % NBLOCKS);
	  }
	  
	  var d = NONE;
	  if (what == BVERT) d = VERT;
	  else if (what == BHORIZ) d = HORIZ;

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
  }


  var backgroundclip = null;
  var backgroundmusic = null;
  public function setMusic(m) {

    trace('switch music ' + m);
    // Does this leak??
    backgroundclip = createMovieAtDepth('bgm', BGMUSICDEPTH);
    backgroundmusic = new Sound(backgroundclip);
    if (MUSIC) {
      backgroundmusic.attachSound(m);
      backgroundmusic.setVolume(100);
      backgroundmusic.start(0, 99999);
    }
  }

  public function onLoad() {
    Key.addListener(this);
    init();
  }

  public function playCutsceneSound(wav, times) {
    var oof = new Sound(_root.cutscenesmc);
    trace(wav);
    oof.attachSound(wav);
    oof.setVolume(100);
    oof.start(0, times);
  }

  public function onEnterFrame() {
    framesdisplayed++;
    animframe++;
    if (animframe > 1000000) animframe = 0;

    playerPhysics();

    redraw();
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
    
    // Assume all blocks are solid for now.
    if (b.dir == HORIZ) {
      // Then if it's the first or last block, we need
      // to test the shrinkage.
      var xoff = px - tx * BLOCKW;
      if (tx == b.x) {
	return xoff >= b.shrink1;
      } else if (tx == b.x + b.len) {
	// Number of solid pixels.
	var solid = BLOCKW - b.shrink2;
	return xoff < solid;
      }

      return true;
    } else if (b.dir == VERT) {
      var yoff = py - ty * BLOCKH;
      if (ty == b.y) {
	return yoff >= b.shrink1;
      } else if (ty == b.y + b.len) {
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
	ddx += 0.7;
      } else {
	ddx += 0.4;
      }
    } else if (holdingLeft) {
      if (og) {
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

    // XXX terminal velocity...
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
    playerbml = flipHoriz(playerbm);

    // Cut it up into the bitmaps.
    for (var i = 0; i < NBLOCKS; i++) {
      // Just shift the whole graphic so that only
      // the desired block shows.
      var cropbig = new Matrix();
      cropbig.translate(-BLOCKW * SCALE * i, 0);
      var b = new BitmapData(BLOCKW * SCALE, BLOCKH * SCALE, true, 0);
      b.draw(blocksbm, cropbig);
      blockbms[i] = b
    }

    gamebm = new BitmapData(BLOCKW * SCALE * TILESW,
			    BLOCKW * SCALE * TILESH,
			    true,
			    0);

    _root.gamemc = createGlobalMC('game', gamebm, GAMEDEPTH);
    _root.gamemc._x = BOARDX * SCALE;
    _root.gamemc._y = BOARDY * SCALE;

    backgroundbm = loadBitmap2x('background.png');
    _root.backgroundmc = createGlobalMC('bg', backgroundbm, BGIMAGEDEPTH);
    _root.backgroundmc._x = 0;
    _root.backgroundmc._y = 0;

    _root.playermc = createMovieAtDepth('player', PLAYERDEPTH);

    info = new Info();
    info.init();

    info.setMessage("You are now playing.");

    initboard();

    // _root.pucksmc = createMovieAtDepth('ps', PUCKSOUNDDEPTH);

    // setMusic('circus.wav');

    // redraw();
    starttime = (new Date()).getTime();
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

    // XXX when player is wrapping around screen, need
    // to draw up to 4 playermcs...
    // Consider placing on odd pixels?
    _root.playermc._x = (BOARDX + playerx - PLAYERLAPX) * SCALE;
    _root.playermc._y = (BOARDY + playery - PLAYERLAPY) * SCALE;
    // XXX animate.
    // XXX PERF this replaces the bitmap right?
    if (playerdx > 0) {
      _root.playermc.attachBitmap(playerbm, 'b', 1);
    } else {
      _root.playermc.attachBitmap(playerbml, 'b', 1);
    }
    // just leave at depth.
    // setDepthOf(_root.rinkmc, iceDepth(playery));

    // XXX debug mode showing mask

    // redraw the tile bitmap. This is already positioned
    // in the right place so that 0,0 is actually the start
    // of the game area.
    clearBitmap(gamebm);
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i];
      // trace(b.what);
      var w = (b.dir == HORIZ) ? b.len : 1;
      var h = (b.dir == VERT) ? b.len : 1;
      for (var y = 0; y < h; y++) {
	for (var x = 0; x < w; x++) {

	  var place = new Matrix();
	  place.translate((b.x + x) * BLOCKW * SCALE,
			  (b.y + y) * BLOCKW * SCALE);

	  gamebm.draw(blockbms[b.what], place);
	}
      }
    }
  }

  public function onKeyDown() {
    var k = Key.getCode();
    switch(k) {
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
