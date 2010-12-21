import flash.display.*;
class Boss extends Depthable {

  #include "constants.js"

  var dx = 0;
  var dy = 0;

  // Size of graphic
  var width = 64 * 2;
  var height = 84 * 2;

  // Subtracted from clip region.
  // Player's top-left corner is at x+left, y+top.
  var top = 15 * 2;
  var left = 19 * 2;
  var right = 18 * 2;
  var bottom = 0 * 2;


  // Not a physics object. We just pretend, in order to
  // prevent tomfoolery. This is the Y position that
  // corresponds to the surfac of the dance floor.
  var FLOORY = 342;
  // Left and right edges of personal dance space.
  var FLOORXL = 400 - (19 * 2);
  var FLOORXR = 450;

  // Area in which the player's dancing counts.
  var PLAYERFLOORXL = 145;
  var PLAYERFLOORXR = 400;

  var FPS = 25;

  /* The danceoff is a script that the boss plays,
     where after each round he waits for you to do
     the 'same' dance. If you do them all, he is
     defeated and lets you pass. If you fail at any
     step, he laughs(?) and starts over.
     
     Each round is a series of x/y destinations that
     he tweens to, while an animation is playing.
     There's also a target, which is what the player
     must do in order to pass the round. 

     There should be some visual and some audio
     indication of success and failure. For example,
     the boss can switch to GASP frames for a little
     while, and a crowd cheering noise.
  */

  // Sometimes Flash complains about non-constant
  // initializers, so do it in a function.
  var danceoff = [];
  public function initdance() {

    // Canned 'invitation' step
    var invite_step = 
      { reps: 1,
        moves: [{ f: 'invite',
                  t: 16,
                  x: FLOORXL * 0.4 + FLOORXR * 0.6,
                  y: FLOORY },
      { f: 'invite',
        t: 16,
        x: FLOORXL * 0.6 + FLOORXR * 0.4,
        y: FLOORY }] };

    danceoff =
    [
     // First round: Player needs to robo walk.
     // Note that the player is USUALLY robo walking,
     // and is likely to arrive on the dance floor
     // already in that state.
     {
     target: { dance: 'z' },
     steps: [ 
             // Start with this so the player sees it without
             // waiting for anything.
             invite_step,
             { reps: 2,
               moves: [
               { f: 'robowalk',
                 t: 16,
                 x: FLOORXL,
                 y: FLOORY },
               { f: 'robowalk',
                 t: 16,
                 x: FLOORXR,
                 y: FLOORY }
               ]
             }
            ]
     },

     {
     target: { dance: 'x' },
     steps: [ 
             { reps: 2,
               moves: [
               { f: 'breakdance',
                 t: 16,
                 x: FLOORXL,
                 y: FLOORY },
               { f: 'breakdance',
                 t: 16,
                 x: FLOORXR,
                 y: FLOORY }
               ]
             }
             // invitations?
            ]
     },

     { target: { dance: 'v' },
       steps: [
             { reps: 2,
               moves: [
               { f: 'punch',
                 t: 16,
                 x: FLOORXL,
                 y: FLOORY },
               { f: 'punch',
                 t: 16,
                 x: FLOORXR,
                 y: FLOORY }
               ]
             }
             ]
     },

     {
     target: { dance: 'c' },
     steps: [ 
             { reps: 2,
               moves: [
               { f: 'hyperfloor',
                 t: 16,
                 x: FLOORXL,
                 y: FLOORY },
               // up, then down.
               { f: 'hyperjump',
                 t: 10,
                 x: FLOORXL,
                 y: FLOORY - 200 },
               { f: 'hyperjump',
                 t: 6,
                 x: FLOORXL,
                 y: FLOORY },

               // Now goto right.
               { f: 'hyperfloor',
                 t: 16,
                 x: FLOORXR,
                 y: FLOORY },
               // up, then down at right too
               { f: 'hyperjump',
                 t: 10,
                 x: FLOORXR,
                 y: FLOORY - 200 },
               { f: 'hyperjump',
                 t: 6,
                 x: FLOORXR,
                 y: FLOORY }

               ]
             }
             // invitations?
            ]
     }

     ];
  }

