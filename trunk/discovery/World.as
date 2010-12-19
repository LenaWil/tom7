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
  
  // Map from room name to its coordinates in the map.
  var coords = {};

  var mapwidth = 0;
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

    // XXX Could check no duplicate rooms (leads to bizarre behavior)
    // XXX Could check that adjacent rooms have equivalent edges
    // XXX Could check that outside world edges are solid.
    for (var y = 0; y < map.length; y++) {
      // Assumes they're all the same.
      mapwidth = map[y].length;
      for (var x = 0; x < map[y].length; x++) {
        coords[map[y][x]] = { x: x, y: y };
      }
    }
  }
  

  public function getCurrentRoom() {
    return currentroom;
  }

  // What room is left from the current one?
  public function leftRoom() {
    var c = coords[currentroom];
    return map[c.y][c.x - 1];
  }

  public function rightRoom() {
    var c = coords[currentroom];
    return map[c.y][c.x + 1];
  }

  public function upRoom() {
    var c = coords[currentroom];
    return map[c.y - 1][c.x];
  }

  public function downRoom() {
    var c = coords[currentroom];
    return map[c.y + 1][c.x];
  }

  public function roomdata(s) {
    return this['room_' + s];
  }

  // Movieclips to delete when leaving the current room.
  var deleteme = [];

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

      if (_root.boss) {
        _root.boss.kill();
        _root.boss = null;
      }

      if (_root.pickup) {
        _root.pickup();
      }

      // Kill any special stuff.
      for (var o in deleteme) {
        deleteme[o].removeMovieClip();
      }

      rerender();

      _root.squares = [];

      if (currentroom == 'xpickup') {
        trace('XPICKUP.');
        _root.pickup = _root.attachMovie('dancepickup',
                                         'dancepickup',
                                         4050,
                                         // XXXXXXXXXXXX
                                         {_x: 400, _y: 200});
        deleteme.push(_root.pickup);
      } else if (currentroom == 'cpickup') {
        _root.pickup = _root.attachMovie('dancepickup',
                                         'dancepickup',
                                         4050,
                                         // XXXXXXXXXXXX
                                         {_x: 400, _y: 200});
        deleteme.push(_root.pickup);
      }

      // Special room?
      if (currentroom == 'boss') {
        _root.boss = _root.attachMovie('boss', 'boss', 4900, {_x:400, _y:200});
        _root.boss.init();

        _root.indicator = _root.attachMovie('danceoffindicator',
                                            'danceoffindicator',
                                            3000,
                                            {_x: 5 * 32, _y: 3 * 32});
        _root.indicator.init();

        // No need to interact with boss physically.
        // _root.squares.push(_root.boss);
        deleteme.push(_root.boss);
        deleteme.push(_root.indicator);
      } else {
        _root.boss = null;
        _root.indicator = null;
      }
      
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

    // Look at adjacent rooms. Treat world edges as solid.
    var fgm = foreground;
    if (tilex >= TILESW || tilex < 0 || tiley < 0 || tiley >= TILESH) {
      var c = coords[currentroom];
      var cx = c.x, cy = c.y;
      if (tilex >= TILESW) {
        // Out of world?
        if (cx >= mapwidth) return true;
        tilex -= TILESW;
        cx++;
      } else if (tilex < 0) {
        if (cx == 0) return true;
        tilex += TILESW;
        cx--;
      }

      if (tiley >= TILESH) {
        if (cy >= map.length) return true;
        tiley -= TILESH;
        cy++;
      } else if (tiley < 0) {
        if (cy == 0) return true;
        tiley += TILESH;
        cy--;
      }

      // trace('look at room @' + cx + ',' + cy);
      fgm = roomdata(map[cy][cx]).fg;
    }

    // XXX should have tile prop.
    // trace(tilemap[foreground[tiley * TILESW + tilex]]);
    return tilemap[fgm[tiley * TILESW + tilex]].id != 0;
  }

}
