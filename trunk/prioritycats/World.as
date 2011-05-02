import flash.display.*;
import flash.text.*;

class World {

  #include "constants.js"
  #include "tiles.js"
  #include "map.js"
  
  // Rooms that the player has been in.
  var roomsvisited = {};
  var nroomsvisited = 0;
  // Butterflies I've picked up.
  // XXX don't start with flies!
  var gotfly = {}; // {a: true, b:true, c: true, d: true, e: true };

  // The movieclips holding the current graphics.
  var bgtiles = [];
  var fgtiles = [];

  // These don't point to the real map data. When we switch
  // rooms, we actually copy into these, adding one tile from
  // each surrounding room.
  var backgroundcache = [];
  var foregroundcache = [];

  // Map from room name to its coordinates in the map.
  var coords = {};

  var currentmusic = null;
  var backgroundclip = null;
  var backgroundmusic = null;

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

    backgroundclip = _root.createEmptyMovieClip("backgroundclip", 80);
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

  public function musicForRoom(r) {
    switch(r) {
    case 'start':
      // built-in histeresis
    case 'mountain':
    case 'treeuptop':
    case 'forest2':
      return 'forest.mp3';
    case 'hole':
    case 'caveout':
    case 'glow':
      return 'worms.mp3';
    case 'lasercave':
      return 'lasercave.mp3';
    default:
      return null;
    }
  }

  public function volumeForRoom(r) {
    // return 0; // NOMUSIC

    switch(r) {
    default:
    case 'start':
      return 100;
      // 50 25 8
    }
  }

  // Get tiles relative to the top left of the current room, even
  // allowing x and y out of bounds. If we go out of the map
  // completely, return tile 1 which is expected to be solid.
  // Returns {f,b} with foreground and background tile IDs.
  public function getTileAnyway(tilex, tiley) {
    var data = roomdata(currentroom);
    if (tilex >= TILESW || tilex < 0 || tiley < 0 || tiley >= TILESH) {
      var c = coords[currentroom];
      var cx = c.x, cy = c.y;
      if (tilex >= TILESW) {
        // Out of world?
        if (cx >= mapwidth) {
          return { f: 1, b: 1 };
        }
        tilex -= TILESW;
        cx++;
      } else if (tilex < 0) {
        if (cx == 0) {
          return { f: 1, b: 1 };
        }
        tilex += TILESW;
        cx--;
      }

      if (tiley >= TILESH) {
        if (cy >= map.length) {
          return { f: 1, b: 1 };
        }
        tiley -= TILESH;
        cy++;
      } else if (tiley < 0) {
        if (cy == 0) {
          return { f: 1, b: 1 };
        }
        tiley += TILESH;
        cy--;
      }

      data = roomdata(map[cy][cx]);
    }
    
    var idx = tiley * TILESW + tilex;
    // trace('' + idx + ' from ' + data + ' ' + data.fg);
    return { f : data.fg[idx], b : data.bg[idx] };
  }

  public function getForeground(tilex, tiley) {
    return foregroundcache[(tiley + 1) * (TILESW + 2) +
                           (tilex + 1)];
  }

  public function getBackground(tilex, tiley) {
    return backgroundcache[(tiley + 1) * (TILESW + 2) +
                           (tilex + 1)];
  }

