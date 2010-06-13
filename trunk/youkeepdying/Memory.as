class Memory {
  
  // Frame names of all reachable spawns.
  // Unfortunately this list has to be maintained
  // in the editor as well as here.
  var reachablespawns = 
    [
     // Secret, above factory door
     'clouds',
     // Above umbrella
     'windtunnel',
     'upstairs',
     // Where umbrellas are manufacutred
     'factoryfloor',
     'factoryentrance',
     'factorydoor',
     'road',
     // Electric fence
     'leftstart',
     'start',
     // secret
     'cavetop',
     'cavedeadend',
     'cavetwolevel',
     // with spider
     'leftcave',
     // spike pit
     'cave',
     'bleed',
     // moving spawn over spike pit
     'caveinterstitial',
     // introduction to bees
     'bees',
     'stomach',
     'impossible',
     'waterbeepuzzle',
     'laserdance',
     'nosignal',
     'titleslide',
     'slide2',
     'paper1',
     'paper2',
     'rightpaper',
     // 'futurework',  // can't die
     'copycloset',
     'deepcloset',

     'demoend'
     ];

  var underconstruction = [ 'cavetop',
                            'clouds',
                            'futurework'
                            ];

  var hardspawns = [ 'factorydoor', 
                     'cavetwolevel',
                     'nosignal'
                     ];

  // Spawns that the player has unlocked by
  // using them, as hash from frame name to true.
  var spawnsfound = {};
  var nspawnsfound = 0;

  // Same, for under construction signs. (The player
  // just needs to enter the room.)
  var constructionfound = {};
  var nconstructionfound = 0;

  // Always use this to change between named frames
  // of the root movie clip, so that we can remember
  // the name of the frame we're on.
  var currentframe : String;
  public function gotoFrame(s) {
    // XXX could check that we know about this frame.
    currentframe = s;
    _root.gotoAndStop(s);
  }

  public function activatedThisSpawn() {
    return !!spawnsfound[currentframe];
  }

  public function activateThisSpawn() {
    if (!activatedThisSpawn()) {
      spawnsfound[currentframe] = true;
      nspawnsfound++;
    }
  }

  public function foundThisSign() {
    return !!constructionfound[currentframe];
  }
  
  public function findThisSign() {
    if (!foundThisSign()) {
      constructionfound[currentframe] = true;
      nconstructionfound++;
    }
  }


}
