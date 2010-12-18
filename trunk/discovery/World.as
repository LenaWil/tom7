class World {

  var map = 
    [
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ],
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ],
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ],
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'start', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ],
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ],
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ],
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ],
     [ 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx', 'xxxxx' ]
    ];
  
  // Rooms that the player has been in.
  var roomsvisited = {};
  var nroomsvisited = 0;

  // Transition to a new room.
  var currentroom : String;
  public function gotoRoom(s) {
    currentroom = s;
    if (!roomsvisited[s]) {
      nroomsvisited++;
      roomsvisited[s] = true;
    }
  }

}
