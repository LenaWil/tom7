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

}
