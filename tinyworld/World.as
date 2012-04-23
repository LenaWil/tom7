import flash.display.*;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.geom.Point;

/* This is basically the whole damn game.
   It's just easier that way... */

class World extends MovieClip {

  // XXX
  // #include "level.h"

  var FONTW = 18;
  var FONTH = 32;

  var SFONTW = 9;
  var SFONTH = 16;

  // XXX should be lots more?
  var TILESW = 40;
  var TILESH = 25;

  var WIDTH = TILESW * FONTW;
  var HEIGHT = TILESH * FONTH;


  var MPLAY = 0, MEDIT = 1, MGETTEXT = 2;
  var mode = MPLAY;
  var gettext_cont = function (){
    trace('bare gettext cont?');
  };

  var font = [], smallfont = [];

  var data = [];

  var mc : MovieClip;
  var fontbitmap : BitmapData;
  var bitmap : BitmapData;
  var tbitmap : BitmapData;
  var cursorbitmap : BitmapData;
  var editorbitmap : BitmapData;

  // If this is true, don't allow keys or state
  // changes because we are doing a blocking load
  // from the server.
  var LOCKOUT = false;
  // Number of frames before drawing Loading message.
  var MAXLOCKOUTFRAMES = 12;
  var lockoutframes = 0;

  // Globally unique name of the current level.
  // Contains only a-z0-9, max 16 characters.
  var levelname : String = '';

  var lockedcache = {

  };
  var levelcache = {

  };

  public function saveLevel(name : String, s : String) {
    var sxml : XML = new XML();
    var that = this;
    sxml.onLoad = function() {
      that.say('done saving to server: (status ' +
               sxml.status + '): ' + sxml.toString());
    };

    sxml.onHTTPStatus = function(status:Number) {
      that.say('http status ' + status);
    };

    sxml.onData = function(src:String) {
      that.say('got data: ' + src);
    };

    sxml.load("http://spacebar.org/f/a/tinyworld/save/" +
              name + "?s=" +
              escape(s));

    say('saving to server...');
  }

  public function nextLevel(s) {
    var base = '', num : Number = 0;
    for (var i = 0; i < s.length; i++) {
      var c = s.charCodeAt(i);
      if (c >= ascii('a') && c <= ascii('z')) {
        base += s.charAt(i);
      } else {
        num = int(1 * s.substr(i));
        break;
      }
    }
    num++;

    return base + num;
  }

  public function gotoNextLevel() {
    levelname = nextLevel(levelname);
    trace('next level: ' + levelname);
    loadLevelCalled(levelname);
  }

  public function ascii(c : String) : Number {
    return 1 * c.charCodeAt(0);
  }

