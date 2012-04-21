import flash.display.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.geom.Point;

/* This is basically the whole damn game.
   It's just easier that way... */

class World extends MovieClip {

  // XXX
  #include "level.h"

  var FONTW = 18;
  var FONTH = 32;

  var SFONTW = 9;
  var SFONTH = 16;

  // XXX should be lots more?
  var TILESW = 40;
  var TILESH = 25;

  var WIDTH = TILESW * FONTW;
  var HEIGHT = TILESH * FONTH;


  var MPLAY = 0, MEDIT = 1;
  var mode = MPLAY;


  var levelidx = 0;

  var font = [], smallfont = [];

  var data = [];

  var mc : MovieClip;
  var fontbitmap : BitmapData;
  var bitmap : BitmapData;
  var tbitmap : BitmapData;

  public function ascii(c : String) : Number {
    return 1 * c.charCodeAt(0);
  }

  var holdingframes = 0;
  var holdingSpace = false, holdingEsc = false,
    holdingUp = false, holdingLeft = false,
    holdingRight = false, holdingDown = false;
  var pressup = 0, pressleft = 0,
    pressright = 0, pressdown = 0;
  public function onKeyDown() {
    var k = Key.getCode();

    switch(k) {
    case ',':
    case 27: // esc
      //levelidx++;
      //loadLevel(LEVELS[levelidx]);
      // break;
      // case 'E':
      mode = MEDIT;
      redraw();
      break;
      // case 27: // esc
    case 'r':
      holdingEsc = true;
      break;

    case 38: // up
    case 32: // space
      holdingUp = true;
      pressup++;
      break;
    case 37: // left
      holdingLeft = true;
      pressleft++;
      break;
    case 39: // right
      holdingRight = true;
      pressright++;
      break;
    case 40: // down
      holdingDown = true;
      pressdown++;
      break;
    }
  }

  public function onKeyUp() {
    var k = Key.getCode();

    holdingframes = 0;
    switch(k) {
    case 27: // esc
      holdingEsc = false;
      break;

    case 32:
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

  public function init(k) {
    fontbitmap = BitmapData.loadBitmap('font.png');
    tbitmap = BitmapData.loadBitmap('t.png');
    var chars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
      "abcdefghijklmnopqrstuvwxyz" +
      "0123456789`-=[]\\;',./~!@#" +
      "$%^&*()_+{}|:\"<>?";
    for (var i = 0; i < chars.length; i++) {

      // Just shift the whole graphic so that only
      // the desired character shows.
      var cropbig = new Matrix();
      cropbig.translate((0 - SFONTW) * i, 0);
      cropbig.scale(2,2);

      var cropsmall = new Matrix();
      cropsmall.translate((0 - SFONTW) * i, 0);

      // Blit to a single-character bitmap using
      // the translation matrix above, and only
      // enough room for that one character.
      var f = new BitmapData(FONTW, FONTH, true, 0xFF222222);
      f.draw(fontbitmap, cropbig);
      font[chars.charCodeAt(i)] = f;

      var fs = new BitmapData(SFONTW, SFONTH, true, 0xFF222222);
      fs.draw(fontbitmap, cropsmall);
      // trace(chars.charCodeAt(i));
      smallfont[chars.charCodeAt(i)] = fs;
    }

    levelidx = 0;
    loadLevel(LEVELS[levelidx]);

    mc = _root.createEmptyMovieClip('worldmc', 999);
    bitmap = new BitmapData(WIDTH, HEIGHT, false, 0xFFCCFFCC);
    mc.attachBitmap(bitmap, 1000);
  }

  public function onLoad() {
    Key.addListener(this);
    trace('hi');
    init();

    _root.stop();
    this.stop();

    redraw();
  }

  var tx : Number = 0;
  var ty : Number = 0;

  /* l is a string 40x25 in size. */
  public function loadLevel(l) {
    data = [];
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        var c : Number = l.charCodeAt(x + y * TILESW);
        if (c == ascii('T')) {
          tx = x;
          ty = y;
        }

        data.push(c);
      }
    }
    redraw();
  }