  // Transition to a new room.
  var currentroom : String;
  public function gotoRoom(s) {
    var symbol = 'room_' + s;
    if (this[symbol]) {
      currentroom = s;
      if (!roomsvisited[s]) {
        nroomsvisited++;
        roomsvisited[s] = true;
      }
      trace('now in room ' + s);

      // Copy foreground and background, and add border.
      // You don't want to read from these directly.
      // Call getForeground.
      /*
      backgroundcache = [];
      foregroundcache = [];

      for (var y = -1; y <= TILESH; y++) {
        for (var x = -1; x <= TILESW; x++) {
          var t = getTileAnyway(x, y);
          backgroundcache[(y + 1) * (TILESW + 2) +
                          (x + 1)] = t.b;
          foregroundcache[(y + 1) * (TILESW + 2) +
                          (x + 1)] = t.f;
        }
      }
      */

      var roommusic = musicForRoom(currentroom);
      if (roommusic != null &&
          currentmusic != roommusic) {
        // Does this leak??
        if (backgroundmusic)
          backgroundmusic.stop();
        backgroundclip.removeMovieClip();

        backgroundclip = _root.createEmptyMovieClip("backgroundclip", 80);
        backgroundmusic = new Sound(backgroundclip);
        trace('play :' + roommusic);
        backgroundmusic.attachSound(roommusic);
        // XXX fade in?
        backgroundmusic.setVolume(100);
        backgroundmusic.start(0, 99999);
        currentmusic = roommusic;
      }

      var roomvolume = volumeForRoom(currentroom);
      if (roomvolume != null && backgroundmusic) {
        backgroundmusic.setVolume(roomvolume);
      }

      rerender();

      _root.squares = [];

      // This is where I attach place pickups, etc.

      // Individual butterfly, not the laser room one.
      if (_root.butterfly) _root.butterfly.removeMovieClip();
      if (currentroom == 'start') {
        attachButterfly('a', 717, 54);
      } else if (currentroom == 'forestlump') {
        attachButterfly('b', 383, 422);
      } else if (currentroom == 'mountain') {
        attachButterfly('c', 648, 279);
      } else if (currentroom == 'deepcave') {
        attachButterfly('d', 395, 309);
      } else if (currentroom == 'waterfall') {
        attachButterfly('e', 309, 342);
      }

      // This is where I attach special objects.

      // Always detach laserfiles.
      _root.laserflies = _root.laserflies || [];
      for (var o in _root.laserflies)
        _root.laserflies[o].removeMovieClip();
      _root.laserflies = [];

      _root.inertflies = _root.inertflies || [];
      for (var o in _root.inertflies)
        _root.inertflies[o].removeMovieClip();
      _root.inertflies = [];

      if (_root.alsomoths) _root.alsomoths.removeMovieClip();

      if (currentroom == 'lasercave') {
       
        var flies = ['a', 'b', 'c', 'd', 'e'];
        var nflies = 0;
        for (var o in flies) {
          if (gotfly[flies[o]]) {
            _root.inertflies.push(attachInertFly(flies[o], 
                                                 175 + (nflies % 3) * 150,
                                                 175 + int(nflies / 3) * 150, nflies));
            nflies++;
          }
        }

        for (var i = 0; i < 30; i++) {
          var x = 2 * (LASERROOMX1 + Math.random() * (LASERROOMX2 - LASERROOMX1));
          var y = 2 * (LASERROOMY1 + Math.random() * (LASERROOMY2 - LASERROOMY1));
          var lf = _root.attachMovie('laserfly', 'laserfly' + i, LASERSDEPTH + i, {_x:x, _y:y});
          _root.laserflies.push(lf);
          lf.init(); // ?

          // Something special if we got all flies!
          if (nflies == flies.length) {
            lf.synchronize();
          }
        }

        if (nflies == flies.length) {
          _root.alsomoths = _root.attachMovie('alsomoths', 'alsomoths', ALSODEPTH, 
                                              {_x:300 * 2 + 50, _y: 145 * 2 + 50});
          _root.alsomoths.init();
        }
      }
      
    } else {
      trace('no room ' + s);
      throw 'bad room';
    }
  }

  public function gotButterfly() {
    gotfly[_root.butterfly.which] = true;
    // animation; removes itself.
    _root.butterfly.got();
    // prevent it from being gotten multiple times.
    _root.butterfly = null;
  }

  public function attachButterfly(which, x, y) {
    // because of border.
    x += 50;
    y += 50;
    if (!gotfly[which]) {
      // trace('add fly ' + which);
      var bf = _root.attachMovie('butterfly', 'butterfly', BUTTERFLYDEPTH, {_x:x, _y:y});
      bf.init(which, x, y);
      _root.butterfly = bf;
    } else {
      // trace('already got butterfly ' + which);
    }
  }

  public function attachInertFly(which, x, y, i) {
    // trace('add inert fly ' + which + ' @' + x + ' ' + y);
    var bf = _root.attachMovie('inertbutterfly', 'inertbutterfly' + which, 
                               BUTTERFLYDEPTH + i, {_x:x, _y:y});
    bf.init(which, x, y);
    return bf;
  }

