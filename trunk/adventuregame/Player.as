
class Player extends Depthable {

  var dx;
  var dy;
  var dir;

  var doordest;
  var allowkeys;

  var spoken;

  public function onEnterFrame () {
    switch(this.dir) {
    case 1:
      this.move(10, 0);
      break;
    case 2:
      // trace("moveleft");
      this.move(-10, 0);
      break;
    case 3:
      this.move(0, 10);
      break;
    case 4:
      this.move(0, -10);
      break;
    }
  }

  public function onKeyDown() {
    if (allowkeys) {
      /* is this reentrant? */
      allowkeys = false;

      var k = Key.getCode();
      //      trace(k);
      switch(k) {
      case 38: /* up */
	this.setdir(4);
	break;
      case 37: /* left */
	this.setdir(2);
	break;
      case 39: /* right */
	this.setdir(1);
	break;
      case 40: /* down */
	this.setdir(3);
	break;
      case 49:
	this.changeframe("inside");
	break;
      case 50:
	this.changeframe("outside");
	break;
      case 51:
	this.changeframe("driveway");
	break;
      case 52:
	this.say("You pressed a button to test the talking!");
	break;
      case 36: /* home */
	this.changeframe("outside");
	break;
      case 35: /* end */
	this.changeframe("driveway");
	break;
      }

      allowkeys = true;
    } 
  };
  
  /* startup stuff */
  public function onLoad () {
    Key.addListener(this);
    this.stop();
    this.setdir(2);
    this.stopmoving();
    this.doscale();	

    this.allowkeys = true;
  }

  public function say(s : String) {
    // this["saybox"].text = s;
    sayex(s, 50);
  }
	
  /* XXX should enqueue? */
  public function sayex(s : String, nframes : Number) {
    _root["familiar"].spoken = s;
    _root["familiar"].speakframesleft = nframes;
  }

  public function doscale() {

    /* sizebox has lower-left registration */
    var p;
    this["sizebox"].localToGlobal(p={x:this["sizebox"]._x,
				     y:this["sizebox"]._y});
    var feety = p.y;

    /* fraction of distance from front to back 
       of frustum. assumes 'scale' has center
       registration point. */
    var deepy  = _root.scale._y - (_root.scale._height/2);
    // var closey = _root.scale._y + (_root.scale._height/2);
    var deepness = _root.scale._height;
    var curdepth = feety - deepy;

    var targheight = 
      /* base height */
      _root.farheight._height + 
      /* amount gained from back to front */
      ((_root.closeheight._height - _root.farheight._height) *
       /* depth fraction */
       (curdepth / deepness));

    this._xscale =
      this._yscale = 100 * (targheight / this["sizebox"]._height);

    this.setdepth(this._y);

    /* and also put the familiar in the right place */
    _root["familiar"].relocate();
  }

  public function warp(cx, cy, dd) {
    /* my registration mark is centered */
    this._x = cx;
    /* but a bit high for doors (Which are on floor) */
    /* XXX better way to do this? perim? */
    this._y = cy - (this._height * 0.33);

    /* face player in the correct direction */
    this.stopmoving();
    this.setdir(dd);
    this.stopmoving();
    this.doscale();
  }


  public function allhit(mc) {
    var i;
    for(i in this["perim"]) {
      var p;
      this["perim"].localToGlobal(p={x:this["perim"][i]._x,
				     y:this["perim"][i]._y});
      if (!mc.hitTest(p.x, p.y, true)) {
	return false;
      }
    }
    return true;
  }

  public function anyhit(mc) {
    var i;
    for(i in this["perim"]) {
      var p;
      this["perim"].localToGlobal(p={x:this["perim"][i]._x,
				     y:this["perim"][i]._y});
      if (mc.hitTest(p.x, p.y, true)) {
	return true;
      }
    }
    return false;
  }


  public function move(dx, dy) {
    /* if we hit a door, then change scenes */
    {
      var d;
      for(d in _root.doors) {
	var mcd = _root.doors[d];
	/* must be going the correct dir, and
	   have actually hit the door */
	if ((this.dir == mcd.dir ||
	     this.dir == mcd.altdir) &&
	    anyhit(mcd) &&
	    /* will announce if blocked... */
	    mcd.active()) {

	  /* warp */

	  /* set my doortarget. when the door loads,
	     it checks my target and maybe moves me
	     there. */
	  this.doordest = mcd.doortarget;
	  // trace("targ: " + mcd.doortarget);

	  /* nb this invalidates mcd */
	  this.changeframe(mcd.frametarget);
	  this.stopmoving ();
	  
	  /* and don't allow keys until
	     the door restores us. (in future, might
	     even want doors to trigger cutscenes,
	     etc.) */
	  this.allowkeys = false;

	}
      }
    }

    var oldx = this._x;
    var oldy = this._y;
    this._x += dx;
    this._y += dy;

    /* if our feet went out of floor, then forget it */
    if (!allhit(_root.floor)) {
      this._x = oldx;
      this._y = oldy;
      this.stopmoving();
      this.dir = 0;
      return false;
    } 

    this.doscale();
    return true;
  }

  /* go to a frame, doing cleanup and
     initialization... */
  public function changeframe(s : String) {
    /* clear doors */
    _root["doors"] = [];
    _root.gotoAndStop(s);
  }

  public function stopmoving () {
    this.dir = 0;
    /* keep facing the same direction,
       but stand still */
    this["body"].gotoAndStop(1);
  }

  public function setdir (d:Number) {
    /* moving twice means stop. */
    if (this.dir == d) {
      this.stopmoving();
    } else {
      this.dir = d;
      this.gotoAndStop(d);
      this["body"].play();
    }
  }
	


  /* 
   */

}