  // How about symbols?
  public function canStepOn(c) {
    switch(c) {
    case ascii('A'):
    case ascii('E'):
    case ascii('I'):
    case ascii('O'):
    case ascii('U'):
    case ascii('Y'):
      return true;

    case ascii(' '):
      return true;

    default:
      if (c >= ascii('P') &&
          c <= ascii('Z')) {
        return true;
      }
    }

    return false;
  }

  public function killsYou(c) {
    if (c >= ascii('P') &&
        c <= ascii('Z')) {
      return true;
    }

    return false;
  }

  public function doSpecial() {
    var c = data[ty * TILESW + tx];
    if (c == ascii('Y')) {
      // XXX sound effect, animation
      levelidx++;
      loadLevel(LEVELS[levelidx]);
    } else if (killsYou(c)) {
      // XXX sound effect, animation
      loadLevel(LEVELS[levelidx]);
    }
  }

  var framemod : Number = 0;
  var facingright = true;
  public function onEnterFrame() {
    // Avoid overflow at the expense of jitter.
    framemod++;
    if (framemod > 100000)
      framemod = 0;

    var dx = 0, dy = 0;
    if (pressup) {
      dy = -1;
      pressup--;
    } else if (pressdown) {
      dy = 1;
      pressdown--;
    } else if (pressleft) {
      dx = -1;
      pressleft--;
    } else if (pressright) {
      dx = 1;
      pressright--;
    }

    // Implement key repeat.
    if (dx != 0 || dy != 0) {
      // Move the T.
      var ntx = tx + dx;
      var nty = ty + dy;

      if (canStepOn(data[nty * TILESW + ntx])) {
        tx = ntx;
        ty = nty;
      } else {
        // Play sound effect, animate.
      }

      // Allow rules whether we were stuck or not!

      /*
      holdingLeft = false;
      holdingRight = false;
      holdingUp = false;
      holdingDown = false;
      */

      doRules();
      redraw();
    }

    doSpecial();
  }

  public function ruleToString(rule) : String {
    var s = 'ch: ' + rule.ch;

    if (rule.match) {
      s += ' match: ';
      for (var i = 0; i < rule.match.length; i++) {
        s += rule.match[i] + ',';
      }
    }

    if (rule.res) {
      s += ' res: ';
      for (var i = 0; i < rule.res.length; i++) {
        s += rule.res[i] + ',';
      }
    }
    return s;
  }

  public function readRule(x, y) {
    // Repeatedly read a command and then some
    // number of characters.
    var i = y * TILESW + x;
    // trace('readrule ' + x + ',' + y);

    var PM = 0, PR = 1;
    var part = PM;
    var rule = { };
    while (i < ((y + 1) * TILESW)) {
      var command = data[i++];
      switch (command) {
      case ascii('?'):
        rule.ch = data[i++];
        break;
      case ascii('v'):
      case ascii('^'):
      case ascii('>'):
      case ascii('<'):
        if (part == PM) {
          if (!rule.match) rule.match = [];
          rule.match.push(command);
          rule.match.push(data[i++]);
        } else if (part == PR) {
          rule.res.push(command);
          rule.res.push(data[i++]);
        }
        break;
      case ascii('='):
        if (part == PM) {
          rule.res = [data[i++]];
          part = PR;
          break;
        } else {
          trace('= command outside match part.');
          return null;
        }
      case ascii('.'):
        if (part == PR) {
          // Done!
          return rule;
        } else {
          trace('. command outside res part.');
          return null;
        }
      default:
        trace('unknown command char ' + command);
        return null;
      }
    }
    // Off end of array.
    trace('off end of array.');
    return null;
  }

