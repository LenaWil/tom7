
class Door extends MovieClip {

  // Configured in editor. Must be unique to this room.
  var doorname : String;
  // If we hit this door, which frame do we switch to?
  var frametarget : String;
  // Which door in that frame to warp to?
  var doortarget : String;
  // Which direction should the player be facing to enter this
  // door?
  //    4
  //  2   1
  //    3
  var dir : Number;

  public function onLoad() {
    /* for debuggin' */
    // this._alpha = 50;
    /* should be invisible. */
    this._visible = false;

    // XXX compute tall or wide!

    if (this.frametarget && this.doortarget) {
      /* put in local door list, but create
	 that list if it doesn't exist first. */
      if (!_root["doors"].length) {
	_root["doors"] = [];
      }
      _root["doors"].push(this);
    } else {
      /* Don't bother putting it in the door list
	 if it doesn't take us anywhere, because
	 then we avoid the hit tests on every frame. */

      // XXX for debugging, show doors that have no
      // destination
      // trace(this.doorname + ' bogus: ' + this);
      this._visible = true;
      this._rotation = 45;
    }

    /* Upon changing rooms, the player will have
       his 'doordest' property set to the door
       he should spawn in. The door itself is
       responsible for arranging this at the time
       it loads. See if we're that door: */

    // trace(this.doorname + ' =?= ' + _root["you"].doordest);
    if (this.doorname ==
	_root["you"].doordest) {
      // trace("doorwarp!");  

      /* reg point at center for doors */
      var cx = this._x;
      var cy = this._y;
      var dd;
      /*
      switch(this["dir"]) {
      case 1: dd = 2;
	break;
      case 2: dd = 1;
	break;
      case 3: dd = 4;
	break;
      case 4: dd = 3;
	break;
      }
      */
      // XXX warptall/warpwide
      _root["you"]._x = cx;
      _root["you"]._y = cy;
      // _root["you"].warp(cx, cy, dd);
    }
	
  }

  public function correctdir(dx, dy) {
    switch(this.dir) {
    case 1: return dx > 0;
    case 2: return dx < 0;
    case 3: return dy > 0;
    case 4: return dy < 0;
    default: return true; // any?
    }
  }

  /* XXX .... */

}