  // Current round of dancing.
  var danceround = 0;
  // Current step within the script.
  var dancestep = 0;
  // Number of reps completed in this step (of reps).
  var dancerep = 0;
  // Current move within this rep.
  var dancemove = 0;
  // Number of frames completed in this move (of t).
  var danceframe = 0;


  // You pass the round if !dancefail && dancesuccess.
  // Dancesuccess is set when you meet the target criteria.
  // (Currently just having that dance set at any time
  // while on the dancefloor.)
  // Dancefail is set if you switch to the WRONG dance,
  // or are thrusted.
  var dancefail = false;
  var dancesuccess = false;


  var framedata = {
  robowalk : { l: ['brobowalk1', 'brobowalk2', 'brobowalk3', 'brobowalk2'] },
  // XXX jump frames!
  jump : { l: ['brobowalk1'] },
  thrust: { l: ['bthrust'] },
  defeated: { l: ['bdefeated1', 'bdefeated2'] },
  invite: { l: ['binvite2', 'binvite1'] },
  hyperfloor: { l: ['bhyperjump2'] },
  hyperjump: { l: ['bhyperjump'] },
  breakdance: { l: ['bbreakdance1', 'bbreakdance2'] },
  embarrassed: { l: ['embarrassed'] },
  punch: { l: ['bpunchl', 'bpunchr'] }
  };

  var frames = {};

  public function init() {
    initdance();
    for (var o in framedata) {
      // n.b. boss is always 'facing' left, but keeping this as
      // a subfield to make it easier to maintain in parallel with
      // player animation (or use common utilities).
      frames[o] = { l: [] };
      var l = framedata[o].l;
      for (var i = 0; i < l.length; i++)
        frames[o].l.push({ src : l[i],
              bm: BitmapData.loadBitmap(l[i] + '.png') });
    }
  }

  public function onLoad() {
    this._xscale = 200.0;
    this._yscale = 200.0;
    this.setdepth(4900);
    this._x = FLOORXL;
    this._y = FLOORY;
    this.stop();
  }

  var thrustframes = 0;

  // Maximum length of shadow.
  var MAXSHADOW = 6;

  var lastframe = null;
  // Holds movieclips of our previous positions
  var shadows = [];
  var shcounter = 0;

  var embarrassedframes = 0;

  // Just make sure to clean up shadow, since those
  // are placed in the root.
  // XXX there is still a problem where these can
  // stick around.
  public function kill() {
    trace('kill boss');
    for (var o in shadows) {
      shadows[o].removeMovieClip();
    }
    shadows = [];
  }

  public function youOnDanceFloor() {
    return (embarrassedframes == 0) &&
      !_root.status.boss_defeated && 
      _root.you.x1() >= PLAYERFLOORXL &&
      _root.you.x2() < PLAYERFLOORXR &&
      _root.you.ontheground();
  }

