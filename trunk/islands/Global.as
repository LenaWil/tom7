/* Helps us keep track of decorations that are
   in fixed supply. */
class Global {

  var FIRSTDECORATION = 500;
  var MAXDECORATIONS = 200;
  var decorations = [];

  // Return all indices.
  function reset() {
    for (var i = 0; i < MAXDECORATIONS; i++) {
      decorations[i] = undefined;
    }
  }

  // Get a decoration index, and claim it.
  function decorationidx() {
    var idx = Math.round(Math.random() * MAXDECORATIONS);
    for (var i = idx; i < MAXDECORATIONS; i++) {
      if (decorations[i] == undefined) {
        decorations[i] = true;
        return i;
      }
    }
    for (var i = 0; i < idx; i++) {
      if (decorations[i] == undefined) {
        decorations[i] = true;
        return i;
      }
    }
    return undefined;
  }

  // Return a decoration index.
  function giveup(i : Number) {
    // trace('giving up ' + i);
    decorations[i] = undefined;
  }

  
  // And some other random unrelated thing...
  var thelevels = ['firstlevel', 'secondlevel', 'winlevel'];
  var currentlevelindex : Number = undefined;
  public function nextLevel() {
    if (currentlevelindex == undefined)
      currentlevelindex = 0;
    else
      currentlevelindex ++;
    currentlevelindex %= thelevels.length;

    _root.background.destroy();

    var lev = thelevels[currentlevelindex];
    var mus;
    if (lev == 'firstlevel') {
      mus = _root.music.bouncy;
    } else if (lev == 'secondlevel') {
      mus = _root.music.noisy;
    } else {
      mus = _root.music.title;
    }

    _root.music.setmusic(mus);
    _root.gotoAndStop(lev);
  }
}
