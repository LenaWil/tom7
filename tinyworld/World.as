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

  // XXX should be lots more?
  var TILESW = 40;
  var TILESH = 25;

  var WIDTH = TILESW * FONTW;
  var HEIGHT = TILESH * FONTH;


  var font = [];

  var data = [];

  var mc : MovieClip;
  var fontbitmap : BitmapData;
  var bitmap : BitmapData;

  public function ascii(c : String) : Number {
    return 1 * c.charCodeAt(0);
  }

  var holdingframes = 0;
  var holdingSpace = false, holdingEsc = false,
    holdingUp = false, holdingLeft = false,
    holdingRight = false, holdingDown = false;
  public function onKeyDown() {
    var k = Key.getCode();

    switch(k) {
    case 's':
      break;
    case 27: // esc
    case 'r':
      holdingEsc = true;
      break;

    case 38: // up
    case 32: // space
      holdingUp = true;
      break;
    case 37: // left
      holdingLeft = true;
      break;
    case 39: // right
      holdingRight = true;
      break;
    case 40: // down
      holdingDown = true;
      break;
    }
  }

  public function onKeyUp() {
    var k = Key.getCode();
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
    fontbitmap = BitmapData.loadBitmap('fontbig.png');
    var chars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
      "abcdefghijklmnopqrstuvwxyz" +
      "0123456789`-=[]\\;',./~!@#" +
      "$%^&*()_+{}|:\"<>?";
    for (var i = 0; i < chars.length; i++) {

      // Just shift the whole graphic so that only
      // the desired character shows.
      var crop = new Matrix();
      crop.translate((0 - FONTW) * i, 0);

      // Blit to a single-character bitmap using
      // the translation matrix above, and only
      // enough room for that one character.
      var f = new BitmapData(FONTW, FONTH, true, 0xFF222222);
      f.draw(fontbitmap, crop);
      // trace(chars.charCodeAt(i));
      font[chars.charCodeAt(i)] = f;
    }

    loadLevel(LEVEL);
    //LOADLEVEL(l);

    mc = _root.createEmptyMovieClip('worldmc', 999);
    bitmap = new BitmapData(WIDTH, HEIGHT, false, 0xFFCCFFCC);
    mc.attachBitmap(bitmap, 1000);
    // mc.attachBitmap(font[i], 1100);
  }

  public function onLoad() {
    Key.addListener(this);
    trace('hi');
    init();

    // Scale 2:1 pixels? Probably.
    // But we should just do this in the font -- the math
    // is typically easier.
    // this._xscale = 200.0;
    // this._yscale = 200.0;
    // Doesn't really matter which one is on top. Try both.
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
        // data.push("ABCDEFGHIJKLMNOPQRSTUVWXYZ".charCodeAt((x + y * TILESW) % 26));
        var c : Number = l.charCodeAt(x + y * TILESW);
        if (c == ascii('T')) {
          tx = x;
          ty = y;
          // XXX could be some background character from nearby?
          c = ascii(' ');
        }

        data.push(c);
      }
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
    if (holdingUp) {
      dy = -1;
    } else if (holdingDown) {
      dy = 1;
    }

    if (holdingLeft) {
      dx = -1;
    } else if (holdingRight) {
      dx = 1;
    }

    if (dx != 0 || dy != 0) {
      // Move the T.
      tx += dx;
      ty += dy;


      holdingLeft = false;
      holdingRight = false;
      holdingUp = false;
      holdingDown = false;

      doRules();
      redraw();
    }

  }

  // Takes the position of the character after
  // the question mark.
  /*
  public function readRule(x, y) {
    var SCH = 0, SCMD = 1;
    var PM = 0, PR = 1;
    var state = SCH, part = PM;

    var rule = { match: [], res: [] };
    for (var i = 0; i < TILESW; i++) {
      var c = data[y * TILESW + x + i];
      rule.match.push(c);
      if (state == SCH) {
        // Character. Can be anything.
        if (i == 0) {
          // Rules indexed by the first char.
          rule.ch = c;
        }
        state = SCH;
      } else if (state = SCMD)
        // Command...
        switch (c) {
        case ascii('/'):
        case ascii('\\'):
        case ascii('>'):
        case ascii('<'):
          // Directional chars, fine;
          break;
        case ascii('='):
          if (part == PM) {

          } else {

          }
        }
      }
    }

    // Got off the end of the screen? No rule.
    return null;
  }
  */

  public function ruleToString(rule) : String {
    var s = 'ch: ' + rule.ch;

    if (rule.match) {
      s += 'match: ';
      for (var i = 0; i < rule.match.length; i++) {
        s += rule.match[i] + ',';
      }
    }

    if (rule.res) {
      s += 'res: ';
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
    trace('readrule ' + x + ',' + y);

    var PM = 0, PR = 1;
    var part = PM;
    var rule = { };
    while (i < ((y + 1) * TILESW)) {
      var command = data[i++];
      switch (command) {
      case ascii('?'):
        rule.ch = data[i++];
        break;
      case ascii('/'):
      case ascii('\\'):
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
      case ascii('/'):
        yy++;
        break;
      case ascii('\\'):
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
      if (i >= rule.match[i]) {
        throw 'bug, bad rule';
        return;
      }

      if (data[yy * TILESW + xx] != rule.match[i]) {
        trace('didn\'t match ' + rule.match[i]);
        return;
      }
    }

    // XXX
    newdata[y * TILESW + x] = ascii('!');
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

    trace('dorules.');
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


    for (var i = 0; i < rules.length; i++) {
      trace(ruleToString(rules[i]));
    }

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
    // XXX clear bitmap
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
    bitmap.copyPixels(font[ascii('T')], r,
                      new Point(tx * FONTW, ty * FONTH));
  }


}