  // Number of frames that escape has been held
  var framemod : Number = 0;
  public function onEnterFrame() {
    // Avoid overflow at the expense of jitter.
    framemod++;
    if (framemod > 100000)
      framemod = 0;

    // Or more generally, whenever we want to save shadow.
    if (thrustframes > 0 && lastframe && shcounter < 100) {
      var sh = 
        _root.createEmptyMovieClip('shadow' + shcounter,
                                   // Maybe should count down?
                                   4500 + shcounter);
      sh._y = this._y;
      sh._x = this._x;
      sh._xscale = 200.0;
      sh._yscale = 200.0;
      // XXX make it depend on depth, probably below
      sh._alpha = 50.0;
      
      sh.attachBitmap(lastframe, anim.getNextHighestDepth());
      shadows.push(sh);
      shcounter ++;
    }

    // Shrink shadow if it's too long or if we're not growing
    // it any more.
    if (thrustframes == 0 || shadows.length == MAXSHADOW) {
      // Throw away the oldest element.
      shadows[0].removeMovieClip();
      shadows = shadows.slice(1, shadows.length);
    } else if (thrustframes == 0 && shadows.length == 0) {
      // Shadow is done, so reset depths information.
      shcounter = 0;
    }


    // XXX "physics."
    if (this._y > FLOORY) {
      this._y = FLOORY;
      this.dy = 0;
    } else if (this._y < FLOORY) {
      this._y += this.dy;
      this.dy += 1.0;
    }

    // When boss is on the screen and not defeated,
    // prevent the player from passing.
    if (!_root.status.boss_defeated) {
      if (_root.you.x2() > 418) {
        trace('No!');

        // If the player tries to jump over boss, make the
        // boss instantly warp to his position to block him.
        var newy = _root.you._y + _root.you.top - this.top;
        if (this._y > newy) this._y = newy;
        thrustframes = 28;

        // Absolute prevention, even if player ignores thrusted
        // command.
        _root.you._x = 417 - (_root.you.width - _root.you.right);
        _root.you.thrusted(thrustframes);

        // Fail dance.
        dancefail = true;

        _root.indicator.dance(48);
      }
    }

    // Allow dancing to count.
    if (youOnDanceFloor()) {

      if (!dancesuccess &&
          _root.status.getCurrentDance() ==
          danceoff[danceround].target.dance) {
        // XXX play cheering
        dancesuccess = true;
        trace('success!');
        _root.indicator.right(48);
      }
    }


    // Special animation mode?
    if (thrustframes > 0) {
      thrustframes --;
      setframe('thrust', framemod);
      this._x = 417 + this.left - ((thrustframes * (thrustframes / 3)) / 3);

    } else if (_root.status.boss_defeated) {

      setframe('defeated', framemod);

    } else if (embarrassedframes > 0) {
      embarrassedframes --;
      if (embarrassedframes == 0) {
        danceround = 0;
        dancestep = 0;
        dancemove = 0;
      }

      setframe('embarrassed', framemod);

    } else {


      /*
      trace(' round ' + danceround +
            ' step ' + dancestep +
            ' rep ' + dancerep +
            ' move ' + dancemove +
            ' frame ' + danceframe);
      */
      // Series of steps
      var round = danceoff[danceround];
      // Series of moves, .reps repetitions
      var step = round.steps[dancestep];
      // Series of frames, each lasts .t
      var move = step.moves[dancemove];
      // XXX also allow linear interpolation,
      // which is probably what we usually want?
      // XXX or at least setting of blend rate
      this._x = this._x * 0.8 + move.x * 0.2;
      this._y = this._y * 0.8 + move.y * 0.2;
      setframe(move.f, framemod);
      danceframe++;
      if (danceframe > move.t) {
        // Next rep!
        danceframe = 0;
        dancemove++;
        if (dancemove >= step.moves.length) {
          // Next move!
          dancemove = 0;
          dancerep++;
          if (dancerep > step.reps) {
            dancerep = 0;
            // Next step!
            dancestep++;
            // Maybe go to next round, or start over.
            if (dancestep >= round.steps.length) {
              dancestep = 0;
              
              if (!dancefail && dancesuccess) {
                // For next round, whether we proceed
                // or start over.
                dancefail = false;
                dancesuccess = false;

                danceround++;
                if (danceround >= danceoff.length) {
                  // XXX Play applause!

                  _root.indicator.disco();
                  _root.status.boss_defeated = true;
                }

              } else {
                // If we simply didn't succeed, then
                // this is the moment that we failed,
                // so play boooooo sounds or laughing
                // or something.

                if (!dancesuccess) {
                  _root.indicator.wrong(48);
                  embarrassedframes = 48;
                }

                dancefail = false;
                dancesuccess = false;
                danceround = 0;

              }
            }
          }
        }
      }

      // Set animation frames.
      // XXX not necessary any more
      var otg = this._y > (FLOORY + 1);
    }
  }

  var anim: MovieClip = null;
  public function setframe(what, frmod) {
    // PERF don't need to do this if we're already on the
    // right frame, which is the common case.
    if (anim) anim.removeMovieClip();
    anim = this.createEmptyMovieClip('anim',
                                     this.getNextHighestDepth());
    anim._y = 0;
    anim._x = 0;

    var fs = frames[what].l;
    // XXX animation should be able to set its own period.
    // XXX pingpong (is built in)
    var f = int(frmod / 8) % fs.length;
    // trace(what + ' ' + frmod + ' of ' + fs.length + ' = ' + f);
    anim.attachBitmap(fs[f].bm, anim.getNextHighestDepth());
    lastframe = fs[f].bm;
  }

}
