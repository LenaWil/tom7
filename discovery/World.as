import flash.display.*;

class World {

  #include "constants.js"
  #include "tiles.js"
  #include "map.js"
  
  // Rooms that the player has been in.
  var roomsvisited = {};
  var nroomsvisited = 0;


  var bgtiles = [];
  var fgtiles = [];


  var background = [];
  var foreground = [];

  var tilemap = {};
  public function init() {
    // Make tilemap and link bitmaps.
    for (var i = 0; i < tiles.length; i++) {
      tilemap[tiles[i].id] = tiles[i];
      var oframes = tiles[i].frames;
      tiles[i].frames = [];
      for (var f = 0; f < oframes.length; f += 2) {
	tiles[i].frames.push({ src: oframes[f],
	      delay: oframes[f + 1],
	      bm: BitmapData.loadBitmap(oframes[f] + '.png') });
      }
    }
  }
  
  // Transition to a new room.
  var currentroom : String;
  public function gotoRoom(s) {
    var symbol = 'room_' + s;
    if (this[symbol]) {
      // Currently aliasing bg and fg, which
      // may be desirable? (Modifications stay
      // around when changing screens?)
      background = this[symbol].bg;
      foreground = this[symbol].fg;

      currentroom = s;
      if (!roomsvisited[s]) {
	nroomsvisited++;
	roomsvisited[s] = true;
      }
      trace('now in room ' + s);

      rerender();
      
    } else {
      trace('no room ' + s);
      throw 'bad room';
    }
  }

  private function makeClipAt(x, y, startdepth, ground, hitlist) {
    var g = tilemap[ground[y * TILESW + x]];
    //    trace(g + ' ' + y + ' ' + x);
    if (g.frames.length > 0) {
      var depth = startdepth + y * TILESW + x;
      var mc : MovieClip = 
	_root.createEmptyMovieClip('b' + y + '_' + x,
				   depth);
	//_root.attachMovie("Star", "m" + depth, depth);
      mc._xscale = 200;
      mc._yscale = 200;
      mc._y = y * HEIGHT;
      mc._x = x * WIDTH;
      // trace(g.frames[0].src);
      mc.attachBitmap(g.frames[0].bm, mc.getNextHighestDepth());
      hitlist.push(mc);
    }
  }

  // Clears the tiles and redraws them.
  // Shouldn't need to call this every frame.
  public function rerender() {
    // Kill all old tiles.
    for (var i = 0; i < bgtiles.length; i++)
      bgtiles[i].removeMovieClip();
    for (var i = 0; i < fgtiles.length; i++)
      fgtiles[i].removeMovieClip();

    bgtiles = [];
    fgtiles = [];

    // Make tiles.
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
	makeClipAt(x, y, BGTILEDEPTH, background, bgtiles);
	makeClipAt(x, y, FGTILEDEPTH, foreground, fgtiles);
      }
    }
  }

  public function solidTileAt(screenx, screeny) {
    var tilex = int(screenx / WIDTH);
    var tiley = int(screeny / HEIGHT);

    // XXX should have tile prop.
    // trace(tilemap[foreground[tiley * TILESW + tilex]]);
    return tilemap[foreground[tiley * TILESW + tilex]].id != 0;
  }

}