  public function makeLevelString(d) : String {
    var s : String = '';
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        var c = data[y * TILESW + x];
        if (c < 32 || c > 127) {
          c = 32;
        }
        s += String.fromCharCode(c);
      }
    }
    return s;
  }

  var cutrow = [];

  var gottext = '';
  var holdingframes = 0;
  var holdingSpace = false, holdingEsc = false,
    holdingUp = false, holdingLeft = false,
    holdingRight = false, holdingDown = false;
  var pressup = 0, pressleft = 0,
    pressright = 0, pressdown = 0;
  public function onKeyDown() {
    var k = Key.getCode();

    if (Key.isDown(Key.CONTROL) &&
        Key.getAscii() == ascii('m')) {
      _root['musicenabled'] = !_root['musicenabled'];
      say('music ' + (_root['musicenabled'] ? 'enabled' : 'disabled'));

      if (_root['musicenabled']) {
        backgroundmusic.setVolume(100);
      } else {
        backgroundmusic.setVolume(0);
      }

      return;
    }

    // Don't observe keys in lockout mode.
    if (LOCKOUT)
      return;

    if (mode == MGETTEXT) {
      if (k == Key.ENTER) {
        gettext_cont();
      } else if (k == Key.ESCAPE) {
        gottext = '';
        gettext_cont();
      } else if (k == Key.BACKSPACE) {
        if (gottext.length > 0) {
          gottext = gottext.substr(0, gottext.length - 1);
          redraw();
        }
      } else {
        var c = Key.getAscii();
        if (legalDestinationCode(c) && gottext.length < 16) {
          gottext += String.fromCharCode(c);
          redraw();
        }
      }

    } else if (mode == MEDIT) {
      switch (k) {
      case Key.TAB:
      case Key.ESCAPE:
        // Writes the data, but doesn't save to
        // server.
        var ls = makeLevelString(data);
        levelcache[levelname] = ls;
        switchMode(MPLAY);
        break;
      case 38: // up
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
      case Key.INSERT:
        for (var i = TILESW - 1; i >= tx + 1; i--) {
          data[ty * TILESW + i] = data[ty * TILESW + i - 1];
        }
        data[ty * TILESW + tx] = ascii(' ');
        redraw();
        break;
      case Key.DELETEKEY:
        for (var i = tx; i < TILESW - 1; i++) {
          data[ty * TILESW + i] = data[ty * TILESW + i + 1];
        }
        redraw();
        break;
      case Key.BACKSPACE:
        if (tx > 0) {
          tx--;
        }
        data[ty * TILESW + tx] = ascii(' ');
        redraw();
        break;
      default:
        var ch = Key.getAscii();

        if (Key.isDown(Key.CONTROL)) {
          switch(ch) {
          case ascii('k'):
            cutrow = [];
            for (var x = 0; x < TILESW; x++) {
              cutrow.push(data[ty * TILESW + x]);
            }

            for (var y = ty; y < TILESH - 1; y++) {
              for (var x = 0; x < TILESW; x++) {
                data[y * TILESW + x] =
                  data[(y + 1) * TILESW + x];
              }
            }
            redraw();
            break;

          case ascii('y'):
            for (var y = TILESH - 1; y > ty; y--) {
              for (var x = 0; x < TILESW; x++) {
                data[y * TILESW + x] =
                  data[(y - 1) * TILESW + x];
              }
            }

            for (var x = 0; x < TILESW; x++) {
              data[ty * TILESW + x] =
                (x < cutrow.length) ? cutrow[x] : ascii(' ');
            }
            redraw();
            break;

          case Key.HOME:
            ty = 0;
            redraw();
            break;

          case Key.END:
            ty = TILESH - 1;
            redraw();
            break;

          case ascii('a'):
            tx = 0;
            redraw();
            break;

          case ascii('e'):
            tx = TILESW - 1;
            redraw();
            break;

          case ascii('g'):
            mode = MGETTEXT;
            gottext = levelname;
            var that = this;
            gettext_cont = function() {
              that.mode = MEDIT;
              that.redraw();
              if (that.gottext != '') {
                that.loadLevelCalled(that.gottext);
                break;
              }
            };
            redraw();
            break;
          case ascii('s'):
            if (lockedcache[levelname]) {
              say('can\'t save -- locked!');
            } else {
              var ls = makeLevelString(data);
              levelcache[levelname] = ls;
              saveLevel(levelname, ls);
            }
            break;
          default:
            say('unknown ctrl key');
            break;
          }
        } else {
          editorType(ch);
        }
      }

    } else if (mode == MPLAY) {
      switch(k) {
      case Key.SPACE:
      case Key.PGDN:
        // XXX cheat
        gotoNextLevel();
        redraw();
        break;

      case Key.ESCAPE:
        reloadLevel();
        redraw();
        break;

      case ascii('E'):
      case Key.TAB:
        switchMode(MEDIT);
        break;

      case 38: // up
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
  }

  public function okayAscii(c) {
    return c >= 32 && c <= 126;
  }

  public function editorType(c) {
    if (okayAscii(c)) {
      data[ty * TILESW + tx] = c;
      if (tx < (TILESW - 1)) {
        tx++;
      }
      redraw();
    }
  }

  public function switchMode(m) {
    mode = m;
    pressup = 0;
    pressleft = 0;
    pressright = 0;
    pressdown = 0;

    reloadLevel();

    redraw();
  }

  public function onKeyUp() {
    var k = Key.getCode();

    // Don't observe keys in lockout mode.
    if (LOCKOUT)
      return;

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
    cursorbitmap = BitmapData.loadBitmap('cursor.png');
    editorbitmap = BitmapData.loadBitmap('editor.png');
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

    mc = _root.createEmptyMovieClip('worldmc', 999);
    bitmap = new BitmapData(WIDTH, HEIGHT, false, 0xFFCCFFCC);
    mc.attachBitmap(bitmap, 1000);
  }

  public function onLoad() {
    Key.addListener(this);
    trace('hi');
    _root.stop();
    this.stop();

    init();

    // XXX caller should be able to adjust this.
    switchMusic(_root['firstmusic']);
    loadLevelCalled(_root['firstlevel']);
  }

  var tx : Number = 0;
  var ty : Number = 0;

  // Should already have this in the cache.
  public function reloadLevel() {
    loadLevelCalled(levelname);
  }

  // XXX this needs to possibly fetch from the server.
  public function loadLevelCalled(s) {
    if (LOCKOUT) {
      throw 'reentrant loadLevelCalled!';
    }

    levelname = s;
    if (levelcache[levelname].length == (TILESW * TILESH)) {
      // Already have it cached.
      loadLevelData(levelcache[levelname]);
    } else {
      loadLevelFromServer(levelname);
    }
  }

  public function loadLevelFromServer(l) {
    // Don't observe keys in lockout mode.
    if (LOCKOUT) {
      throw 'reentrant loadLevelCalled!';
    }
    LOCKOUT = true;
    lockoutframes = MAXLOCKOUTFRAMES;

    var lxml : XML = new XML();
    var that = this;

    lxml.onHTTPStatus = function(status:Number) {
      // Not clear what to do in these cases?
      that.say('http status ' + status);
    };

    lxml.onData = function(src:String) {
      // trace('ondata.');
      if (!that.LOCKOUT) {
        throw 'bad loadLevelCalled lock!';
      }
      that.LOCKOUT = false;
      that.say('loaded ' + l + ' from server');

      var leveldata = src.substr(0, 1000);
      var islocked = (src.charCodeAt(1000) == ascii('Y'));

      that.lockedcache[l] = islocked;
      that.levelcache[l] = leveldata;
      levelname = l;
      that.loadLevelData(leveldata);
    };

    var url = 'http://spacebar.org/f/a/tinyworld/get/' + escape(l);
    trace(url);
    lxml.load(url);

    redraw();
  }

  /* l is a string 40x25 in size. */
  public function loadLevelData(l) {
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
      gotoNextLevel();
    } else if (killsYou(c)) {
      // XXX sound effect, animation
      reloadLevel();
    }
  }

  var framemod : Number = 0;
  public function onEnterFrame() {

    if (LOCKOUT)
      return;

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
      // Move the T or cursor.
      var ntx = tx + dx;
      var nty = ty + dy;

      if (ntx >= 0 && nty >= 0 &&
          ntx < TILESW && nty < TILESH &&
          // Cursor can go anywhere, but T is limited.
          (mode == MEDIT ||
           canStepOn(data[nty * TILESW + ntx]))) {
        tx = ntx;
        ty = nty;
      } else {
        // Play sound effect, animate.
      }

      // Allow rules whether we were stuck or not!

      if (mode == MPLAY) {
        doRules();
      }

      redraw();
    }

    if (mode == MPLAY) {
      doSpecial();
    }
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
      case ascii('('):
      case ascii(')'):
        if (part == PM) {
          if (!rule.match) rule.match = [];
          rule.match.push(command);
          rule.match.push(data[i++]);
        } else if (part == PR) {
          rule.res.push(command);
          rule.res.push(data[i++]);
        }
        break;
      case ascii('m'):
        if (part == PM) {
          var dest = getDest(i, y);
          if (dest == null || dest.length <= 0 ||
              dest.length > 16) {
            trace('illegal music ' + dest);
            return null;
          } else {
            rule.music = dest;
            return rule;
          }
        } else {
          trace('m command outside match part.');
          return null;
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
        break;
      case ascii('@'):
        if (part == PM) {
          var dest = getDest(i, y);
          if (dest == null || dest.length <= 0 ||
              dest.length > 16) {
            trace('illegal dest ' + dest);
            return null;
          } else {
            rule.dest = dest;
            return rule;
          }
        } else {
          trace('@ command outside match part.');
          return null;
        }
        break;
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

  // Used to get destination strings and music strings.
  public function getDest(i : Number, y : Number) {
    var dest = '';
    while (i < ((y + 1) * TILESW)) {
      var ch = data[i++];
      if (ch == ascii('.')) {
        if (dest.length > 0 && dest.length <= 16) {
          return dest;
        } else {
          trace('illegal dest ' + dest);
          return null;
        }
      } else if (legalDestinationCode(ch)) {
        dest += String.fromCharCode(ch);
      } else {
        trace('illegal destination code ' + ch);
        return null;
      }
    }
    trace('unterminated @ dest');
    return null;
  }

  public function legalDestinationCode(ch : Number) : Boolean {
    return (ch >= ascii('a') && ch <= ascii('z')) ||
      ch >= ascii('0') && ch <= ascii('9');
  }

  public function Sign(n : Number) : Number {
    if (n > 0)
      return 1;
    else if (n < 0)
      return -1;
    else
      return 0;
  }


  var currentmusic = null;
  var backgroundclip = null;
  var backgroundmusic = null;
  public function switchMusic(m) {
    // XXX maybe should work better the music file isn't found?
    if (currentmusic != m) {
      trace('switch music ' + m);
      // Does this leak??
      if (backgroundmusic)
        backgroundmusic.stop();
      backgroundclip.removeMovieClip();

      backgroundclip = _root.createEmptyMovieClip("backgroundclip", 80);
      backgroundmusic = new Sound(backgroundclip);
      backgroundmusic.attachSound(m + '.mp3');
      // XXX fade in?
      if (_root['musicenabled']) {
        backgroundmusic.setVolume(100);
      } else {
        backgroundmusic.setVolume(0);
      }
      backgroundmusic.start(0, 99999);
      currentmusic = m;
    }
  }

  // Apply the rule r, knowing that
  public function applyRule(x, y, rule, newdata, affected) : Boolean {
    // The direction towards the T is computed once based on the
    // starting position.
    var tdx = x - tx;
    var tdy = y - ty;
    var towardx = 0, towardy = 0;
    if (Math.abs(tdx) >= Math.abs(tdy)) {
      towardx = Sign(tdx);
    } else {
      towardy = Sign(tdy);
    }

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
      case ascii(')'):
        xx += towardx;
        yy += towardy;
        break;
      case ascii('('):
        xx -= towardx;
        yy -= towardy;
        break;
      default:
        throw 'bad path command ' + rule.match[i];
        return;
      }

      if (xx >= TILESW || xx < 0 ||
          yy >= TILESH || yy < 0) {
        trace('outside level');
        return true;
      }
      i++;
      if (i >= rule.match.length) {
        throw ('bug, bad rule (match) ' + i);
        return false;
      }

      if (affected[yy * TILESW + xx] != undefined) {
        trace('already affected at ' + xx + ',' + yy);
        return true;
      }

      if (data[yy * TILESW + xx] != rule.match[i]) {
        trace('didn\'t match ' + rule.match[i]);
        return true;
      }
    }

    // XXX replay match to set affected?

    // XXX
    // newdata[y * TILESW + x] = ascii('!');
    if (rule.music) {
      switchMusic(rule.music);
      return true;
    } else if (rule.dest) {
      trace('warp rule with dest ' + rule.dest);
      loadLevelCalled(rule.dest);
      return false;
    } else {

      xx = x;
      yy = y;
      for (var i = 0; i < rule.res.length; i++) {

        // Write, if inside the level.
        if (xx < TILESW && xx >= 0 &&
            yy < TILESH && yy >= 0) {
          newdata[yy * TILESW + xx] = rule.res[i];
          // data[yy * TILESW + xx] = rule.res[i];
          affected[yy * TILESW + xx] = true;
        }
        i++;

        // But keep going either way. We might come
        // back into the level.

        if (i >= rule.res.length) {
          // Normal exit condition.
          return true;
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
        case ascii(')'):
          xx += towardx;
          yy += towardy;
          break;
        case ascii('('):
          xx -= towardx;
          yy -= towardy;
          break;
        default:
          throw 'bad res path command ' + rule.res[i];
          return false;
        }

        if (i >= rule.res.length) {
          throw ('bug, bad rule (res)');
          return false;
        }
      }
    }

    return false;
  }

  // Process the level in place.
  public function doRules() {
    // Rules could change any frame.
    var rules = [];

    // Character where T was. Put T there
    // for the sake of making and matching
    // rules.
    var ttx = tx, tty = ty;
    var oldt = data[tty * TILESW + ttx];
    data[tty * TILESW + ttx] = ascii('T');

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
    // starts all false.
    var affected = new Array(TILESW * TILESH);

    // Now, apply rules.
    /*
    for (var y = 0; y < TILESH; y++) {
      for (var x = 0; x < TILESW; x++) {
        var i = y * TILESW + x;
        if (affected[i] == undefined) {
          // PERF can index by character.
          for (var r = 0; r < rules.length; r++) {
            if (data[i] == rules[r].ch) {
              trace('rule matches @' + x + ',' + y +
                    ': ' + ruleToString(rules[r]));
              applyRule(x, y, rules[r], newdata, affected);
            }
          }
        }
      }
    }
    */

    // To be more efficient, we could index the whole data
    // array by character. But the index for ' ' is gonna
    // be pretty big...
    for (var r = 0; r < rules.length; r++) {
      for (var y = 0; y < TILESH; y++) {
        for (var x = 0; x < TILESW; x++) {
          var i = y * TILESW + x;
          if (affected[i] == undefined &&
              data[i] == rules[r].ch) {
            // trace('rule matches @' + x + ',' + y +
            // ': ' + ruleToString(rules[r]));
            if (!applyRule(x, y, rules[r], newdata, affected)) {
              // Avoid swapping back if we applied a warp rule.
              data[tty * TILESW + ttx] = oldt;
              return;
            }
          }
        }
      }
    }

    // ?
    newdata[tty * TILESW + ttx] = oldt;
    data = newdata;
    // data[ty * TILESW + tx] = oldt;
  }

  var message : String;
  public function say(s) {
    message = s;
    redraw();
  }

  public function writeString(x, y, s) {
    var r = new Rectangle(0, 0, SFONTW, SFONTH);
    var c = 0;
    for (var i = 0; i < s.length; i++) {
      c++;
      /*
      if (x + c > TILESW) {
        c = 0;
        y += SFONTH;
      }
      */
      bitmap.copyPixels(smallfont[s.charCodeAt(i)], r,
                        new Point(x + c * SFONTW, y));
    }
  }

  public function writeStringBig(x, y, s) {
    var r = new Rectangle(0, 0, FONTW, FONTH);
    var c = 0;
    for (var i = 0; i < s.length; i++) {
      c++;
      /*
      if (x + c > TILESW) {
        c = 0;
        y += FONTH;
      }
      */
      bitmap.copyPixels(font[s.charCodeAt(i)], r,
                        new Point(x + c * FONTW, y));
    }
  }

  private function redraw() {

    if (LOCKOUT && lockoutframes == 0) {
      bitmap.copyPixels(editorbitmap,
                        new Rectangle(0, 0, WIDTH, HEIGHT),
                        new Point(0, 0));
      writeString(0, 0, message);
      writeStringBig(100, 400, 'loading from server...');
      return;
    }
    lockoutframes--;

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
    } else if (mode == MEDIT) {

      // Background.
      bitmap.copyPixels(editorbitmap,
                        new Rectangle(0, 0, WIDTH, HEIGHT),
                        new Point(0, 0));

      var MAPX = 100, MAPY = 100;

      writeString(0, 0, message);
      writeString(0, SFONTH, 'level name: ' + levelname);
      if (cutrow) {
        var s = '';
        for (var i = 0; i < cutrow.length; i++)
          s += String.fromCharCode(cutrow[i]);
        writeString(0, SFONTH * 2, 'cut row: ' + s);
      }


      var r = new Rectangle(0, 0, SFONTW, SFONTH);
      for (var y = 0; y < TILESH; y++) {
        for (var x = 0; x < TILESW; x++) {
          var ch = data[y * TILESW + x];
          bitmap.copyPixels(smallfont[ch],
                            r,
                            new Point(MAPX + x * SFONTW, MAPY + y * SFONTH));
        }
      }

      // Draw cursor.
      bitmap.copyPixels(cursorbitmap, r,
                        new Point(MAPX + tx * SFONTW, MAPY + ty * SFONTH));

      if (lockedcache[levelname]) {
        writeStringBig(100, 5 * SFONTH,
                       'THIS LEVEL IS LOCKED - NO SAVING.');
      }

      var INSY = 530;
      writeString(100, INSY,
                  'arrow keys to move cursor. type characters to insert.');
      writeString(100, INSY + SFONTH * 1,
                  'ctrl-s to save to server. ctrl-g to warp.');
      writeString(100, INSY + SFONTH * 2,
                  'ctrl-k cuts a line, ctrl-y pastes it.');
      writeString(100, INSY + SFONTH * 3,
                  'ctrl-a goes to line start, ctrl-e to end, like emacs.');
      writeString(100, INSY + SFONTH * 4,
                  'ctrl-home goes to the top, ctrl-end to the bottom.');
      writeString(100, INSY + SFONTH * 5,
                  'esc or tab goes back to game.');

      writeString(100, INSY + SFONTH * 7,
                  'use ctrl-s to save for everybody. PLZ BE SMART AND FUN :)');

      var KEY = INSY + SFONTH * 9;
      writeString(100, KEY,
                  '? starts a rule. the first character must match something');
      writeString(100, KEY + SFONTH * 1,
                  'in the level. commands < ^ > v continue the match in that');
      writeString(100, KEY + SFONTH * 2,
                  'direction. ( ) mean towards and away from the T. after the');
      writeString(100, KEY + SFONTH * 3,
                  'match must be an action. the = action writes a replacement');
      writeString(100, KEY + SFONTH * 4,
                  'path (can use <^>v()). the @ action warps to the given dest.');
      writeString(100, KEY + SFONTH * 5,
                  'the m command changes the music. then every rule ends with period.');
      writeString(100, KEY + SFONTH * 6,
                  'rules can match themselves and others. anything in the level!.');

    } else if (mode == MGETTEXT) {

      bitmap.copyPixels(editorbitmap,
                        new Rectangle(0, 0, WIDTH, HEIGHT),
                        new Point(0, 0));

      writeStringBig(100, 100, 'Load which level? (a-z 0-9 only)');
      writeStringBig(100, 100 + FONTH, gottext + '_');

    }
  }


}