  // Apply the rule r, knowing that
  public function applyRule(x, y, rule, newdata) {
    // Only type of rule so far is match rule.
    var xx = x, yy = y;
    for (var i = 0; i < rule.match.length; i++) {
      // Path command
      switch (rule.match[i]) {
      case ascii('v'):
        yy++;
        break;
      case ascii('^'):
        yy--;
        break;
      case ascii('<'):
        xx--;
        break;
      case ascii('>'):
        xx++;
        break;
      default:
        throw 'bad path command ' + rule.match[i];
        return;
      }

      if (xx >= TILESW || xx < 0 ||
          yy >= TILESH || yy < 0) {
        trace('outside level');
        return;
      }
      i++;
      if (i >= rule.match.length) {
        throw ('bug, bad rule (match) ' + i);
        return;
      }

      if (data[yy * TILESW + xx] != rule.match[i]) {
        trace('didn\'t match ' + rule.match[i]);
        return;
      }
    }

    // XXX
    // newdata[y * TILESW + x] = ascii('!');
    xx = x;
    yy = y;
    for (var i = 0; i < rule.res.length; i++) {

      // Write, if inside the level.
      if (xx < TILESW && xx >= 0 &&
          yy < TILESH && yy >= 0) {
        newdata[yy * TILESW + xx] = rule.res[i];
      }
      i++;

      // But keep going either way. We might come
      // back into the level.

      if (i >= rule.res.length) {
        // Normal exit condition.
        return;
      }

      switch (rule.res[i]) {
      case ascii('v'):
        yy++;
        break;
      case ascii('^'):
        yy--;
        break;
      case ascii('<'):
        xx--;
        break;
      case ascii('>'):
        xx++;
        break;
      default:
        throw 'bad res path command ' + rule.res[i];
        return;
      }

      if (i >= rule.res.length) {
        throw ('bug, bad rule (res)');
        return;
      }
    }
  }

  // Process the level in place.
  public function doRules() {
    // Rules could change any frame.
    var rules = [];

    // Character where T was. Put T there
    // for the sake of making and matching
    // rules.
    var oldt = data[ty * TILESW + tx];
    data[ty * TILESW + tx] = ascii('T');

    // trace('dorules.');
    // First, get rules.
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        var i = y * TILESW + x;
        if (data[i] == ascii('?')) {
          var rule = readRule(x, y);
          if (rule) {
            rules.push(rule);
          }
        }
      }
    }

    trace('num rules: ' + rules.length);

    var newdata = data.slice(0);

    // Now, apply rules.
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        var i = y * TILESW + x;
        // PERF can index by character.
        for (var r = 0; r < rules.length; r++) {
          if (data[i] == rules[r].ch) {
            trace('rule matches @' + x + ',' + y +
                  ': ' + ruleToString(rules[r]));
            applyRule(x, y, rules[r], newdata);
          }
        }
      }
    }

    // ?
    newdata[ty * TILESW + tx] = oldt;
    data = newdata;
  }

  private function redraw() {

    if (mode == MPLAY) {

      var r = new Rectangle(0, 0, FONTW, FONTH);
      for (var y = 0; y < TILESH; y++) {
        for (var x = 0; x < TILESW; x++) {
          var ch = data[y * TILESW + x];
          // var ch = data[(framemod + y * TILESW + x) % (TILESW * TILESH)]
          bitmap.copyPixels(font[ch],
                            r,
                            new Point(x * FONTW, y * FONTH));
        }
      }

      // draw T
      bitmap.copyPixels(tbitmap, r,
                        new Point(tx * FONTW, ty * FONTH));
    } else {

      var MAPX = 100, MAPY = 100;

      var r = new Rectangle(0, 0, SFONTW, SFONTH);
      for (var y = 0; y < TILESH; y++) {
        for (var x = 0; x < TILESW; x++) {
          var ch = data[y * TILESW + x];
          bitmap.copyPixels(smallfont[ch],
                            r,
                            new Point(MAPX + x * SFONTW, MAPY + y * SFONTH));
        }
      }

    }
  }


}
