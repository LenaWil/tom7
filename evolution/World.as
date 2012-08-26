import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class World {

  #include "constants.js"
  #include "events.js"

  // The movieclips holding the current graphics.

  var currentmusic = null;
  var backgroundmusic = null;

  var mask : BitmapData = null;

  var tlbg : MovieClip = null;
  var trbg : MovieClip = null;
  var blbg : MovieClip = null;
  var brbg : MovieClip = null;

  var mapwidth = 0;
  var tilemap = {};

  public function init() {
    mask = BitmapData.loadBitmap("mask.png");

    tlbg = _root.createEmptyMovieClip("tlbg", WORLDDEPTH + 1);
    trbg = _root.createEmptyMovieClip("trbg", WORLDDEPTH + 2);
    blbg = _root.createEmptyMovieClip("blbg", WORLDDEPTH + 3);
    brbg = _root.createEmptyMovieClip("brbg", WORLDDEPTH + 4);
    trace('init world');


    var grow = new Matrix();
    grow.scale(2, 2);

    var idx = 0;
    for (var o in stuff) {
      var s = stuff[o];
      s.idx = idx;
      s.bm = [];
      s.jiggle = false;
      for (var i = 0; i < s.p.length; i++) {

        var bm = BitmapData.loadBitmap(s.p[i] + '.png');
        if (!bm) {
          trace('could not load bitmap ' + s.p[i] +
                '. add it to the library and set linkage!');
        }

        var bm2x : BitmapData =
          new BitmapData(bm.width * 2, bm.height * 2, true, 0);
        bm2x.draw(bm, grow);
        s.bm.push(bm2x);
      }
      s.mc = null;
      idx++;
    }
  }

  // Give the screen x and y coordinates; load the corresponding
  // bitmap into the movie clip.
  public function loadBits(mc, sx, sy) {
    // PERF! Cache it!
    var png = "screen_" + sx + "_" + sy + ".png";
    var bm : BitmapData = BitmapData.loadBitmap(png);
    var bm2x : BitmapData =
      new BitmapData(WIDTH * 2,
                     HEIGHT * 2,
                     // No transparency.
                     false, 0);
    var grow = new Matrix();
    grow.scale(2, 2);
    bm2x.draw(bm, grow);
    mc.attachBitmap(bm2x,
                    // depth: always the same
                    10);
  }

  public function liftingAt(x, y) {
    var tilex = int(x / TILEWIDTH);
    var tiley = int(y / TILEHEIGHT);

    // Pretend the whole world is surrounded by solids
    // that don't lift.
    if (tilex < 0 || tiley < 0 ||
        tilex >= WORLDTILESW ||
        tiley >= WORLDTILESH) return false;

    var pix : Number = mask.getPixel32(tilex, tiley);
    var aa = pix >> 24 & 0xFF;
    var rr = pix >> 16 & 0xFF;
    var gg = pix >> 8  & 0xFF;
    var bb = pix       & 0xFF;

    // Should be green.
    // XXX could support multiple color channels...?
    return bb < 0x70 && rr < 0x70 && gg > 0x70 && aa > 0x70;
  }

  // Takes world pixel coordinates.
  public function solidAt(x, y) {
    var tilex = int(x / TILEWIDTH);
    var tiley = int(y / TILEHEIGHT);

    // Pretend the whole world is surrounded by solids.
    if (tilex < 0 || tiley < 0 ||
        tilex >= WORLDTILESW ||
        tiley >= WORLDTILESH) return true;

    var pix : Number = mask.getPixel32(tilex, tiley);
    var aa = pix >> 24 & 0xFF;
    var rr = pix >> 16 & 0xFF;
    var gg = pix >> 8  & 0xFF;
    var bb = pix       & 0xFF;

    // Treat as solid if more than 50% alpha.
    // XXX Should allow for more kinds of information here, based
    // on the color?
    return bb > 0x70 && rr > 0x70 && gg < 0x70 && aa > 0x70;
  }

  public function waterAt(x, y) {
    var tilex = int(x / TILEWIDTH);
    var tiley = int(y / TILEHEIGHT);

    // Pretend the whole world is surrounded by solids
    // that don't lift.
    if (tilex < 0 || tiley < 0 ||
        tilex >= WORLDTILESW ||
        tiley >= WORLDTILESH) return false;

    var pix : Number = mask.getPixel32(tilex, tiley);
    var aa = pix >> 24 & 0xFF;
    var rr = pix >> 16 & 0xFF;
    var gg = pix >> 8  & 0xFF;
    var bb = pix       & 0xFF;

    // Should be blue.
    return bb > 0x70 && rr < 0x70 && gg < 0x70 && aa > 0x70;
  }

  var scrollx : Number = 0;
  var scrolly : Number = 0;

  public function scrollTo(scx, scy) {
    scrollx = scx;
    scrolly = scy;

    // Now, hard bounds on scrolling.
    if (scrollx < 0) scrollx = 0;
    if (scrolly < 0) scrolly = 0;
    if (scrollx > WORLDPIXELSW - WIDTH) scrollx = WORLDPIXELSW - WIDTH;
    if (scrolly > WORLDPIXELSH - HEIGHT) scrolly = WORLDPIXELSH - HEIGHT;
  }

  // Eases in.
  public function scrollTowards(scx, scy) {
    scx = int((scx + scrollx * 3) / 4);
    scy = int((scy + scrolly * 3) / 4);

    scrollTo(scx, scy);
  }

  // Only move the scroll window if we need to keep x,y in bounds.
  public function scrollToShow(x, y) {
    // Scrollx and scrolly are world coordinates too.
    var scx = scrollx;
    var scy = scrolly;

    // Scroll as little as possible.
    if (x - scx < XMARGIN) scx = x - XMARGIN;
    if (y - scy < YMARGIN) scy = y - YMARGIN;
    if (scx + WIDTH - x < XMARGINR) scx = x + XMARGINR - WIDTH;
    if (scy + HEIGHT - y < YMARGINB) scy = y + YMARGINB - HEIGHT;

    scrollTo(scx, scy);
  }

  public function drawPlayerAt(framemod, x, y) {
    // This is the screen number of the top-left screen.
    var screenx = int(scrollx / WIDTH);
    var screeny = int(scrolly / HEIGHT);

    var youx = x - scrollx;
    var youy = y - scrolly;

    var left = scrollx % WIDTH;
    var top = scrolly % HEIGHT;

    // Everything up to this point is in world pixels.

    loadBits(tlbg, screenx, screeny);
    tlbg._x = -2 * left;
    tlbg._y = -2 * top;

    loadBits(trbg, screenx + 1, screeny);
    trbg._x = -2 * left + 2 * WIDTH;
    trbg._y = -2 * top;

    loadBits(blbg, screenx, screeny + 1);
    blbg._x = -2 * left;
    blbg._y = -2 * top + + 2 * HEIGHT;

    loadBits(brbg, screenx + 1, screeny + 1);
    brbg._x = -2 * left + 2 * WIDTH;
    brbg._y = -2 * top + 2 * HEIGHT;

    // Loop over every object in the world (!) and position it,
    // if it's on-screen.
    var visx1 = screenx * WIDTH;
    var visy1 = screeny * HEIGHT;
    var visx2 = (screenx + 2) * WIDTH;
    var visy2 = (screeny + 2) * HEIGHT;
    for (var o in stuff) {
      var s = stuff[o];
      if (s.x >= visx1 && s.x < visx2 &&
          s.y >= visy1 && s.y < visy2) {
        // Set the right frame..
        // PERF not necessary if already on the right frame.
        if (s.mc) {
          s.removeMovieClip();
        }
        s.mc = _root.createEmptyMovieClip('stuff_' + o, STUFFDEPTH + s.idx);
        var f = int(framemod / (s.div || 1)) % s.bm.length;
        s.mc.attachBitmap(s.bm[f], 1);

        s.mc._x = 2 * (s.x - scrollx);
        s.mc._y = 2 * (s.y - scrolly) - (s.jiggle ? 4 : 0);
      } else {
        if (s.mc) {
          s.mc.removeMovieClip();
        }
      }
    }

    // Place you based on scroll window.
    _root.you._x = youx * 2;
    _root.you._y = youy * 2;
  }

  public function doEvents(x, y) {
    // XXX some histeresis. Shouldn't keep triggering the event
    // if it's permanent!
    for (var o in events) {
      var evt = events[o];
      // trace('try ' + o + ' ' + x + ' ' + y + ' in ' +
      // ' ' + evt.x1 + ' ' + evt.y1 +
      // ' ' + evt.x2 + ' ' + evt.y2);
      // XXX use center of dude?
      if (!evt.used &&
          x >= evt.x1 && x <= evt.x2 &&
          y >= evt.y1 && y <= evt.y2) {
        if (!evt.permanent) {
          evt.used = true;
        }

        var scx, scy;
        if (evt.scx && evt.scy) {
          scx = evt.scx;
          scy = evt.scy;
        } else {
          // Center player near bottom of screen.
          scx = x - WIDTH;
          scy = y - int(0.75 * HEIGHT);
        }

        // trace('trigger ' + o + '?');

        switch(o) {
        case 'treestart':

          _root.you.dialogInterlude([
          //     ------------------------------
             {m:('Hello little cell.\n' +
                 '\n' +
                 'Today is your 16th birthday.\n'),
              s: stuff['mom'],
                  scx: scx, scy: scy},

             {m:('Where are your presents?\n' +
                 'Well...\n' +
                 '\n' +
                 'Since this is such a special\n' +
                 'birthday, we got you\n' +
                 'something really special.\n'),
              s: stuff['dad'],
              scx: scx + 75, scy: scy},

             {m:('Yes, the present is a\n' +
                 'surprise! A surprise party!\n'),
              s: stuff['mom'],
              scx: scx, scy: scy },

             {m:('A surprise adventure party!\n' +
                 '\n' +
                 '\n' +
                 'Go find the adventure party!\n'),
              s: stuff['dad'],
                 scx: scx + 75, scy: scy }]);
          break;
        case 'lifeguard':
          _root.you.dialogInterlude([{
          //     ------------------------------
              m:('It\'s some kind of hut. I\n' +
                 'think it\'s where they sell\n' +
                 'snacks.\n'),
                  scx: scx, scy: scy}]);
          break;
        case 'shell':
          _root.you.dialogInterlude([
          //     ------------------------------
              {m:('Hi. I\'m the shellfish,\n' +
                 'Gene. I\'m doing Jazzercize\n' +
                 'to work on my body.\n'),
                  s: stuff['shell'],
                  scx: scx, scy: scy},
              {m:('Since I can breathe\n' +
                  'underwater, you should have\n' +
                  'this snorkel. It\'s an\n' +
                  'organelle that lets you\n' +
                  '"swim" better. Swim up\n' +
                  'and down! Swimming is a\n' +
                  'lot like slow jumping.\n'),
                  s: stuff['shell'],
                  scx: scx, scy: scy},
              {m:('\n\n' +
                  '         EVOLVED     \n' +
                  '\n'),
                  scx: scx, scy: scy}]);
          _root.you.havesnorkel = true;
          break;

        case 'bird':
          _root.you.dialogInterlude([
          //     ------------------------------
              {m:('Ho there good sir! And\n' +
                  'might I mention, a hearty\n' +
                  'happy birthday.\n'),
               s: stuff['bird'],
                  scx: scx, scy: scy},
              {m:('I\'m a time-traveling bird\n' +
                  'from the future, sent here\n' +
                  'to prevent the Large Hadron\n' +
                  'Collider from discovering\n' +
                  'mind-control lasers.\n'),
               s: stuff['bird'],
                  scx: scx + 100, scy: scy},
              {m:('Would you mind helping me\n' +
                  'by going down in there\n' +
                  'and causing a catastrophic\n' +
                  'magnet quench?\n'),
               s: stuff['bird'],
                  scx: 2553, scy: 3842},
              {m:('I mean, you don\'t want your\n' +
                  'mind controlled by lasers,\n' +
                  'do you?\n'),
               s: stuff['bird'],
                  scx: scx, scy: scy}]);
          _root.you.lhcopen = true;
          break;

        case 'charlie':
          _root.you.dialogInterlude([
          //     ------------------------------
              {m:('Hi! I\'m Charlie Darwin and\n',
                  'this is my boat! I\'m a\n' +
                  'boat driver AND a science\n' +
                  'chef!\n'),
               s: stuff['charlie'],
                  scx: scx, scy: scy},
              {m:('Sailing is easy! Boats\n' +
                  'just float like ducks!\n' +
                  'Charlie Darkwin Duck! hehe\n'),
               s: stuff['charlie'],
                  scx: scx, scy: scy}]);
          // XXX some power-up?
          break;

        case 'foreman':
          if (_root.you.havewalljump) {
            // nothing.
          } else if (_root.you.havecoordinates) {
          _root.you.dialogInterlude([
          //     ------------------------------
              {m:('What? You found trapped\n' +
                  'U.R.S.A. miners?\n' +
                  '\n' +
                  '...\n' +
                  'I guess if I dig them\n' +
                  'out, I won\'t need to teach\n' +
                  'you how to use dynamite.\n'),
               s: stuff['foreman'],
                  scx: scx, scy: scy},
              {m:('Instead I\'ll teach you how\n' +
                  'to climb walls so you can\n' +
                  'GET OUT OF MY MINE.\n'),
               s: stuff['foreman'],
                  scx: scx, scy: scy},
              {m:('This is a wall. Since cells\n' +
                  'are very sticky, you can\n' +
                  'cling to the wall, and even\n' +
                  'jump off it!'),
               s: stuff['foreman'],
                  scx: scx - 4 * 26, scy: scy - 26},
              {m:('\n\n' +
                  '         EVOLVED     \n' +
                  '\n'),
                  scx: scx, scy: scy}]);

          _root.you.havewalljump = true;

          } else if (!_root.you.lookingforminers) {
          _root.you.dialogInterlude([
          //     ------------------------------
              {m:('Happy birthday!\n' +
                  '\n' +
                  'Welcome to the United\n' +
                  'Reticulum Spelunking Assoc.\n' +
                  'public mine museum &\n' +
                  'adventure camp.'),
               s: stuff['foreman'],
                  scx: scx, scy: scy},
              {m:('The downside is that you\'re\n' +
                  'pretty much stuck here\n' +
                  'forever. Maybe you can find\n' +
                  'a new friend or job down\n' +
                  'here?\n'),
               s: stuff['foreman'],
                  scx: scx, scy: scy}]);
          _root.you.lookingforminers = true;
          } else {
            // do nothing
          }

          break;
        case 'miners':
          _root.you.dialogInterlude([
          //     ------------------------------
              {m:('BLESS MY TEXAS! You found\n' +
                  'us! The trapped U.R.S.A.\n' +
                  'miners!'),
               s: stuff['tminer1'],
                  scx: scx, scy: scy},
              {m:('Can you tell the foreman\n' +
                  'where we are? The air is\n' +
                  'getting thin, and we\'re\n' +
                  'aerobic!\n'),
               s: stuff['tminer2'],
                  scx: scx + 75, scy: scy},
              {m:('Just give him our GPS\n' +
                  'coordinates... I think this\n' +
                  'thing should work okay down\n' +
                  'here?'),
               s: stuff['tminer1'],
                  scx: scx, scy: scy},
              {m:('...\n'),
               s: stuff['tminer2'],
                  scx: scx + 75, scy: scy},
              {m:('81.37\' 64.331" N\n' +
                  '-41.03\' 22.101" E\n' +
                  '\n' +
                  ' ... got that?\n'),
               s: stuff['tminer1'],
                  scx: scx, scy: scy}]);
          _root.you.havecoordinates = true;
          break;

        case 'mines':
          _root.you.dialogInterlude([{
          //     ------------------------------
              m:('This is a public mine run\n'
                 'by the the United Reticulum\n'
                 'Spelunking Association.\n'
                 'Their motto is:\n'
                 '\n'
                 '"What\'s mines is yours."\n'),
                  scx: scx, scy: scy}]);
          break;

        default:
          _root.you.dialogInterlude([{
          //     ------------------------------
              m:('You found a "secret"!\n' +
                 'It\'s an unimplemented event!\n'),
                  scx: scx, scy: scy}]);
          break;
        }
      }
    }
  }

}
