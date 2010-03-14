// Rectangular "physics" object. The player,
// dead player bodies, and enemies use this
// base class.
class PhysicsObject extends MovieClip {
  // Velocity x/y
  var dx = 0;
  var dy = 0;

  // Physics constants. These can be overridden
  // by the subclass, though things like gravity
  // probably should be true constants.
  var ACCEL = 3;
  var DECEL_GROUND = 0.75;
  var DECEL_AIR = 0.05;
  var JUMP_IMPULSE = 9.8;
  var GRAVITY = 0.5;
  var TERMINAL_VELOCITY = 9;
  var MAXSPEED = 5.5;
  var DIVE = 0.3;

  
  
}
