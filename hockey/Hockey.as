import flash.display.*;
import flash.text.*;
import flash.geom.Matrix;

class Hockey {

  #include "constants.js"
  #include "util.js"

  var currentmusic = null;
  var backgroundmusic = null;

  var rink : BitmapData = null;

  // Each state is a list of frames for the USA team facing right.
  var playerframes = {
  // With stick
  skate : [
    {f:'skate1.png', d:2}, 
    {f:'skate2.png', d:3},
    {f:'skate3.png', d:2},
    {f:'skate2.png', d:3}] /*,
  // Without stick
  skatewo : [
    {f:'skatewo1.png', d:2}, 
    {f:'skatewo2.png', d:3},
    {f:'skatewo3.png', d:2},
    {f:'skatewo2.png', d:3}] */
  };

  public function init() {
    trace('init hockey');
    rink = loadBitmap3x('rink.png');

    for (var sym in playerframes) {
      var framelist = playerframes[sym];
      
    }

  }
}