  private function makeClipAt(x, y, startdepth, t, hitlist) {
    var g = tilemap[t];
    //    trace(g + ' ' + y + ' ' + x);
    if (g.frames.length > 0) {
      if (x == -1 || y == -1 || x == TILESW || y == TILESH) {
        // XXX just not drawing edges now.
        // Maybe fg alpha should be lower than bg alpha?
        // Maybe we just want to draw transparent fading atop it?
        // mc._alpha = 50;
      } else {

        var depth = startdepth + (y + 1) * (TILESW + 2) + (x + 1);
        var mc : MovieClip = 
          _root.createEmptyMovieClip('b' + (y + 1) + '_' + (x + 1), depth);
        mc._xscale = 200;
        mc._yscale = 200;
        mc._y = (y + 1) * HEIGHT;
        mc._x = (x + 1) * WIDTH;

        // trace(g.frames[0].src);
        mc.attachBitmap(g.frames[0].bm, mc.getNextHighestDepth());
        hitlist.push(mc);
      }
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
    for (var y = -1; y <= TILESH; y++) {
      for (var x = -1; x <= TILESW; x++) {
        var t = getTileAnyway(x, y);
        makeClipAt(x, y, BGTILEDEPTH, t.b, bgtiles);
        makeClipAt(x, y, FGTILEDEPTH, t.f, fgtiles);
      }
    }
  }

  /*
  // Only works for tiles on the current screen.
  public function foregroundTileAt(screenx, screeny) {
    var tilex = int(screenx / WIDTH);
    var tiley = int(screeny / HEIGHT);

    if (tilex >= TILESW || tilex < 0 || tiley < 0 || tiley >= TILESH)
      return 0;
    
    return foreground[tiley * TILESW + tilex];
  }

  public function deleteForegroundTileAt(screenx, screeny) {
    var tilex = int(screenx / WIDTH);
    var tiley = int(screeny / HEIGHT);

    if (tilex >= TILESW || tilex < 0 || tiley < 0 || tiley >= TILESH)
      return;
    
    foreground[tiley * TILESW + tilex] = 0;
  }
  */

  public function solidTileAt(screenx, screeny) {
    var tilex = int(screenx / WIDTH) - 1;
    var tiley = int(screeny / HEIGHT) - 1;
    //    trace('solidtileat ' +screenx + ',' + screeny + ' -> ' + tilex + ',' + tiley);

    /*
    var show = false;
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

      // trace('look at room @' + cx + ',' + cy + ': ' + tilex + ',' + tiley);
      show = true;
      fgm = roomdata(map[cy][cx]).fg;
    }
    */

    var tile = getTileAnyway(tilex, tiley).f;

    // XXX should have tile prop.
    // trace(tilemap[foreground[tiley * TILESW + tilex]]);
    // XXX why not just fgm[..] ? Isn't that the ID?
    // var tile = fgm[tiley * TILESW + tilex];
    // if (true || show)
    // trace('tile@ ' + tilex + "," + tiley + ": " + tile + ' =  ' + tilemap[tile].id);
    return tilemap[tile].id != 0;
  }


  var ccount = 1;
  var circs = [];
  public function clearDebug() {
    for (var o in circs) {
      circs[o].removeMovieClip();
    }
    circs = [];
  }

  // Returns true if every pixel(ish) between the two screen pixels
  // is unblocked.
  public function lineOfSight(x1, y1, x2, y2) {
    // We may stop before we get to the final point. Test that first.
    if (solidTileAt(x2, y2)) return false;

    var dx = x2 - x1;
    var dy = y2 - y1;
    // Make unit vector.
    var d = Math.sqrt(dx * dx + dy * dy);
    dx = dx / d;
    dy = dy / d;
    // Make quantum vector. To avoid tunnelling, we just
    // need the width of the test to be no longer than the
    // width of the minimum object. We don't care much about
    // going through corners (just make them solid; after
    // all, cats can see out of their butts!) so the minimum
    // width is just the tile width or height, which are the same.
    var step = (WIDTH / 2);
    dx = dx * step;
    dy = dy * step;

    // _root.message.text = '' + dx + ' ' + dy + ' ' + ' ' + d + ' ' + step;
    
    // just prevent looping when some bullshit creeps in there
    var maxiters = 100; 
    for (var i = 0; i * step < d; i++) {
      var tx = x1 + i * dx, ty = y1 + i * dy;

      /*
      var c = _root.attachMovie('circle', 'circle' + ccount, 20000 + ccount, {_x: tx, _y: ty});
      c._alpha = 15;
      circs.push(c);
      ccount++;
      */

      if (solidTileAt(tx, ty)) {
        return false;
      }
    }

    // Not blocked.
    return true;
  }

}
