class World {

  #include "constants.js"
  #include "map.js"
  
  // Rooms that the player has been in.
  var roomsvisited = {};
  var nroomsvisited = 0;


  var bgtiles = [];
  var fgtiles = [];


  var background = [];
  var foreground = [];
  
  // Transition to a new room.
  var currentroom : String;
  public function gotoRoom(s) {
    if (this[s]) {
      // Currently aliasing bg and fg, which
      // may be desirable? (Modifications stay
      // around when changing screens?)
      background = this[s].bg;
      foreground = this[s].fg;

      currentroom = s;
      if (!roomsvisited[s]) {
	nroomsvisited++;
	roomsvisited[s] = true;
      }

      rerender();
      
    } else {
      trace('no room ' + s);
      throw 'bad room';
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
  }

}
