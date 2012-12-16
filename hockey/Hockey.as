import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class Hockey extends MovieClip {

  #include "constants.js"
  #include "util.js"

  var rinkbm : BitmapData = null;
  var halobm : BitmapData = null;
  var puckbm : BitmapData = null;
  var bottomboardsbm : BitmapData = null;

  var stick1bm : BitmapData = null;

  var info : Info = null;

  var holdingSpace = false;
  var holdingZ = false;
  var holdingX = false;
  var holdingUp = false;
  var holdingLeft = false;
  var holdingRight = false;
  var holdingDown = false;
  var holdingEsc = false;

  var menuteam = USA;

  // This is the scroll offset, the coordinates of the
  // top-left corner of the screen in terms of the rink
  // graphic.
  var scrollx = 0;
  var scrolly = 0;

  // Player stances.
  // Normal.
  var UPRIGHT = 0;
  // Fell.
  var SPLAT = 1;
  // Getting up from falling, or picking something
  // up off the ground.
  var GETTINGUP = 2;
  // Holding key to shoot (counter holds time held)
  var SHOOTING = 3;
  // Just released puck
  var FOLLOWTHROUGH = 4;

  // Each state is a list of frames for the USA team facing right.
  var playerframes = {
  shooting : {
    x: -6,
    l:[{f:'slapshot1.png', d:1}]
  },
  followthrough : {
    x: -6,
    l:[{f:'slapshot2.png', d:1}]
  },

  splat : {
    y: 13 * 3,
    l:
    [{f:'splat.png', d:1}]
  },
  stand : {
    l:
    [{f:'skate2.png', d:1}]
  },
  // With stick
  skate : {
    l:
    [{f:'skate1.png', d:5},
     {f:'skate2.png', d:9},
     {f:'skate3.png', d:5},
     {f:'skate2.png', d:9}]
  },

  gettingup : {
    l:[{f:'gettingup.png', d:1}]
  },

  standwo : {
    l:[{f:'skatewo2.png', d:1}]
  },
  // Without stick
  skatewo : {
    l:
    [{f:'skatewo1.png', d:5},
     {f:'skatewo2.png', d:9},
     {f:'skatewo3.png', d:5},
     {f:'skatewo2.png', d:9}]
  }/*, */
  };
  // Global animation offset. Resets to stay integral
  // and reasonably small.
  var animframe = 0;

  // Fields:
  // x,y - location of the center of the player's feet.
  // dx,dy - physics
  // facing: LEFT or RIGHT
  // team: USA or CAN or REF
  // goalie: true or false
  // stick: true or false
  // puck: true or false
  // stance: UPRIGHT, SPLAT, etc.
  // counter: general purpose frame counter
  //   for stances.
  // ...
  var players = [];

  // Stuff on the ice other than players and puck.
  // x,y, dx,dy - center of junk
  // type: STICK, ...
  // bm: which bitmap?
  // mc: movieclip
  var junks = [];

  var STICK = 0;

  // The puck is either at some coordinate {x,y,dx,dy} or
  // in possession of a player with index {p}.
  var puck = {x:0, y:0, dx:0, dy:0};

  // Who is being controlled by the player? After initialization,
  // this is always a player that's not been ejected.
  var user = 0;

  var currentmusic = null;
  var backgroundclip = null;
  var backgroundmusic = null;
  public function switchMusic(m) {
    if (currentmusic != m) {
      trace('switch music ' + m);
      // Does this leak??
      if (backgroundmusic)
        backgroundmusic.stop();
      backgroundclip.removeMovieClip();

      backgroundclip = _root.createEmptyMovieClip("backgroundclip",
                                                  MUSICDEPTH);
      backgroundmusic = new Sound(backgroundclip);
      backgroundmusic.attachSound(m);
      if (true || _root['musicenabled']) {
        backgroundmusic.setVolume(MUSIC ? 100 : 0);
      } else {
        backgroundmusic.setVolume(0);
      }
      backgroundmusic.start(0, 99999);
      currentmusic = m;
    }
  }

  public function onLoad() {
    Key.addListener(this);
  }

  public function createGlobalMC(name, bitmap, depth) {
    var mc = createMovieAtDepth(name, depth);
    // var mc = _root.createEmptyMovieClip(name, depth);
    mc.attachBitmap(bitmap, 'b', 1);
    return mc;
  }

  // Make the player shoot. Should have been in stance
  // SHOOTING, should have puck, should have stick.
  // XXX take vector for direction?
  public function playerShoots(player) {
    var dx = (player.facing == RIGHT) ? 1 : -1;
    var dy = 0.2 * (Math.random() - 0.5);
    var len = Math.sqrt(dx * dx + dy * dy);
    if (len > 0) {
      dx /= len;
      dy /= len;
    }
    // dx contained normalized vector now.

    var pdx = dx * SHOTSTRENGTH;
    var pdy = dy * SHOTSTRENGTH;

    trace('pd: ' + pdx + ' ' + pdy);

    player.puck = false;
    // Might want to ensure puck is in rink?
    puck = { x: player.x + ((player.facing == RIGHT) ?
                            PLAYERTOPUCK : -PLAYERTOPUCK),
             y: player.y,
             dx: pdx,
             dy: pdy };
    if (puck.p != undefined) {
      trace('???');
    }

    player.stance = FOLLOWTHROUGH;
    player.counter = 0;
  }

  public function onEnterFrame() {
    animframe++;
    if (animframe > 1000000) animframe = 0;

    // trace('oef');

    // TODO: handle physics for objects on the ice (sticks, etc.)

    // TODO: Goals!

    // Physics for the puck, if not in possession.
    if (puck.p == undefined) {
      // trace('pdx: ' + puck.dx + ' ' + puck.dy);
      var res = tryMove(puck.x, puck.y,
                        PUCKCLIPW, PUCKCLIPH,
                        puck.dx, puck.dy)
      puck.x = res.x;
      puck.y = res.y;

      puck.dx = res.dx;
      puck.dy = res.dy;
    }

    var puckcoord = getPuckCoordinates();

    // Advance waiting states.
    for (var i = 0; i < players.length; i++) {
      var player = players[i];
      if (player.stance == SPLAT) {
        player.counter++;
        if (player.counter > SPLATTIME) {
          player.stance = GETTINGUP;
          player.counter = 0;
        }
      } else if (player.stance == GETTINGUP) {
        player.counter++;
        if (player.counter > GETUPTIME) {
          player.stance = UPRIGHT;
          player.counter = 0;
        }
      } else if (player.stance == FOLLOWTHROUGH) {
        player.counter++;
        if (player.counter > FOLLOWTHROUGHTIME) {
          player.stance = UPRIGHT;
          player.counter = 0;
        }
      }
    }

    // TODO: handle input for user player
    for (var i = 0; i < players.length; i++) {
      var player = players[i];

      if (i == user) {

        if (player.stance == SHOOTING) {
          if (!holdingZ) {
            trace('shoots!');
            playerShoots(player);
          }

        } if (player.stance == UPRIGHT) {

          if (holdingZ) {
            trace('shooting...');
            player.stance = SHOOTING;
            player.counter = 0;

          } else {

            // XXX constants.
            if (holdingLeft) {
              player.dx -= PLAYERACCEL;
              if (player.dx < 0) player.facing = LEFT;
            } else if (holdingRight) {
              player.dx += PLAYERACCEL;
              if (player.dx > 0) player.facing = RIGHT;
            }

            if (holdingUp) {
              player.dy -= PLAYERACCEL;
            } else if (holdingDown) {
              player.dy += PLAYERACCEL;
            }
          }
        }

      } else {

        // TODO: handle AI for non-user players
        if (player.stance == UPRIGHT &&
            animframe > 100 &&
            (i == 3 || i == 7)) {

          // XXX find stick if I don't have one.

          if (player.x < puckcoord.x) {
            player.dx += PLAYERACCEL;
          } else if (player.x > puckcoord.x) {
            player.dx -= PLAYERACCEL;
          }

          if (player.y < puckcoord.y) {
            player.dy += PLAYERACCEL;
          } else if (player.y > puckcoord.y) {
            player.dy -= PLAYERACCEL;
          }
        }
      }

      // TODO: Pick up stick if near it.

      // Pick up puck if near it.
      // TODO: consider timer after followthrough..
      if (player.stick && player.stance == UPRIGHT &&
          puck.p == undefined) {
        var ty = player.y;
        var tx = player.x + ((player.facing == RIGHT) ?
                             PLAYERTOPUCK : -PLAYERTOPUCK);

        // XXX limits on dy?
        if (Math.abs(puck.x - tx) < PICKUPDIST &&
            Math.abs(puck.y - ty) < PICKUPDIST) {
          player.puck = true;
          puck = { p: i };
        }

      }
    }

    // Collisions between players.
    for (var i = 0; i < players.length; i++) {
      var player1 = players[i];
      if (player1.stance == SPLAT) continue;

      for (var j = i + 1; j < players.length; j++) {
        var player2 = players[j];
        if (player2.stance == SPLAT) continue;

        if (Math.abs(player1.x - player2.x) < COLLIDEDIST &&
            Math.abs(player1.y - player2.y) < COLLIDEDIST) {

          // trace(Math.abs(player1.x - player2.x) + ' ' +
          // Math.abs(player1.y - player2.y));

          // XXX should have real priority system, based on
          // velocity, stance, having puck, hp, anger, running
          // start, etc.
          var prior1 = (i == user) ? 1000 : i;
          var prior2 = (j == user) ? 1000 : j;

          // Put them in priority order.
          if (prior1 < prior2) {
            var t = player1;
            player1 = player2;
            player2 = t;
          }

          // Player 1 wins...

          var rdx = player2.dx + player1.dx;
          var rdy = player2.dy + player1.dy;

          if (player2.puck) {
            puck = { x: player2.x + ((player2.facing == RIGHT) ?
                                     PLAYERTOPUCK : -PLAYERTOPUCK),
                     y: player2.y,
                     dx: 2 * rdx,
                     dy: 2 * rdy };
            player2.puck = false;
          }

          // Lose stick.
          if (player2.stick) {
            var sdx = rdx + Math.random() - 0.5;
            var sdy = rdy + Math.random() - 0.5;
            // XXX randomize stick graphic.
            addJunk(player2.x, player2.y, sdx, sdy, STICK, stick1bm);
            player2.stick = false;
          }

          // And fall.
          player2.dx = 0.3 * rdx;
          player2.dy = 0.3 * rdy;
          player2.stance = SPLAT;
          player2.counter = 0;
        }
      }
    }

    for (var i = 0; i < players.length; i++) {
      var player = players[i];

      if (player.dx > MAXVELOCITYX)
        player.dx = MAXVELOCITYX;

      if (player.dx < -MAXVELOCITYX)
        player.dx = -MAXVELOCITYX;

      if (player.dy > MAXVELOCITYY)
        player.dy = MAXVELOCITYY;

      if (player.dy < -MAXVELOCITYY)
        player.dy = -MAXVELOCITYY;

      var res = tryMove(player.x, player.y,
                        PLAYERC, PLAYERCLIPHEIGHT,
                        player.dx, player.dy)
      player.x = res.x;
      player.y = res.y;

      player.dx = res.dx;
      player.dy = res.dy;
    }

    redraw();
  }

  // Move an object on the ice; used for both players
  // and the puck and maybe junk. The object returned
  // x, y, dx, and dy fields. Width and height are
  // half heights.
  public function tryMove(x, y, w, h, dx, dy) {
    // XXX damping param
    var nx = x + dx;
    var ny = y + dy;
    if (nx - w < ICEMINX) {
      dx = -dx;
      nx = ICEMINX + w;
    } else if (nx + w > ICEMAXX) {
      dx = -dx;
      nx = ICEMAXX - w;
    }

    if (ny - h < ICEMINY) {
      dy = -dy;
      ny = ICEMINY + h;
    } else if (ny + h> ICEMAXY) {
      dy = -dy;
      ny = ICEMAXY - h;
    }

    // ice deceleration
    dx *= ICEFRICTION;
    dy *= ICEFRICTION;

    return { x: nx, y: ny, dx: dx, dy: dy };
  }

  public function init() {
    menuteam = _root['menuselection'];
    trace('init hockey ' + menuteam);

    stick1bm = loadBitmap3x('stick1.png');

    halobm = loadBitmap3x('halo.png');
    _root.halomc = createGlobalMC('halo', halobm, HALODEPTH);

    rinkbm = loadBitmap3x('rink.png');
    _root.rinkmc = createGlobalMC('rink', rinkbm, RINKDEPTH);

    bottomboardsbm = loadBitmap3x('bottomboards.png');
    _root.bottomboardsmc = createGlobalMC('bottomboards',
                                          bottomboardsbm,
                                          BOTTOMBOARDSDEPTH);
    puckbm = loadBitmap3x('puck.png');
    _root.puckmc = createGlobalMC('puck', puckbm, ICESTUFFDEPTH + 500);

    var num = 0;
    for (var sym in playerframes) {
      var framelist = playerframes[sym].l;
      for (var i = 0; i < framelist.length; i++) {
        var frame = framelist[i];
        // Facing right
        var bm = loadBitmap3x(frame.f);
        var bmc = convertToCanadian(bm);
        var bmr = convertToReferee(bm);
        // Facing left
        var bml = flipHoriz(bm);
        var bmlc = flipHoriz(bmc);
        var bmlr = flipHoriz(bmr);
        frame.bm = bm;
        frame.bmc = bmc;
        frame.bmr = bmr;
        frame.bml = bml;
        frame.bmlc = bmlc;
        frame.bmlr = bmlr;
        num++;
      }
    }

    switchMusic('circus.wav');

    this.junks = [];

    this.players = [];
    for (var team = 0; team < 2; team++) {
      for (var p = 0; p < 5; p++) {

        // Depths will be reset dynamically, so just don't duplicate
        // for now.
        var mc = createMovieAtDepth('p_' + team + '_' + p,
                                    ICESTUFFDEPTH + team * 20 + p);
        var player = { goalie: (p == 0), x: 0, y: 0, dx: 0, dy: 0,
                       stance: UPRIGHT,
                       team: team,
                       mc: mc };
        this.players.push(player);
      }
    }
    this.players.push({ goalie: false, team: REF,
          x: 0, y: 0, dx: 0, dy: 0, stance: UPRIGHT,
          mc: createMovieAtDepth('pref', ICESTUFFDEPTH + 500) });

    // XXX from menu.
    switch (menuteam) {
    default:
    case USA: user = 1; break;
    case CAN: user = 7; break;
    case REF: user = players.length - 1; break;
    }
    trace('user: ' + user);

    trace('loaded ' + num + ' frames.');

    info = new Info();
    info.init()

    faceOff(2);
    redraw();
  }

  // Sets up the players for a faceoff.
  // The spots are
  //
  //       0       1
  //           2
  //       3       4
  //
  public function faceOff(which) {
    // Get coordinates for puck, which is the center
    // of the dot.
    var x, y;
    switch (which) {
    case 0: x = FACEOFF0X; y = FACEOFF0Y; break;
    case 1: x = FACEOFF1X; y = FACEOFF1Y; break;
    default:;
    case 2: x = FACEOFF2X; y = FACEOFF2Y; break;
    case 3: x = FACEOFF3X; y = FACEOFF3Y; break;
    case 4: x = FACEOFF4X; y = FACEOFF4Y; break;
    }

    // TODO: Ref could initiate faceoff, piss off players
    // by not dropping it.

    // Puck goes in the center.
    this.puck = {x:x, y:y, dx:0, dy:0};

    // Clear any junk.
    for (var i = 0; i < junks.length; i++) {
      junks[i].mc.removeMovieClip();
    }
    junks = [];

    // Priority on positions so that if the center is
    // ejected, someone takes his place.
    var usaoffsets = [{x: -25*3, y: 0}, {x: -44*3, y: -50*3},
                      {x: -44*3, y: 50*3}, {x: -62*3, y: 0}];
    var canoffsets = [{x: 25*3, y: 0}, {x: 44*3, y: -50*3},
                      {x: 44*3, y: 50*3}, {x: 62*3, y: 0}];

    // Initializes x,y and facing for each player.
    // Everyone gets a stick except the ref.
    // Nobody gets the puck. (TODO: ref?)
    for (var i = 0; i < players.length; i++) {
      var player = players[i];
      // XXX skip ejected players

      player.dx = 0;
      player.dy = 0;
      player.puck = false;
      player.stance = UPRIGHT;
      player.counter = 0;
      if (player.team == REF) {
        // Ref goes right above the puck.
        player.facing = RIGHT;
        player.x = x;
        player.y = y - PLAYERH/2;
        player.stick = false;
      } else {
        player.stick = true;
        if (player.goalie) {
          player.y = GOALIEY;
          if (player.team == USA) {
            player.x = USAGOALIEX;
            player.facing = RIGHT;
          } else {
            player.x = CANGOALIEX;
            player.facing = LEFT;
          }
        } else {
          // Regular player...
          var obj;
          if (player.team == USA) {
            player.facing = RIGHT;
            obj = usaoffsets.shift();
          } else {
            player.facing = LEFT;
            obj = canoffsets.shift();
          }
          if (!obj) obj = {x: 0, y: 0}; // ??

          player.x = x + obj.x;
          player.y = y + obj.y;

          // trace('at ' + player.x + ',' + player.y);
        }
      }
    }
  }

  public function getPuckCoordinates() {
    if (puck.p != undefined) {
      var plr = players[puck.p];
      var offset = (plr.facing == RIGHT) ?
        PLAYERTOPUCK : -PLAYERTOPUCK;
      return { x: plr.x + offset, y : plr.y };
    } else {
      return { x: puck.x, y: puck.y };
    }
  }

  public function scrollToShow(x, y) {
    var SLOP = 45 * 3;
    // XXX smooth transition!
    if (x - SLOP < scrollx) scrollx = x - SLOP;
    if (y - SLOP < scrolly) scrolly = y - SLOP;

    if (x + SLOP >= scrollx + SCREENW)
      scrollx = x + SLOP - SCREENW;
    if (y + SLOP >= scrolly + (SCREENH - INFOHEIGHT))
      scrolly = y + SLOP - (SCREENH - INFOHEIGHT);
  }

  public function iceDepth(ycoord) {
    return int(ycoord * 20);
  }

  public function placePlayer(idx, player) {
    // TODO: select frames based on state, etc.
    var whichframes = 'skate';

    if (player.stance == SPLAT) {
      whichframes = 'splat';
    } else if (player.stance == SHOOTING) {
      whichframes = 'shooting';
    } else if (player.stance == FOLLOWTHROUGH) {
      whichframes = 'followthrough';
    } else if (player.stance == GETTINGUP) {
      whichframes = 'gettingup';
    } else if (Math.abs(player.dx) < 1 &&
               Math.abs(player.dy) < 1) {
      if (player.stick) {
        whichframes = 'stand';
      } else {
        whichframes = 'standwo';
      }
    } else {
      if (player.stick) {
        whichframes = 'skate';
      } else {
        whichframes = 'skatewo';
      }
    }

    var xoffset = playerframes[whichframes].x || 0;
    var yoffset = playerframes[whichframes].y || 0;
    var frames = playerframes[whichframes].l;

    // PERF could cache this.
    var tot = 0;
    for (var i = 0; i < frames.length; i++) {
      tot += frames[i].d;
    }

    var offset = animframe % tot;
    var cell = frames[0];
    for (var i = 0; i < frames.length; i++) {
      if (offset < frames[i].d) {
        cell = frames[i];
        break;
      }
      offset -= frames[i].d;
    }

    // Cell is the animation cell to use. Now choose
    // left/right and team.
    var frame;
    if (player.team == USA) {
      frame = (player.facing == LEFT) ? cell.bml : cell.bm;
    } else if (player.team == CAN) {
      frame = (player.facing == LEFT) ? cell.bmlc : cell.bmc;
    } else {
      frame = (player.facing == LEFT) ? cell.bmlr : cell.bmr;
    }

    // PERF remove it every time, really?
    if (player.mc) player.mc.removeMovieClip();

    player.mc = createMovieAtDepth('p' + idx, ICESTUFFDEPTH +
                                   iceDepth(player.y) + 1 + idx);
    // Halo behind the player, if this is the user.
    if (idx == user) {
      _root.halomc._x = player.x - halobm.width/2 - scrollx;
      _root.halomc._y = player.y - halobm.height/2 - scrolly;
    }
    player.mc.attachBitmap(frame, PPLAYERDEPTH);

    if (player.facing == RIGHT) {
      player.mc._x = player.x + xoffset - PLAYERC - scrollx;
    } else {
      player.mc._x = player.x + xoffset - (frame.width - PLAYERC) - scrollx;
    }
    player.mc._y = player.y + yoffset - PLAYERH - scrolly;

  }

  var junkctr = 0;
  public function addJunk(x, y, dx, dy, type, bm) {
    junkctr++;
    var mc = createMovieAtDepth('j' + junkctr, iceDepth(y));
    mc.attachBitmap(bm, 1);
    var ajunk = {x:x, y:y, dx:dx, dy:dy, type:type, bm:bm, mc:mc};
    junks.push(ajunk);
    return ajunk;
  }

  // XXX removeJunk

  public function placeJunk(idx, thing) {
    // The movieclip is expected to already contain
    // the bitmap.
    setDepthOf(thing.mc, thing.y);
    thing.mc._x = thing.x - (thing.bm.width/2) - scrollx;
    thing.mc._y = thing.y - (thing.bm.height/2) - scrolly;
  }

  public function redraw() {
    // First try to put the puck in view.
    var puckcoord = getPuckCoordinates();
    scrollToShow(puckcoord.x, puckcoord.y);

    // Then try to put the player in view.
    scrollToShow(players[user].x, players[user].y);

    // scrollx = 500;
    // scrolly = 200;

    // Place rink.
    _root.rinkmc._x = -scrollx;
    _root.rinkmc._y = -scrolly;

    // Place bottom boards.
    _root.bottomboardsmc._x = BOTTOMBOARDSX - scrollx;
    _root.bottomboardsmc._y = BOTTOMBOARDSY - scrolly;

    // Place puck
    _root.puckmc._x = puckcoord.x - scrollx;
    _root.puckmc._y = puckcoord.y - PUCKH/2 - scrolly;
    setDepthOf(_root.puckmc, iceDepth(puckcoord.y));

    // Place junks.
    for (var i = 0; i < junks.length; i++) {
      placeJunk(i, junks[i]);
    }

    // Player player MCs.
    for (var p = 0; p < players.length; p++) {
      placePlayer(p, players[p]);
    }

  }

  public function clearKeys() {
    holdingEsc = holdingUp = holdingLeft = holdingRight = holdingDown = false;
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
      holdingX = true;
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