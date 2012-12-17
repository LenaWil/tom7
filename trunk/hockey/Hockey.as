import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class Hockey extends MovieClip {

  #include "constants.js"
  #include "util.js"
  #include "bars.js"

  var rinkbm : BitmapData = null;
  var halobm : BitmapData = null;
  var puckbm : BitmapData = null;
  var bottomboardsbm : BitmapData = null;

  // cutscenes
  var goalscoredbg : BitmapData = null;
  var goalscoredcan : BitmapData = null;
  var goalscoredusa : BitmapData = null;
  var goalscoredref : BitmapData = null;

  var ejectionbg : BitmapData = null;
  var ejectionusa : BitmapData = null;
  var ejectioncan : BitmapData = null;
  var ejectionref : BitmapData = null;

  var gameoverbg : BitmapData = null;

  var telephonebg : BitmapData = null;
  var telephoneref : BitmapData = null;

  var stick1bm : BitmapData = null;

  var anger1bm : BitmapData = null;
  var anger2bm : BitmapData = null;
  var anger3bm : BitmapData = null;

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

  var menuteam = USA;

  // Cutscene.
  var NOCUT = 0;
  var GOALSCORED = 1;
  var EJECTION = 2;
  var TELEPHONE = 3;
  var GAMEOVER = 4;
  var cutscene = NOCUT;
  var cutteam = USA;
  var cutx = 0;
  var cutcounter = 0;
  var reftouchedlast = false;

  var suspicion = 0;

  // Three minutes.
  var gametimeframes = FASTMODE ? 30 : (4 * 60 * 24);

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
  // mc: movieclip for graphics, reset each frame
  // smc: movieclip for sound
  // stance: UPRIGHT, SPLAT, etc.
  // counter: general purpose frame counter
  //   for stances.
  // anger: [0, 1], 1 is maximum angriness
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

  // XXX TIMER
  var usascore = 0;
  var canscore = 0;

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
  }

  public function createGlobalMC(name, bitmap, depth) {
    var mc = createMovieAtDepth(name, depth);
    mc.attachBitmap(bitmap, 'b', 1);
    return mc;
  }

  // Get the default shot direction for the player.
  public function getPlayerShot(player) {
    var goalx;
    var goaly = GOALIEY + GOALH/2;
    if (player.facing == RIGHT) {
      // Maybe don't shoot towards own goal?
      goalx = CANGOALIEX + 15;
    } else {
      goalx = USAGOALIEX - 15;
    }

    // XXX from puck position?
    var dx = goalx - player.x;
    var dy = goaly - player.y;

    dy += 0.2 * (Math.random() - 0.5);

    return { dx: dx, dy: dy };
  }

  // Make the player shoot. Should have been in stance
  // SHOOTING, should have puck, should have stick.
  // dx/dy is a possibly unnormalized vector. strengthfrac
  // is the power from 0-1.
  public function playerShoots(player, dx, dy, strengthfrac) {
    // Norm dx/dy
    var len = Math.sqrt(dx * dx + dy * dy);
    if (len > 0) {
      dx /= len;
      dy /= len;
    }

    if (isNaN(dx)) dx = 0;
    if (isNaN(dy)) dy = 0;

    // trace('norm shoot vec: ' + dx + ' ' + dy + ' ' + strengthfrac);

    var pdx = dx * SHOTSTRENGTH * strengthfrac;
    var pdy = dy * SHOTSTRENGTH * strengthfrac;

    trace('shoot vec: ' + pdx + ' ' + pdy);

    player.puck = false;
    // Might want to ensure puck is in rink?
    puck = { x: player.x + ((player.facing == RIGHT) ?
                            PLAYERTOPUCK : -PLAYERTOPUCK),
             y: player.y,
             dx: pdx,
             dy: pdy };

    // XXX sound

    player.stance = FOLLOWTHROUGH;
    player.counter = 0;
  }

  public function angerTeam(team, amt) {
    for (var i = 0; i < players.length; i++) {
      if (players[i].team == team) {
        players[i].anger += amt;
        if (players[i].anger > 1) players[i].anger = 1;
        if (players[i].anger < 0) players[i].anger = 0;
      }
    }
  }

  public function makeCutsceneMC() {
    if (_root.cutscenemc) _root.cutscenemc.removeMovieClip();
    _root.cutscenemc = createMovieAtDepth('cut', CUTSCENEDEPTH);
    _root.cutscenemc._visible = true;
    _root.cutscenemc._x = 0;
    _root.cutscenemc._y = 0;
  }

  public function playCutsceneSound(wav, times) {
    var oof = new Sound(_root.cutscenesmc);
    trace(wav);
    oof.attachSound(wav);
    oof.setVolume(100);
    oof.start(0, times);
  }

  public function newCutScene(scene) {
    cutx = SCREENW + 3;
    cutcounter = 0;
    cutscene = scene;

    if (scene == GOALSCORED || scene == GAMEOVER) {
      playCutsceneSound('crowd.wav', 1);
    }

    // XXX booing
    if (scene == EJECTION) {
      playCutsceneSound('boo.wav', 1);
    }

    if (scene == TELEPHONE) {
      playCutsceneSound('telephone.wav', 2);
    }
  }

  public function resetCutScene() {
    animframe = 0;
    cutscene = NOCUT;
    _root.cutscenemc._visible = false;
    faceOff(2);
  }

  public function addAnger(player, amt) {
    player.anger += amt;
    if (player.anger > 1) player.anger = 1;
    if (player.anger < 0) player.anger = 0;
  }

  public function onEnterFrame() {
    animframe++;
    if (animframe > 1000000) animframe = 0;

    if (suspicion > 1.0 && cutscene == NOCUT) {

      newCutScene(TELEPHONE);
      cutteam = REF;
    }

    // trace('oef');

    // TODO: handle physics for objects on the ice (sticks, etc.)

    // TODO: Goals!
    if (cutscene == GOALSCORED) {
      cutcounter++;
      makeCutsceneMC();
      _root.cutscenemc.attachBitmap(goalscoredbg, 0);

      var mc = _root.cutscenemc.createEmptyMovieClip('team', 1);
      mc._y = 9 * 3;
      cutx = (41 * 3) * 0.33 + 0.66 * cutx;
      mc._x = cutx;
      if (cutteam == USA) {
        mc.attachBitmap(goalscoredusa, 4);
      } else if (cutteam == CAN) {
        mc.attachBitmap(goalscoredcan, 4);
      } else if (cutteam == REF) {
        mc.attachBitmap(goalscoredref, 4);
      }

      if (cutcounter > 75) {
        resetCutScene();
      }

      return;
    } else if (cutscene == EJECTION) {
      cutcounter++;
      makeCutsceneMC();
      _root.cutscenemc.attachBitmap(ejectionbg, 0);

      var mc = _root.cutscenemc.createEmptyMovieClip('team', 1);
      mc._y = 53 * 3;
      cutx = (161 * 3) * 0.33 + 0.66 * cutx;
      mc._x = cutx;

      if (cutteam == USA) {
        mc.attachBitmap(ejectionusa, 4);
      } else if (cutteam == CAN) {
        mc.attachBitmap(ejectioncan, 4);
      }

      var mcref = _root.cutscenemc.createEmptyMovieClip('r', 5);
      mcref._y = 31 * 3;
      mcref._x = -cutx*1.5 + SCREENW;

      mcref.attachBitmap(ejectionref, 10);

      if (cutcounter > 75) {
        resetCutScene();
      }

      return;
    } else if (cutscene == TELEPHONE) {

      cutcounter++;
      makeCutsceneMC();
      _root.cutscenemc.attachBitmap(telephonebg, 0);

      var mcref = _root.cutscenemc.createEmptyMovieClip('r', 5);
      mcref._y = 37 * 3;
      cutx = (169 * 3) * 0.33 + 0.66 * cutx;
      mcref._x = cutx;

      mcref.attachBitmap(telephoneref, 10);

      if (cutcounter > 100) {
        if (backgroundclip != null) {
          backgroundmusic.setVolume(0);
          backgroundmusic.stop();
          backgroundclip.removeMovieClip();
          backgroundclip = null;
        }
      } else {
        backgroundmusic.setVolume(100 - cutcounter);
      }

      if (cutcounter > 180) {
        // XXX delete everything...

        // XXX?!
        this.removeMovieClip();
        for (var o in _root) {
          _root[o].removeMovieClip();
        }
        _root.gotoAndStop('title');
        return;
      }

      return;
    } else if (cutscene == GAMEOVER) {
      cutcounter++;
      makeCutsceneMC();
      _root.cutscenemc.attachBitmap(gameoverbg, 0);

      var mc = _root.cutscenemc.createEmptyMovieClip('team', 1);
      mc._y = 9 * 3;
      cutx = (41 * 3) * 0.33 + 0.66 * cutx;
      mc._x = cutx;
      if (cutteam == USA) {
        mc.attachBitmap(goalscoredusa, 4);
      } else if (cutteam == CAN) {
        mc.attachBitmap(goalscoredcan, 4);
      }

      if (cutcounter > 100) {
        if (backgroundclip != null) {
          backgroundmusic.setVolume(0);
          backgroundmusic.stop();
          backgroundclip.removeMovieClip();
          backgroundclip = null;
        }
      } else {
        backgroundmusic.setVolume(100 - cutcounter);
      }

      if (cutcounter > 180) {
        // XXX delete everything...

        // XXX?!
        this.removeMovieClip();
        for (var o in _root) {
          _root[o].removeMovieClip();
        }
        _root.gotoAndStop('title');
        return;
      }

      return;
    }

    gametimeframes--;
    showScore(); // PERF always?
    if (gametimeframes < 0 && usascore != canscore) {
      newCutScene(GAMEOVER);
      cutteam = (usascore > canscore) ? USA : CAN;
    }

    // Physics for the puck, if not in possession.
    if (puck.p == undefined) {
      // trace('pdx: ' + puck.dx + ' ' + puck.dy);
      var res = tryMove(puck.x, puck.y,
                        PUCKCLIPW, PUCKCLIPH,
                        puck.dx, puck.dy, PUCKFRICTION,
                        true)
      puck.x = res.x;
      puck.y = res.y;

      puck.dx = res.dx;
      puck.dy = res.dy;

      if (res.hit) {
        playPuckBounce(puck.x, puck.y);
      }
    }

    for (var i = 0; i < junks.length; i++) {
      var junk = junks[i];
      var res = tryMove(junk.x, junk.y,
                        PUCKCLIPW, PUCKCLIPH,
                        junk.dx, junk.dy, JUNKFRICTION,
                        false);

      junk.x = res.x;
      junk.y = res.y;

      junk.dx = res.dx;
      junk.dy = res.dy;
    }

    var puckcoord = getPuckCoordinates();
    var refcoord = getRefCoordinates();

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

    var usaoffense = [{ x: 389 * 3, y: 167 * 3 },
                      { x: 424 * 3, y: 112 * 3 },
                      { x: 424 * 3, y: 224 * 3 },
                      { x: 385 * 3, y: 127 * 3 },
                      { x: 383 * 3, y: 203 * 3 }];
    var canoffense = [];
    for (var i = 0; i < usaoffense.length; i++) {
      var xx = usaoffense[i].x;
      var yy = usaoffense[i].y;
      canoffense.push({ x: REDLINEX - (xx - REDLINEX),
            y: yy });
    }

    var usadefense = [{ x: 122 * 3, y: 134 * 3 },
                      { x: 122 * 3, y: 198 * 3 },
                      { x: 150 * 3, y: 166 * 3 },
                      { x: 207 * 3, y: 168 * 3 },
                      { x: 240 * 3, y: 127 * 3 }];
    var candefense = [];
    for (var i = 0; i < usadefense.length; i++) {
      var xx = usadefense[i].x;
      var yy = usadefense[i].y;
      candefense.push({ x: REDLINEX - (xx - REDLINEX),
            y: yy });
    }

    // TODO: handle input for user player
    for (var i = 0; i < players.length; i++) {
      var player = players[i];

      if (i == user) {

        if (holdingX) {
          // impulse
          allowX = false;
          holdingX = false;

          if (player.team == REF) {

            // Eject the closest player.
            var bestdist = 999999;
            var bestidx = i;
            for (var p = 0; p < players.length; p++) {
              var other = players[p];
              if (other.team != REF) {
                var distx = other.x - player.x;
                var disty = other.y - player.y;
                var dist = distx * distx + disty * disty;

                if (dist < bestdist) {
                  bestdist = dist;
                  bestidx = p;
                }
              }
            }

            if (bestidx != i) {
              var other = players[bestidx];
              newCutScene(EJECTION);
              cutteam = other.team;

              // XXX get from player
              var guilt = 0.1;
              // xxx if guilt > 0.8 guilt = 1

              var anger = (1.0 - guilt) / 2;

              suspicion += (1.0 - guilt) * 0.75;

              angerTeam(other.team, anger);
              showScore();
            }

          } else {

            // If we have the puck, pass. Otherwise,
            // change the active player.
            if (player.puck) {

              // Find a player on my team..
              var bestp = pp;
              // Number of directions satisfied.
              var bestscore = -10;
              for (var pp = 0; pp < players.length; pp++) {
                var other = players[pp];
                if (other.team == player.team && pp != user) {
                  var otherscore = 0;
                  if (holdingLeft) {
                    if (other.x < player.x) {
                      otherscore++;
                    } else {
                      otherscore--;
                    }
                  }

                  if (holdingRight) {
                    if (other.x > player.x) {
                      otherscore++;
                    } else {
                      otherscore--;
                    }
                  }

                  if (holdingDown) {
                    if (other.y > player.y) {
                      otherscore++;
                    } else {
                      otherscore--;
                    }
                  }

                  if (holdingUp) {
                    if (other.y < player.y) {
                      otherscore++;
                    } else {
                      otherscore--;
                    }
                  }

                  if (otherscore > bestscore) {
                    bestscore = otherscore;
                    bestp = pp;
                  }
                }
              }

              var other = players[bestp];
              // Note, might not be any other players!
              playerShoots(player,
                           other.x - player.x,
                           other.y - player.y, 0.66);

              // Can switch away from current player if not
              // holding puck, and on a team.
            } else {

              // XXX skip over SPLATted players?
              for (var pp = 0; pp < players.length; pp++) {
                var other = (user + pp + 1) % players.length;
                if (players[other].team == player.team) {
                  user = other;
                  break;
                }
              }
            }
          }
        }

        if (player.stance == SHOOTING) {
          player.counter++;

          if (!holdingZ) {
            trace('shoots!');

            var dir = getPlayerShot(player);
            // XXX adjust if holding up/down.

            var strength = player.counter / FULLSTRENGTHTIME;
            if (strength > 1) strength = 1;
            playerShoots(player, dir.dx, dir.dy, strength);
          }

        } if (player.stance == UPRIGHT) {

          if (holdingZ && player.puck && player.stick) {
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

        // XXX goalie sticks?
        var destx = player.x;
        var desty = player.y;

        // TODO: handle AI for non-user players
        if (player.team == REF) {
          var distx = puckcoord.x - player.x;
          var disty = puckcoord.y - player.y;

          var dist = Math.sqrt(distx * distx +
                               disty * disty);
          if (dist > REFDIST) {
            destx = puckcoord.x;
            desty = puckcoord.y;
          } else {
            // ?
            destx = FACEOFF2X;
            desty = FACEOFF2Y - 100;
          }

          // XXX ref behavior -- get near puck?, but not
          // too close

        } else if (animframe > 10) {

          // XXX find stick if I don't have one.
          if (!player.stick) {
            var bestdist = 9999999;

            // If I can't figure out what to do, attack the ref, since
            // he must be up to some tomfoolery and there is always one.
            // XXX what if I'm the ref?
            destx = refcoord.x;
            desty = refcoord.y;

            for (var j = 0; j < junks.length; j++) {
              if (junks[j].type == STICK) {
                var xd = junks[j].x - player.x;
                var yd = junks[j].y - player.y;
                var distsq = xd * xd + yd * yd;
                if (distsq < bestdist) {
                  bestdist = distsq;
                  destx = junks[j].x;
                  desty = junks[j].y;
                }
              }
            }

          } else if (player.puck) {

            // trace('player ' + i + ' with puck ' + player.stance);
            if (player.stance == SHOOTING) {
              player.counter++;

              // trace('shooting ' + player.counter);
              if (Math.random() < 0.1 || player.counter > FULLSTRENGTHTIME) {
                var strength = player.counter / FULLSTRENGTHTIME;
                if (strength > 1) strength = 1;
                var dir = getPlayerShot(player);
                playerShoots(player, dir.dx, dir.dy, strength);
              }
            } else {

              // XXX should skate to offense before shooting.
              // XXX should sometimes pass, obviously
              player.stance = SHOOTING;
              player.counter = 0;
              trace('shooting...');
              // trace(' have puck? ' + player.puck);
            }

          } else if (player.goalie) {
            destx = (player.team == USA) ? USAGOALIEX : CANGOALIEX;
            desty = puckcoord.y;

            if (desty < GOALIEY) desty = GOALIEY;
            if (desty > GOALIEY + GOALH) desty = GOALIEY + GOALH;

            // XXX if in crease, set facing correctly.

            // XXX goalie should pass/shoot

            // XXX center indices; wrong
          } else {

            // Figure out what I do?
            var closestdist = 99999;
            var closestidx = i;

            var teammatehaspuck = false;
            var enemyhaspuck = false;

            for (var p = 0; p < players.length; p++) {
              var other = players[p];
              if (p != i && other.puck) {
                if (other.team == player.team) {
                  teammatehaspuck = true;
                } else {
                  enemyhaspuck = true;
                }
              }

              if (other.team == player.team &&
                  !other.goalie) {
                var px = other.x - puckcoord.x;
                var py = other.y - puckcoord.y;
                var dist = px * px + py * py;
                if (dist < closestdist) {
                  closestdist = dist;
                  closestidx = p;
                }
              }
            }

            // If I'm the closest to the puck, go there.
            if (i == closestidx) {
              // XXX as the player flips, not necessarily convergent
              destx = puckcoord.x;
              desty = puckcoord.y;
            } else if (enemyhaspuck) {

              var dest = (player.team == USA) ? usadefense.shift() :
                candefense.shift();
              destx = dest.x;
              desty = dest.y;
            }

            // Otherwise, if a teammate has the puck, go
            // to offense.
            if (teammatehaspuck) {
              var dest = (player.team == USA) ? usaoffense.shift() :
                canoffense.shift();
              destx = dest.x;
              desty = dest.y;
            }

            // Otherwise what, stay still?

          }

        }

        // XXX Can be smarter about skating towards dest.
        // Can only skate if upright.
        if (player.stance == UPRIGHT) {

          var distx = player.x - destx;
          var disty = player.y - desty;
          var dist = Math.sqrt(distx * distx +
                               disty * disty);

          // If close, slow down.
          var accel = PLAYERACCEL;
          if (dist < 12) {
            accel *= (dist / 12);
          }

          if (player.x < destx) {
            player.dx += accel;
            if (player.dx > 0) player.facing = RIGHT;
          } else if (player.x > destx) {
            player.dx -= accel;
            if (player.dx < 0) player.facing = LEFT;
          }

          if (player.y < desty) {
            player.dy += accel;
          } else if (player.y > desty) {
            player.dy -= accel;
          }

        }


      }

      // TODO: Pick up stick if near it.
      if (!player.stick && player.stance == UPRIGHT &&
          (i == user || player.team != REF)) {
        maybeGetStick(player);
      }

      // Pick up puck if near it.
      // TODO: consider timer after followthrough..
      if (player.stick && player.stance == UPRIGHT &&
          puck.p == undefined) {
        var ty = player.y;
        var tx = player.x; /* + ((player.facing == RIGHT) ?
                             PLAYERTOPUCK : -PLAYERTOPUCK); */

        // XXX limits on dy?
        if (Math.abs(puck.x - tx) < PICKUPDIST &&
            Math.abs(puck.y - ty) < PICKUPDIST) {
          player.puck = true;
          reftouchedlast = (player.team == REF);
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
          var prior1 = (i == user) ? 1000 : (player1.goalie ? 2000 : i);
          var prior2 = (j == user) ? 1000 : (player2.goalie ? 2000 : j);

          // Put them in priority order.
          if (prior1 < prior2) {
            var t = player1;
            player1 = player2;
            player2 = t;
          }

          // Player 1 wins...

          var rdx = player2.dx + player1.dx;
          var rdy = player2.dy + player1.dy;

          var baseanger =
            (player1.team == REF) ? 0.3 :
            ((player1.team == player2.team) ? 0.05 : 0.1);

          if (player2.puck) {
            puck = { x: player2.x + ((player2.facing == RIGHT) ?
                                     PLAYERTOPUCK : -PLAYERTOPUCK),
                     y: player2.y,
                     dx: 2 * rdx,
                     dy: 2 * rdy };
            player2.puck = false;
            addAnger(player2, baseanger);
            addAnger(player1, -baseanger);
          }

          // Lose stick.
          if (player2.stick) {
            var sdx = 0.6 * (rdx + Math.random() - 0.5);
            var sdy = 0.6 * (rdy + Math.random() - 0.5);
            // XXX randomize stick graphic.
            addJunk(player2.x, player2.y, sdx, sdy, STICK, stick1bm);
            player2.stick = false;
            addAnger(player2, 0.1);
            addAnger(player1, -0.1);
          }

          // Prevent player 1 from getting the stick immediately
          // if he doesn't have one.
          if (!player1.stick) {
            player1.stance = GETTINGUP;
            player1.counter = 0;
          }

          // And fall.
          player2.dx = 0.3 * rdx;
          player2.dy = 0.3 * rdy;
          player2.stance = SPLAT;
          player2.counter = 0;

          var damage = 1.0;
          playHurtSound(player2, damage);
        }
      }
    }

    for (var i = 0; i < players.length; i++) {
      var player = players[i];

      var mvx = player.puck ? (MAXVELOCITYX * 1.1) : MAXVELOCITYX;
      var mvy = player.puck ? (MAXVELOCITYY * 1.1) : MAXVELOCITYY;

      if (player.dx > mvx)
        player.dx = mvx;

      if (player.dx < -mvx)
        player.dx = -mvx;

      if (player.dy > mvy)
        player.dy = mvy;

      if (player.dy < -mvy)
        player.dy = -mvy;

      var res = tryMove(player.x, player.y,
                        PLAYERC, PLAYERCLIPHEIGHT,
                        player.dx, player.dy, PLAYERFRICTION,
                        false)
      player.x = res.x;
      player.y = res.y;

      player.dx = res.dx;
      player.dy = res.dy;
    }


    // Goal scored?
    if (puck.p == undefined) {

      if (puck.x >= CANGOALX1 && puck.x <= CANGOALX2 &&
          puck.y >= CANGOALY1 && puck.y <= CANGOALY2) {

        newCutScene(GOALSCORED);

        if (menuteam == REF && reftouchedlast) {
          cutteam = REF;
          angerTeam(USA, 0.5);
        } else {
          cutteam = USA;
          angerTeam(CAN, 0.2);
          angerTeam(USA, -0.5);
        }
        usascore++;
        showScore();

      } else if (puck.x >= USAGOALX1 && puck.x <= USAGOALX2 &&
                 puck.y >= USAGOALY1 && puck.y <= USAGOALY2) {

        newCutScene(GOALSCORED);

        if (menuteam == REF && reftouchedlast) {
          cutteam = REF;
          angerTeam(USA, 0.5);
        } else {
          cutteam = CAN;
          angerTeam(USA, 0.2);
          angerTeam(CAN, -0.5);
        }

        canscore++;
        showScore();
      }

    }

    redraw();
  }

  public function playPuckBounce(x, y) {
    var oof = new Sound(_root.pucksmc);
    var idx = (int(Math.random() * 1000)) % NBOUNCE;
    oof.attachSound('bounce' + (idx + 1) + '.wav');
    setSoundVolume(x, y, oof, 100);
    oof.start(0, 1);
  }

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

  public function maybeGetStick(player) {
    var ty = player.y;
    var tx = player.x; /* + ((player.facing == RIGHT) ?
                         PLAYERTOPUCK : -PLAYERTOPUCK); */

    for (var j = 0; j < junks.length; j++) {
      var junk = junks[j];
      if (junk.type == STICK) {
        // XXX limits on dy?
        if (Math.abs(junk.x - tx) < PICKUPSTICKDIST &&
            Math.abs(junk.y - ty) < PICKUPSTICKDIST) {
          trace('pick up stick');
          removeJunk(j);
          // Get stick.
          player.stick = true;
          player.stance = GETTINGUP;
          player.counter = int(GETUPTIME/2);
          return;
        }
      }

    }
  }

  // Move an object on the ice; used for both players
  // and the puck and maybe junk. The object returned
  // x, y, dx, and dy fields. Width and height are
  // half heights.
  public function tryMove(x, y, w, h, dx, dy, friction,
                          ispuck) {
    var hit = false;

    // XXX damping param
    var nx = x + dx;
    var ny = y + dy;
    if (nx - w < ICEMINX) {
      dx = -dx;
      hit = true;
      nx = ICEMINX + w;
    } else if (nx + w > ICEMAXX) {
      dx = -dx;
      hit = true;
      nx = ICEMAXX - w;
    }

    if (ny - h < ICEMINY) {
      dy = -dy;
      hit = true;
      ny = ICEMINY + h;
    } else if (ny + h> ICEMAXY) {
      dy = -dy;
      hit = true;
      ny = ICEMAXY - h;
    }

    // Bars.
    for (var i = 0; i < hbars.length; i++) {
      var hbar = hbars[i];
      if (ispuck && hbar.puckok) continue;
      if (y >= hbar.y1 && y <= hbar.y2) {
        if (x <= hbar.x1 && nx > hbar.x1) {
          nx = hbar.x1;
          dx = -dx;
          hit = true;
        } else if (x >= hbar.x2 && nx < hbar.x2) {
          nx = hbar.x2;
          dx = -dx;
          hit = true;
        }
      }
    }

    for (var i = 0; i < vbars.length; i++) {
      var vbar = vbars[i];
      if (ispuck && vbar.puckok) continue;
      if (x >= vbar.x1 && x <= vbar.x2) {
        if (y <= vbar.y1 && ny > vbar.y1) {
          ny = vbar.y1;
          dy = -dy;
          hit = true;
        } else if (y >= vbar.y2 && ny < vbar.y2) {
          ny = vbar.y2;
          dy = -dy;
          hit = true;
        }
      }
    }

    // ice deceleration
    dx *= friction;
    dy *= friction;

    return { x: nx, y: ny, dx: dx, dy: dy, hit: hit };
  }

  public function init() {
    menuteam = _root['menuselection'];
    trace('init hockey ' + menuteam);

    goalscoredbg  = loadBitmap3x('goalscoredbg.png');
    goalscoredcan = loadBitmap3x('goalscoredcan.png');
    goalscoredusa = loadBitmap3x('goalscoredusa.png');
    goalscoredref = loadBitmap3x('goalscoredref.png');

    ejectionbg  = loadBitmap3x('ejectionbg.png');
    ejectioncan = loadBitmap3x('ejectioncan.png');
    ejectionusa = loadBitmap3x('ejectionusa.png');
    ejectionref = loadBitmap3x('ejectionref.png');

    gameoverbg = loadBitmap3x('gameoverbg.png');

    telephonebg = loadBitmap3x('telephonebg.png');
    telephoneref = loadBitmap3x('telephoneref.png');

    anger1bm = loadBitmap3x('anger1.png');
    anger2bm = loadBitmap3x('anger2.png');
    anger3bm = loadBitmap3x('anger3.png');

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
    _root.pucksmc = createMovieAtDepth('ps', PUCKSOUNDDEPTH);

    _root.cutscenesmc = createMovieAtDepth('cuts', CUTSOUNDDEPTH);

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

    setMusic('circus.wav');

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
                       anger: 0,
                       smc: createMovieAtDepth('s' + players.length,
                                               PLAYERSOUNDDEPTH +
                                               players.length),
                       mc: mc };
        this.players.push(player);
      }
    }
    this.players.push({ goalie: false, team: REF,
          x: 0, y: 0, dx: 0, dy: 0, stance: UPRIGHT,
          anger: 0,
          smc : createMovieAtDepth('sref',
                                   PLAYERSOUNDDEPTH + players.length),
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
    info.init();
    showScore();

    faceOff(2);
    redraw();
  }

  public function showScore() {
    var minutes = int(gametimeframes / (60 * 24));
    var leftover = gametimeframes - (minutes * 60 * 24);
    var seconds = int(leftover / 24);

    var sstr = '' + seconds;
    if (seconds == 0) sstr = '00';
    else if (seconds < 10) sstr = '0' + seconds;
    var timestr = '' + minutes + ":" + sstr;

    if (menuteam == REF) {
      var line1 = " YOU ARE THE REF ";
      if (suspicion > 0) {
        line1 = "  SUSPICION: " + int(100 * suspicion) + "% ";
      }

      line1 += " TIME: " + timestr;

      info.setMessage(line1 + "\n" +
                      "Z - SHOOT     X - EJECT");
    } else {
      info.setMessage(" USA: " + usascore + "  " +
                      "CAN: " + canscore +
                      "  TIME: " + timestr +
                      "\n" +
                      "   Z - SHOOT     X - PASS/SWITCH");
    }
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

  public function getRefCoordinates() {
    for (var i = 0; i < players.length; i++) {
      if (players[i].team == REF) {
        return { x: players[i].x, y: players[i].y };
      }
    }

    return { x: 0, y: 0 };
  }

  public function scrollToShow(x, y) {
    var SLOP = 45 * 3;

    var wantx = scrollx;
    var wanty = scrolly;

    // XXX smooth transition!
    if (x - SLOP < scrollx) wantx = x - SLOP;
    if (y - SLOP < scrolly) wanty = y - SLOP;

    if (x + SLOP >= scrollx + SCREENW)
      wantx = x + SLOP - SCREENW;
    if (y + SLOP >= scrolly + (SCREENH - INFOHEIGHT))
      wanty = y + SLOP - (SCREENH - INFOHEIGHT);

    scrollx = scrollx * .75 + wantx * .25;
    scrolly = scrolly * .75 + wanty * .25;
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

    var amc = player.mc.createEmptyMovieClip('a', 3);
    amc._x = ((12*3) / 2) - 6;
    amc._y = -40;
    if (player.anger > 0.8) {
      amc.attachBitmap(anger3bm, 4);
    } else if (player.anger > 0.5) {
      amc.attachBitmap(anger2bm, 4);
    } else if (player.anger > 0.2) {
      amc.attachBitmap(anger1bm, 4);
    }
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

  public function removeJunk(idx) {
    var junk = junks[idx];
    junk.mc.removeMovieClip();
    junks.splice(idx, 1);
  }

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
    allowX = true;
    holdingZ = holdingX =
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
