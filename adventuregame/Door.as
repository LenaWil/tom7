
class Door extends MovieClip {
  
  var doorname : String;

  var requireopen : String;

  /* did we already announce what's keeping us
     from using this door? */
  var announced; /* : Bool ? */
  var blockedtext : String;

  /* XXX could generalize this.
     could provide a bunch of functions
     that we can call from onLoad
     like 
           mustBeOpen("alley_door")
  */
  public function active() {
    if (requireopen == undefined) return true;

    /* otherwise, we require something... */
    if (_root[requireopen]._currentframe == 2) {
      // trace("door active");
      return true;
    } else {
      // trace("door not active");
      if (blockedtext != undefined && !announced) {
	_root["player"].say(blockedtext);
	announced = true;
      }
      return false;
    }
  }

  public function onLoad() {
    /* for debuggin' */
    this._alpha = 50;
    /* should be invisible. */
    this._visible = false;

    // trace("Door " + doorname + " created.");

    /* put in local door list, but create
       that list if it doesn't exist first. */
    if (!(_root["doors"].length > 0)) {
      // trace(": clear list");
      _root["doors"] = [];
    }
    _root["doors"].push(this);

    /* If the player has us as door target, then warp
       him to us. */
	
    // var mcp = _root["player"];

    if (this.doorname ==
	_root["player"].doordest) {
      // trace("doorwarp!");  

      /* reg point at center for doors */
      var cx = this._x;
      var cy = this._y;
      var dd;
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
      _root["player"].warp(cx, cy, dd);

      /* reenable him */
      _root["player"].allowkeys = true;
    }
	
  }

  /* XXX .... */

}
