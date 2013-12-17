
var counter = 0, skipped = 0;
var start_time = (new Date()).getTime();

// Number of elapsed frames in the current scene.
var frames = 0;

var PHASE_TITLE = 0, PHASE_PLAYING = 1,
  PHASE_CUTSCENE = 2;
var phase = PHASE_TITLE;

var scrollx = 0;
var dollars = 0;

var resources = new Resources(
  ['alone.png',
   'alone2.png',
   'killed.png',
   'alley-mask.png',
   'alley.png',
   'secret.png',
   'secret-mask.png',
   'coin.png',
   'utoh.png',
   'accused.png',
   'beach.png',
   'beach-mask.png',
   'schoolfront.png',
   'schoolfront-mask.png',
   'street.png',
   'street-mask.png',
   'font.png',
   'walk1.png',
   'walk2.png',
   'walk3.png',
   'jump.png',
   'blink.png',
   'punch.png',
   'punch2.png',
   'kick.png',
   'kick2.png',
   'ouch.png',
   'stunned.png',
   'title.png',
   'dead.png',
   'blank.png',
   'z.png',
   'confrontation.png',
   'coinflip1.png',
   'coinflip2.png',
   'coinflip3.png',
   'coinflip3b.png',
   'coinflip4.png',
   'coinground.png',
   'leeback.png',
   'shock.png',
   'leedown.png',
   'leedown2.png',
   'fishroom.png',
   'classroom.png',
   'classroom-mask.png'],
  ['fishbowl.wav',
   'jump1.wav',
   'jump2.wav',
   'jump3.wav',
   'land1.wav',
   'land2.wav',
   'land3.wav',
   'coin.wav',
   'dead.wav',
   'hit1.wav',
   'hit2.wav',
   'hit3.wav',
   'hit4.wav',
  ], audioctx);

var lasthit = -1;
var cutscene_idx = 0;
var cutscene = null;
// Initialized in Init.
var cutscenes = {};
// Continuation to run after cutscene ends.
// XXX Move into cutscene object
var after_cutscene = function () { throw 'no cutscene cont'; };
function SetPhase(p) {
  frames = 0;
  // XXX clear other state

  phase = p;

  switch (phase) {
    case PHASE_PLAYING:
    if (currentroom.music) {
      if (song != currentroom.music) {
	StartSong(currentroom.music);
      }
    } else {
      ClearMusic();
    }
    break;
    case PHASE_TITLE:
      StartSong(song_overworld);
    break;
    case PHASE_CUTSCENE:
      cutscene_idx = -1;
      NextCutScene();
    break;
  }
}

// Holds a list of strings that we want drawn.
var textpages = [];
// Index within textpages[0]. If you modify the
// first element, make sure to clear this.
var textidx = 0;
function UpdateText() {
  if (TextDone()) return;
  if (textidx >= textpages[0].length) {
    // XXX some pause time here.
    if (holdingSpace || holdingZ) {
      textpages.shift();
      textidx = 0;
    } else {
      font.Draw(ctx, 4, TOP + GAMEHEIGHT + 1,
		textpages[0]);
      // XXX Blink?
      // indicate with graphic
      ctx.drawImage(resources.Get('z.png'),
		    WIDTH - 16,
		    HEIGHT - 16);
    }
  } else {
    textidx++;
    font.Draw(ctx, 4, TOP + GAMEHEIGHT + 1,
	      textpages[0].substr(0, textidx));
  }
}

function TextDone() {
  return textpages.length == 0;
}

function ClearText() {
  textpages = [];
  textidx = 0;
}

function NextCutScene() {
  // cutscene_idx holds the currently shown
  // cutscene state (or -1 if we're just
  // starting)
  cutscene_idx++;
  frames = 0;
  ClearText();

  if (cutscene_idx >= cutscene.desc.length) {
    ClearSong();
    // XXX from obj
    (0, after_cutscene)();
    return;
  }
  
  var state = cutscene.desc[cutscene_idx];
  if (song != state.s) {
    StartSong(state.s);
  }

  if (state.fx) {
    PlaySound(state.fx);
  }

  var t = state.t || ['              ...  '];
  textpages = t;
}

var holdingLeft = false, holdingRight = false,
  holdingUp = false, holdingDown = false,
  holdingSpace = false, holdingEnter = false,
  holdingX = false, holdingZ = false;

document.onkeydown = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  switch (e.keyCode) {
    case 9:
    // CHEATS
    if (true || DEBUG)
      textpages = [];
    break;
    case 27: // ESC
    if (true || DEBUG) {
      ClearSong();
      document.body.innerHTML = '(SILENCED. RELOAD TO PLAY)';
      // n.b. javascript keeps running...
    }
    break;
    case 8: // BACKSPACE
    if (DEBUG) {
      gang = null;
    }
    break;
    case 37: // LEFT
    holdingLeft = true;
    break;
    case 38: // UP
    holdingUp = true;
    break;
    case 39: // RIGHT
    holdingRight = true;
    break;
    case 40: // DOWN
    holdingDown = true;
    break;
    case 32: // SPACE
    holdingSpace = true;
    break;
    case 13: // ENTER
    holdingEnter = true;
    break;
    case 90: // Z
    holdingZ = true;
    break;
    case 88: // X
    holdingX = true;
    break;
  } 
  // var elt = document.getElementById('key');
  // elt && (elt.innerHTML = 'key: ' + e.keyCode);
  return false;
}

document.onkeyup = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  switch (e.keyCode) {
    case 37: // LEFT
    holdingLeft = false;
    break;
    case 38: // UP
    holdingUp = false;
    break;
    case 39: // RIGHT
    holdingRight = false;
    break;
    case 40: // DOWN
    holdingDown = false;
    break;
    case 32: // SPACE
    holdingSpace = false;
    break;
    case 13: // ENTER
    holdingEnter = false;
    break;
    case 90: // Z
    holdingZ = false;
    break;
    case 88: // X
    holdingX = false;
    break;
  }
  return false;
}

function CutScene(desc) {
  this.desc = desc;
  // ...
}



// The 'f' field must be something that you can ctx.drawImage on,
// so an Image or Canvas.
function Frames(arg) {
  if (arg instanceof Image) {
    // Assume static.
    this.frames = [{f: arg, d: 1}];
  } else {
    // Assume list.
    this.frames = arg;
  }
  
  var ct = 0;
  for (var i = 0; i < this.frames.length; i++) {
    ct += this.frames[i].d;
  }
  this.numframes = ct;

  this.GetFrame = function(idx) {
    var f = idx % this.numframes;
    for (var i = 0; i < this.frames.length; i++) {
      if (f < this.frames[i].d) {
	return this.frames[i].f;
      }
      f -= this.frames[i].d;
    }
    return this.frames[0].f;
  };
  if (this.frames.length == 0) throw '0 frames';
  // alert(this.frames[0].f);
  this.height = this.frames[0].f.height;
  this.width = this.frames[0].f.width;
}

function Static(f) { return new Frames(resources.Get(f)); }
var MASK_CLEAR = 0, MASK_CLIP = 1, MASK_LEDGE = 2;
function Room(bg, mask, music, gang) {
  this.bg = bg;
  this.width = bg.width;
  this.height = bg.height;
  this.mask_debug = resources.Get(mask);
  this.mask = Buf32FromImage(resources.Get(mask));
  this.gang = gang;
  this.music = music;
  // ...?
  this.MaskAt = function(x, y) {
    x = Math.round(x);
    y = Math.round(y);

    // Can't leave screen?
    if (x < 0 || y < 0 || x >= this.width || y >= this.height)
      return MASK_CLIP;

    var p = this.mask[this.width * y + x];
    // console.log(x + ' ' + y + ': ' + p);
    // Note, must be unsigned shift!
    if ((p >>> 24) > 10) {
      // console.log(x + ' ' + y + ': ' + p);
      // Assuming just magenta and green, resp.
      if (p & 255 > 10) return MASK_CLIP;
      else return MASK_LEDGE;
    } else {
      return MASK_CLEAR;
    }
  };
  
  // Find the safe spot if we are jumping down from
  // a ledge at x,y. Returns integer y.
  this.GetJumpDown = function(x, y) {
    x = Math.round(x);
    y = Math.round(y);
    var rem = GAMEHEIGHT - y;
    for (var i = 0; i < rem; i++) {
      var m = this.MaskAt(x, y + i);
      // OK to jump down to another ledge
      if (m == MASK_CLEAR || m == MASK_LEDGE) {
	return { x: x, y: y + i, i: i };
      }
    }
    // Bad level.
    console.log('ledge has no jump-down.');
    return null;
  }
}

// Assumes a list ['frame', n, 'frame', n] ...
// where frame doesn't even have 'png' on it.
// But it must have been loaded into Resources.
// TODO: Pass the same list to EzImages or
// something.
function EzFrames(l) {
  if (l.length % 2 != 0) throw 'bad EzFrames';
  var ll = [];
  for (var i = 0; i < l.length; i += 2) {
    var s = l[i];
    var f = null;
    if (typeof s == 'string') {
      f = resources.Get(l[i] + '.png');
      if (!f) throw ('could not find ' + s + '.png');
    } else if (s instanceof Element) {
      // Assume [canvas] or Image
      f = s;
    }
    ll.push({f: f, d: l[i + 1]});
  }
  return new Frames(ll);
}

// Returns a canvas of the same size with the pixels flipped horizontally
function EzFlipHoriz(img) {
  if (typeof img == 'string') img = resources.Get(img + '.png');

  var i32 = Buf32FromImage(img);
  var c = NewCanvas(img.width, img.height);
  var ctx = c.getContext('2d');
  var id = ctx.createImageData(img.width, img.height);
  var buf = new ArrayBuffer(id.data.length);
  // Make two aliases of the data, the second allowing us
  // to write 32-bit pixels.
  var buf8 = new Uint8ClampedArray(buf);
  var buf32 = new Uint32Array(buf);

  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      buf32[y * img.width + x] =
	  i32[y * img.width + (img.width - 1 - x)];
    }
  }
  
  id.data.set(buf8);
  ctx.putImageData(id, 0, 0);
  return c;
}

function EzColor(img, shirt, pants, hair) {
  if (typeof img == 'string') img = resources.Get(img + '.png');

  var i32 = Buf32FromImage(img);
  var c = NewCanvas(img.width, img.height);
  var ctx = c.getContext('2d');
  var id = ctx.createImageData(img.width, img.height);
  var buf = new ArrayBuffer(id.data.length);
  // Make two aliases of the data, the second allowing us
  // to write 32-bit pixels.
  var buf8 = new Uint8ClampedArray(buf);
  var buf32 = new Uint32Array(buf);

  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      var p = i32[y * img.width + x];
      if (p == 0xFFFF00EA) {
	p = shirt;
      } else if (p == 0xFFF0FF00) {
	p = pants;
      } else if (p == 0xFF00FFFF) {
	p = hair;
      }
      buf32[y * img.width + x] = p;
    }
  }
  
  id.data.set(buf8);
  ctx.putImageData(id, 0, 0);
  return c;
}

function PersonGraphics(shirt, pants, hair) {
  var walk1 = EzColor('walk1', shirt, pants, hair);
  var walk2 = EzColor('walk2', shirt, pants, hair);
  var walk3 = EzColor('walk3', shirt, pants, hair);
  var blink = EzColor('blink', shirt, pants, hair);
  var jump = EzColor('jump', shirt, pants, hair);
  var punch = EzColor('punch', shirt, pants, hair);
  var punch2 = EzColor('punch2', shirt, pants, hair);
  var kick = EzColor('kick', shirt, pants, hair);
  var kick2 = EzColor('kick2', shirt, pants, hair);
  var dead = EzColor('dead', shirt, pants, hair);
  var ouch = EzColor('ouch', shirt, pants, hair);
  var stunned = EzColor('stunned', shirt, pants, hair);

  return {
    run_right: EzFrames([walk1, 3, walk2, 2, walk3, 3, walk2, 2]),
    run_left: EzFrames([EzFlipHoriz(walk1), 3, 
			EzFlipHoriz(walk2), 2, 
			EzFlipHoriz(walk3), 3, 
			EzFlipHoriz(walk2), 2]),
    right: EzFrames([walk2, 4 * 30, blink, 2]),
    left: EzFrames([EzFlipHoriz(walk2), 4 * 30, 
		    EzFlipHoriz(blink), 2]),
    jump_right: EzFrames([jump, 1]),
    jump_left: EzFrames([EzFlipHoriz(jump), 1]),
    punch_right: EzFrames([punch, 2, punch2, 30]),
    punch_left: EzFrames([EzFlipHoriz(punch), 2, 
			 EzFlipHoriz(punch2), 30]),
    kick_right: EzFrames([kick, 2, kick2, 30]),
    kick_left: EzFrames([EzFlipHoriz(kick), 2, 
			 EzFlipHoriz(kick2), 30]),
    // For actually dying, can flicker
    ko_right: EzFrames([dead, 1]),
    ko_left: EzFrames([EzFlipHoriz(dead), 1]),

    dead_right: EzFrames([dead, 2, 'blank', 2]),
    dead_left: EzFrames([EzFlipHoriz(dead), 2, 'blank', 2]),

    hurt_right: EzFrames([ouch, 1, stunned, 1]),
    hurt_left: EzFrames([EzFlipHoriz(ouch), 1, 
			 EzFlipHoriz(stunned), 1])
  };
}

function Init() {
  // XXX Music tweaks. These should be built by dumpmidi...
  song_boss.multiply = 1.25;
  // song_boss[0].volume = 0.25;
  song_boss[2].volume = 0.65;
  song_vampires.multiply = 1.1;
  song_store.multiply = 1.33;

  window.rooms = {
    fishroom: new Room(Static('fishroom.png'),
		       'classroom-mask.png',
		       song_overworld,
		       new Gang([])),
    beach: new Room(Static('beach.png'),
		    'beach-mask.png',
		    song_overworld,
		    new Gang([])),
    alley: new Room(Static('alley.png'),
		    'alley-mask.png',
		    song_overworld, // something danker?
		    new Gang([])),
    street: new Room(Static('street.png'),
		     'street-mask.png',
		     song_overworld,
		     new Gang(
		       [{ name: 'Hank', 
			  shirt: 0xFF123456, pants: 0xFF987654, hair: 0xFF000088,
			  x: 194, y: 98,
			  hp: 5 },
			{ name: 'Bo', 
			  shirt: 0xFF123456, pants: 0xFF987654, hair: 0xFF000000,
			  x: 253, y: 111,
			  hp: 5 },
			{ name: 'Fred', 
			  shirt: 0xFF123456, pants: 0xFF987654, hair: 0xFF000000,
			  x: 239, y: 86,
			  hp: 5 }])),

    schoolfront: new Room(Static('schoolfront.png'),
			  'schoolfront-mask.png',
			  song_overworld,
			  new Gang(
			    [{ name: 'Derek', 
			       shirt: 0xFF123456, pants: 0xFF765400, hair: 0xFF000000,
			       x: 194, y: 98,
			       hp: 8 },
			     { name: 'Marvin', 
			       shirt: 0xFF125688, pants: 0xFF007654, hair: 0xFF000000,
			       x: 253, y: 111,
			       hp: 10 },
			     { name: 'Chuck', 
			       shirt: 0xFF123456, pants: 0xFF987698, hair: 0xFF008888,
			       x: 239, y: 86,
			       hp: 20 },
			     { name: 'Boris', 
			       shirt: 0xFFFFFFFF, pants: 0xFFFFFFFF, hair: 0xFF000000,
			       x: 320, y: 86,
			       hp: 15 } ])),
    
    secret: new Room(Static('secret.png'),
		     'secret-mask.png',
		     song_store,
		     new Gang([])),

    classroom: new Room(Static('classroom.png'),
			'classroom-mask.png',
			song_boss,
			new Gang(
			  [{ name: 'N. Lee',
			     shirt: 0xFF00A8FF, pants: 0xFF454A59, hair: 0xFF00FCFF,
			     x: 237, y: 110,
			     hp: 50 }] ))
  };

  window.cutscenes = {
    intro: new CutScene(
      [{ f: EzFrames(['killed', 1]),
	 s: song_vampires,
	 t: ['... when I was young my brother was\n' +
	     'killed in a karate tournament.'] },
       { f: EzFrames(['alone', 15, 'alone2', 15]),
	 s: song_escape,
	 t: ['So I spent a lot of time alone.\n'] }
      ]),
    fish: new CutScene(
      [{ f: EzFrames(['utoh', 1]),
	 // XXX in trouble music
	 s: null,
	 fx: 'fishbowl.wav',
	 t: ['Me: Oops...!'] },
       { f: EzFrames(['accused', 1]),
	 s: song_boss,
	 t: ['N. Lee: Who\'s there?',
	     'Me: Ut oh, it\'s N. Lee.',
	     'N. Lee: That\'s "JET" to you, Punky\n' +
	     'Brewsturd.\n' +
	     'Did you just kill the class fish?',
	     'Me: I think it might still be alive.',
	     'N. Lee: Well that was MY fishbowl,\n' +
	     'Rainbow Blight.',
	     'Me: ...',
	     'N. Lee: Got any dollars?\n' +
	     'Because it looks like\n' +
	     'you owe N. Lee ("Jet") one.']
       }]),
    confrontation: new CutScene(
      [{ f: EzFrames(['confrontation', 1]),
	 s: song_overworld, // ?
	 t: ['N. Lee: You again!',
	     'Me: Hey, I brought your dollar.\n' +
	     'I\'m really sorry about the fishbowl.',
	     'N. Lee: You better be, Magnum P.U.!\n' +
	     'Hand it over!'] },
       { f: EzFrames(['coinflip1', 20,
		      'coinflip2', 10,
		      'coinflip3', 10,
		      'coinflip3b', 10,
		      'coinflip4', 100000]),
	 // XXX pling sound effect
	 s: song_overworld, // ?
	 t: ['Me: Here you go.'] },
       { f: EzFrames(['coinground', 1]),
	 s: song_overworld, // ?
	 t: ['N. Lee: Oh, nice job, 21 Jerk Street,\n' +
	     'throwing it on the floor for me.'] },
       // XXX show him kneeling in classroom
       { f: EzFrames(['leeback', 20]),
	 // XXX move to kneeling anim
	 fx: 'coin.wav',
	 s: null, //
	 t: ['N. Lee: Heh heh, easy money.'] },

       { f: EzFrames(['killed', 1,
		      'leeback', 8,
		      'killed', 2,
		      'leeback', 5,
		      'killed', 3,
		      'leeback', 4,
		      'killed', 5,
		      'leeback', 2,
		      'killed', 7,
		      'leeback', 1,
		      'killed', 100000]),
	 fx: 'dead.wav',
	 s: song_vampires,
	 t: ['                         \n' +
	     '                         \n' +
	     '                         ...'] },
       { f: EzFrames(['shock', 1]),
	 s: song_vampires,
	 t: ['Me: It\'s YOU!!'] }]),
    win: new CutScene(
      [{ f: EzFrames(['leedown', 1]),
	 s: song_vampires,
	 t: ['Me: Hey, Jet, I just have one\n' +
	     'question.',
	     'N. Lee: Yeah?',
	     'Me: What does "N." stand for?',
	     'N. Lee: ...',
	     'Me: I just wanna know.',
	     'N. Lee: ... It stands for ...\n' +
	     '   ... Nilbourque.',
	     'Me: Damn, dude.',
	     'N. Lee: Yeah, that\'s why I go\n' +
	     'by N. or Jet.',
	     'Me: Yeah but damn.',
	     'N. Lee: ...          ',
	     'Me: It\'s a pretty dumb name.'] },
       { f: EzFrames(['leedown', 2, 'leedown2', 2,
		      'leedown', 2, 'leedown2', 2,
		      'leedown', 2, 'leedown2', 2,
		      'leedown', 2, 'leedown2', 2,
		      'leedown', 2, 'leedown2', 2,
		      'leedown2', 1000000]),
	 fx: 'dead.wav',
	 s: song_vampires, // ?
	 t: ['N. Lee: ...           \n' +
	     '                      \n' +
	     '                        ',
	     '\n' +
	     '        YOU WIN\n' +
	     '                        '] }])
  };

  window.me = new Human(PersonGraphics(0xFF7FFFFF, 0xFFEC7000, 0xFF000000));
  window.font = new Font(resources.Get('font.png'),
			 FONTW, FONTH, FONTOVERLAP, FONTCHARS);
}

// For a second playthrough...
function InitGame() {
  me.hp = 30;
  me.dollars = 0;
  me.name = 'Me';
}

// Sets up the context 
function WarpTo(roomname, x, y) {
  console.log('warpto ' + roomname);
  currentroom = rooms[roomname];
  me.x = x;
  me.y = y;
  // Keep velocity?
  me.dx = 0;
  me.dy = 0;

  lasthit = -1;
  // Room needs to define a spawn spot or something.
  // gang = new Gang(4, 0xFF123456, 0xFF987654, 0xFF000088);
  // XXX maybe should just do this directly
  gang = currentroom.gang;
}

function TitleStep(time) {
  ctx.drawImage(resources.Get('title.png'), 0, 0);
  if (holdingEnter || holdingSpace) {
    ClearSong();
    InitGame();

    cutscene = cutscenes.intro;
    after_cutscene = function () {
      WarpTo('fishroom', 77, 116);
      SetPhase(PHASE_PLAYING);
      ClearText();
      // textpages = ['Time to tend to my debts.'];
    };

    /*
    cutscene = cutscenes.confrontation;
    after_cutscene = function() {
      me.facingright = false;
      WarpTo('classroom', 394, 105);
      SetPhase(PHASE_PLAYING);
      ClearText();
    }
    */
    
    SetPhase(PHASE_CUTSCENE);
  }
}

// XXX crop rectangle version?
function DrawFrame(frame, x, y, opt_fc) {
  ctx.drawImage(frame.GetFrame(arguments.length > 3 ? opt_fc : frames), 
		Math.round(x), Math.round(y));
}

function Human(gfx) {
  this.gfx = gfx;
  this.x = WIDTH / 2;
  this.y = GAMEHEIGHT / 2;
  // Place on floor...
  // XXX if we don't have a room, this had better be me
  // (placed manually).
  if (window.currentroom) {
    for (var y = 0; y < GAMEHEIGHT - 1; y++) {
      if (currentroom.MaskAt(this.x, y) != MASK_CLIP) {
	this.y = y;
	break;
      }
    }
  }

  // 0 is floor
  this.z = 0;
  this.dx = 0;
  this.dy = 0;
  this.dz = 0;
  this.facingright = true;

  this.hp = 20;

  this.punching = 0;
  this.kicking = 0;
  this.ko = 0;
  this.hurt = 0;

  // frame counter.
  this.fc = 0;

  this.Depth = function() {
    return this.y;
  }

  this.Draw = function(scrollx) {
    var fr = this.gfx.right;

    var isjump = this.z > 0.01;

    var isrun = Math.abs(this.dx) > 1 || Math.abs(this.dy) > 0.25;

    if (this.ko > 0) {
      // XXX check if really dying
      if (this.hp <= 0) {
	fr = this.facingright ? this.gfx.dead_right : this.gfx.dead_left;
      } else {
	fr = this.facingright ? this.gfx.ko_right : this.gfx.ko_left;
      } 

    } else if (this.hurt > 0) {
      fr = this.facingright ? this.gfx.hurt_right : this.gfx.hurt_left;

    } else {
      // Turn the player around.
      // XXX Also should happen when standing still and first
      // tapping, right? Maybe useful to be able to back up.
      if (!isjump && isrun) {
	// Maybe shouldn't be updating this state in drawing...
	if (this.dx > 1) {
	  this.facingright = true;
	} else if (this.dx < -1) {
	  this.facingright = false;
	}
      }

      // XXX kicking, air attacks
      if (this.facingright) {
	if (isjump) {
	  // XXX air attacks
	  fr = this.gfx.jump_right;
	} else {
	  if (this.punching > 0) {
	    fr = this.gfx.punch_right;
	  } else if (this.kicking > 0) {
	    fr = this.gfx.kick_right;
	  } else {
	    fr = isrun ? this.gfx.run_right : this.gfx.right;
	  }
	}
      } else {
	if (isjump) {
	  // XXX air attacks
	  fr = this.gfx.jump_left;
	} else {
	  if (this.punching > 0) {
	    fr = this.gfx.punch_left;
	  } else if (this.kicking > 0) {
	    fr = this.gfx.kick_left;
	  } else {
	    fr = isrun ? this.gfx.run_left : this.gfx.left;
	  }
	}
      }
    }
    DrawFrame(fr, this.x - scrollx - fr.width / 2, 
	      this.y - this.z + TOP - fr.height + ME_FEET,
	      this.fc);
    this.fc++;
  };

  // XXX objects should also have physics, using some of the same methods
  this.UpdatePhysics = function(objects) {
    var onground = this.z == 0;

    // XX no air attacks implemented. But allow them
    var canattack = this.hurt == 0 && this.ko == 0 && onground;

    if (!canattack) {
      // For example if killed while throwing a punch.
      this.punching = 0;
      this.kicking = 0;

    } else if (this.punching == 0 &&
	       this.kicking == 0) {
      if (this.holdingX) {
	// Depending on air/floor?
	this.punching = PUNCHFRAMES;
	// Need to reset animation offset when starting a
	// non-looping pose like this.
	this.fc = 0;
      } else if (this.holdingZ) {
	this.kicking = KICKFRAMES;
	this.fc = 0;
      }

    } else if (this.punching > 0) {
      this.punching--;

    } else if (this.kicking > 0) {
      this.kicking--;
    }

    if (this.ko > 0) {
      this.ko --;

    } else if (this.hurt > 0) {
      this.hurt --;

    }

    // Kicking makes you stop.
    var canmove = this.ko == 0;
    var canrun = canmove && (this.kicking == 0 || !onground);

    var kick_now = this.kicking == 2;
    var punch_now = this.punching == 2;
    // Dealing damage.
    if (punch_now || kick_now) {
      // Check non-self objects for hit.
      var ax = this.x + (this.facingright ? ATTACKSIZE_X : -ATTACKSIZE_X);
      for (var i = 0; i < objects.length; i++) {
	if (objects[i] != this) {
	  if (objects[i].hp >= 0 &&
	      Math.abs(objects[i].y - this.y) <= ATTACKSIZE_Y &&
	      Math.abs(objects[i].x - ax) <= HALFPERSON_W) {
	    // Hit! But are we allowed to hit them?
	    // XXX
	    if (objects[i].x < this.x) {
	      objects[i].dx -= 4;
	    } else {
	      objects[i].dx += 4;
	    }	    

	    // Save id so we can show its hp.
	    if ('id' in objects[i]) {
	      // console.log(objects[i].id + ' was hit');
	      lasthit = objects[i].id;
	    }

	    if (punch_now) {
	      objects[i].hp -= PUNCH_DAMAGE;
	    } else if (kick_now) {
	      objects[i].hp -= KICK_DAMAGE;
	    }

	    if (objects[i].hp <= 0 || Math.random() < 0.1) {
	      if (objects[i].hp <= 0) {
		// XXX randomly
		textpages.push(objects[i].name + ': BARF!!!');
		PlaySound('dead.wav');
	      }

	      objects[i].ko = objects[i].hp <= 0 ? DEADFRAMES : KOFRAMES;
	      objects[i].fc = 0;
	    } else {
	      PlayASound('hit', 4);
	      objects[i].hurt = HURTFRAMES;
	      objects[i].fc = 0;
	    }
	  }
	}
      }
    }

    // XXX being hurt should interfere somewhat?
    
    // Player physics.
    if (canmove && canrun && this.holdingRight) {
      this.dx += onground ? ACCEL_X : AIR_ACCEL_X;
    } else if (canmove && canrun && this.holdingLeft) {
      this.dx -= onground ? ACCEL_X : AIR_ACCEL_X;
    } else {
      if (onground) this.dx *= 0.8;
      if (Math.abs(this.dx) < 0.5) this.dx = 0;
    }

    if (canmove && this.holdingDown) {
      this.dy += onground ? ACCEL_Y : 0;
    } else if (canmove && holdingUp) {
      this.dy -= onground ? ACCEL_Y : 0;
    } else {
      // Always decelerate y, even in air
      this.dy *= 0.6;
      if (Math.abs(this.dy) < 0.5) this.dy = 0;
    }

    if (onground) {
      if (canmove && this.holdingSpace) {
	// XXX this won't work, it's an alias.
	// this.holdingSpace = false;
	this.dz += JUMP_IMPULSE;
	PlayASound('jump', 3);
      }
    } else {
      this.dz -= GRAVITY;
    }
    if (Math.abs(this.dz) < 0.01) this.dz = 0;

    if (this.dx > TERMINAL_X) this.dx = TERMINAL_X;
    else if (this.dx < -TERMINAL_X) this.dx = -TERMINAL_X;

    if (this.dy > TERMINAL_Y) this.dy = TERMINAL_Y;
    else if (this.dy < -TERMINAL_Y) this.dy = -TERMINAL_Y;

    if (this.dz > TERMINAL_Z) this.dz = TERMINAL_Z;
    else if (this.dz < -TERMINAL_Z) this.dz = -TERMINAL_Z;

    // XXX collisions.

    // x is simple
    if (this.dx != 0) {
      var startmask = currentroom.MaskAt(this.x, this.y);
      // unit dx, either 1 or -1
      var ux = this.dx / Math.abs(this.dx);
      // console.log(ux);

      // As we enter the loop, this.x will be in a valid location.
      for (var i = 0; Math.abs(i) < Math.abs(this.dx); i += ux) {
	var m = currentroom.MaskAt(this.x + ux, this.y);
	// console.log(m);
	// XXX actually should allow this from a ledge; then
	// you convert y to z and fall.
	if (m == MASK_CLIP) break;
	// Can't walk onto ledge.
	if (m == MASK_LEDGE && m != startmask) break;

	if (startmask == MASK_LEDGE && m != MASK_LEDGE) {
	  console.log('stay on ledge x');
	  // XXX should be possible to walk into free space
	  // and fall.
	  break;
	}
	this.x += ux;
      }
    }

    // y is easy too, though we need to allow converting down
    if (this.dy != 0) {
      var startmask = currentroom.MaskAt(this.x, this.y);
      var uy = this.dy / Math.abs(this.dy);

      for (var i = 0; Math.abs(i) < Math.abs(this.dy); i += uy) {
	var m = currentroom.MaskAt(this.x, this.y + uy);
	// console.log(m);
	// Clip usually stops us, but we can ledge transfer.
	if (m == MASK_CLIP) {
	  // must be moving down.
	  // XXX maybe HOLDING down?
	  if (startmask == MASK_LEDGE && this.dy > 0) {
	    // must be able to find a safe position.
	    // n.b. level designers should always put
	    // sufficient MASK_CLEAR somewhere beneath
	    // ledges.
	    var offset = currentroom.GetJumpDown(this.x, this.y + uy);
	    if (offset) {
	      console.log('ledge drop! ' + offset.y + ' ' + offset.i);
	      // Rounds to ints, to ensure invariants
	      this.x = offset.x;
	      this.y = offset.y;
	      // Make it easier to drop down to narrow ledges.
	      this.dy = 0;
	      // Any fake ledge height we had becomes z,
	      // which makes us look like we're in the same spot.
	      this.z = offset.i;
	    }
	  }
	  // In any case, stop applying y force this turn.
	  break;
	}
	// Can't walk onto ledge from anything but ledge.
	if (m == MASK_LEDGE && m != startmask) break;
	if (startmask == MASK_LEDGE && m != MASK_LEDGE) {
	  // Prevent walking UP off ledges onto CLEAR.
	  // Walking down is covered in the CLIP case,
	  // assuming there is clip below (normal).
	  console.log('stay on ledge y');
	  break;
	}
	this.y += uy;
      }
    }

    // Always apply the z vector.
    // XXX apply in increments so we can test each pixel for
    // ledge transfer.
    this.z += this.dz;
    // If we are moving down but holding 'up', allow landing
    // on a ledge.
    if (this.dz < 0 && this.holdingUp) {
      // Where does it look like our feet are?
      var xx = Math.round(this.x);
      var yy = Math.round(this.y - this.z);
      var m = currentroom.MaskAt(xx, yy);
      if (m == MASK_LEDGE) {
	// XXX play "landing" animation
	console.log('ledge transfer!');
	PlayASound('land', 3);
	// Convert to y coords, losing z height.
	this.x = xx;
	this.y = yy;
	this.z = 0;
	this.dz = 0;
      }
    }

    // XXX maybe don't need if we use mask? -- or warps only?
    if (this.x < 0) {
      // XXX warp left if we can
      this.x = 0;
      this.dx = 0;
    }
    
    if (this.y > GAMEHEIGHT) {
      this.y = GAMEHEIGHT;
      this.dy = 0;
    } /* else if (this.y < WALLHEIGHT) {
      // XXX should be possible to stand on that stuff maybe?
      this.y = WALLHEIGHT;
      this.dy = 0;
    } */

    if (DEBUG) {
      debug.innerHTML = this.dx + ' ' + this.dy + ' ' + this.dz +
	  ' @ ' + this.x + ' ' + this.y + ' ' + this.z +
	  (this.punching > 0 ? (' punching ' + this.punching) : '') +
	  (this.facingright ? ' >' : ' <');
    }

    if (this.z < 0) {
      // XXX play "landing" animation
      PlayASound('land', 3);
      this.z = 0;
      this.dz = 0;
    }
  };

}

// TODO: fighting style, hats, and so on.
function Gang(l) {
  var NATTACKERS = 2;

  // Or get stuff, etc.
  var S_ATTACK = 0, S_CONFRONT = 1; // , S_AVOID = 2;
  
  this.humans = [];
  for (var i = 0; i < l.length; i++) {
    var g = l[i];
    var gfx = PersonGraphics(g.shirt, g.pants, g.hair);
    var h = new Human(gfx);
    h.name = g.name;
    if ('hp' in g) h.hp = g.hp;
    h.x = g.x;
    h.y = g.y;
    h.strategy = S_CONFRONT;
    h.id = i;
    this.humans.push(h);
    // Anything else??
  }
  
  this.AddObjects = function(l) {
    for (var i = 0; i < this.humans.length; i++) {
      l.push(this.humans[i]);
    }
  };

  this.Reap = function() {
    for (var i = 0; i < this.humans.length; i++) {
      var h = this.humans[i];
      if (h.ko == 1 && h.hp <= 0) {
	// Dead!
	this.humans.splice(i, 1);
	i--;
      }
    }
    
    if (this.humans.length > 0) return this;
    else return null;
  };
  
  this.UpdateStrategies = function() {

    if (this.humans.length == 0) return;

    var player_on_ledge = 
	MASK_LEDGE == currentroom.MaskAt(me.x, me.y);

    // Maybe change strategies.
    // Nobody attack when I'm on the ground.
    if (me.ko > 0) {
      for (var i = 0; i < this.humans.length; i++) {
	this.humans[i].strategy = S_CONFRONT;
      }
    } else {
      // Are enough people attacking?
      var na = 0;
      for (var i = 0; i < this.humans.length; i++) {
	if (this.humans[i].strategy == S_ATTACK) {
	  na++;
	}
      }

      if (na < NATTACKERS) {
	// Someone becomes an attacker (possibly someone
	// who already was..)
	var i = Math.round(Math.random() * (this.humans.length - 1));
	// console.log(na + ' so making #' + i + ' an attacker');
	this.humans[i].strategy = S_ATTACK;
      }
    }

    // Implement strategies.
    for (var i = 0; i < this.humans.length; i++) {
      var human = this.humans[i];
      var onledge = MASK_LEDGE == currentroom.MaskAt(human.x, human.y);
      // Figure out our destination.
      var destx = 0, desty = 0;
      switch (human.strategy) {
	case S_ATTACK:
	// Pick one side or the other of me.
	if (typeof human.attack_right != 'boolean') {
	  human.attack_right = Math.random() > 0.5;
	}
	destx = me.x + (human.attack_right ? ATTACKSIZE_X : -ATTACKSIZE_X);
	desty = me.y;
	break;
	case S_CONFRONT:
	if (!human.confront_vec) {
	  // Pick a random normalized vector.
	  // (It doesn't matter, but maybe this is not uniform)
	  var xx = Math.random() - 0.5, yy = Math.random() - 0.5;
	  var d = Math.sqrt(xx * xx + yy * yy);
	  xx /= d; yy /= d;
	  human.confront_vec = {x: xx, y: yy};
	}
	
	// XXX: This should change based on how the fight is going,
	// I think.
	var confront_dist_x = 100;
	var confront_dist_y = 24;
	var cv = human.confront_vec;
	destx = Math.round(me.x + cv.x * confront_dist_x);
	desty = Math.round(me.x + cv.y * confront_dist_y);

	break;
      }
      
      // XXX snap destx, desty to be within level?
      // physics will do this for us, but it's maybe
      // just smarter AI to only try to get to sensible
      // places?

      var xdist = Math.abs(destx - human.x);


      // allow turning around too
      human.holdingRight = (human.x < destx) && xdist > 16;
      human.holdingLeft = (human.x > destx) && xdist > 16;

      // XXX This doesn't work. Fix it!
      /* 
	var facingme = human.facingRight ? (human.x < me.x) : (human.x > me.x);
      if (!(human.holdingRight ||
	    human.holdingLeft)) {
	if (!facingme) {
	  if (human.x < me.x) {
	    human.holdingRight = true;
	  } else if (human.x > me.x) {
	    human.holdingLeft = true;
	  }
	}
      }
      */

      // Get off ledge if I'm on one and the player is not.
      human.holdingDown = (human.y < desty) ||
	  (onledge && !player_on_ledge && Math.random() < 0.02);

      // Try to jump onto ledges if the player is on one.
      human.holdingUp = !human.holdingDown && 
	  ((human.y > desty) ||
	   (human.z > 0 && player_on_ledge));

      // When to jump?
      human.holdingSpace = (Math.random() < 0.025);

      // XXX based on strategy. Don't be so crazy active
      // when confronting
      human.holdingX = Math.random() < 0.05;
      human.holdingY = Math.random() < 0.05;
    }
  };

  this.UpdatePhysics = function(objects) {
    for (var i = 0; i < this.humans.length; i++) {
      // not the best strategy
      this.humans[i].UpdatePhysics(objects);
    }
  };
}

function CutSceneStep(time) {
  var scene = cutscene.desc[cutscene_idx];

  // Could be configurable by cutscene
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  if (scene.f)
    DrawFrame(scene.f, 0, TOP);

  UpdateText();

  // XXX allow timer too, where condition is
  // TextDone() && enough_time
  if (TextDone()) {
    NextCutScene();
  }
}

function PlayingStep(time) {
  // XXX once we start scrolling, scroll ahead of
  // where the player's going
  if (me.x < scrollx + 75) scrollx = me.x - 75;
  else if (me.x > scrollx + WIDTH - 125)
    scrollx = me.x - WIDTH + 125;

  // Snap scrollx to background extent
  // XXX if room width is smaller than screen, center.
  if (scrollx + WIDTH > currentroom.width)
    scrollx = currentroom.width - WIDTH;
  if (scrollx < 0) scrollx = 0;

  var objects = [];
  if (gang) gang.AddObjects(objects);
  objects.push(me);

  me.holdingRight = holdingRight;
  me.holdingLeft = holdingLeft;
  me.holdingUp = holdingUp;
  me.holdingDown = holdingDown;
  me.holdingSpace = holdingSpace;

  me.holdingZ = holdingZ;
  me.holdingX = holdingX;

  me.UpdatePhysics(objects);

  if (gang) {
    gang.UpdateStrategies();
    gang.UpdatePhysics(objects);
    gang = gang.Reap();
  }

  // Redraw everything every frame (!)
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  DrawFrame(currentroom.bg, -scrollx, TOP);
  // XXX no!
  if (false && DEBUG)
    ctx.drawImage(currentroom.mask_debug, -scrollx, TOP);

  if (me.dollars == 0 && currentroom == rooms.alley) {
    ctx.drawImage(resources.Get('coin.png'),
		  158 - scrollx, 88 + TOP);
  }

  objects.sort(function (a, b) { return b.Depth () < a.Depth(); });
  for (var i = 0; i < objects.length; i++) {
    objects[i].Draw(scrollx);
  }

  // XXX Handle case where I die!

  // XXX real text status
  font.Draw(ctx, 2, 2, 'HP: ' + me.hp + ' $' + me.dollars);
  if (currentroom == rooms.beach &&
      currentroom == rooms.fishroom) {
    font.Draw(ctx, 160, 2, 'arrows/z/x/space');
  } else {
    var found = false;
    // console.log(lasthit);
    if (gang) {
      for (var i = 0; i < gang.humans.length; i++) {
	if (gang.humans[i].id == lasthit) {
	  font.Draw(ctx, 160, 2,
		    gang.humans[i].name + ': ' + 
		    gang.humans[i].hp);
	  found = true;
	}
      }
    }
    if (!found) {
      // console.log('not found');
      font.Draw(ctx, 160, 2, 'arrows/z/x/space');
    }
  }

  UpdateText();

  if (me.ko == 1 && me.hp <= 0) {
    textpages = ['\n       FREE PLAY MODE  '];
    PlaySound('coin.wav');
    me.ko = 0;
    me.hp = 30;
    me.dz = JUMP_IMPULSE;
  }

  // Room-specific logic and triggers.
  if (currentroom == rooms.fishroom && me.x > 244) {
    after_cutscene = function() {
      WarpTo('beach', 77, 116);
      SetPhase(PHASE_PLAYING);
      ClearText();
      textpages = ['THE NEXT DAY.',
		   'Me: Time to tend to my debts.'];
    };
    cutscene = cutscenes.fish;
    SetPhase(PHASE_CUTSCENE);

  } else if (currentroom == rooms.beach) {
    if (me.x > 608) {
      WarpTo('street', 43, 95);
      SetPhase(PHASE_PLAYING);
      ClearText();
      // XXX don't repeat text.
      textpages = ['OCEAN CITY.',
		   'Me: Someone around here must\n' +
		   'have a dollar I can borrow.',
		   'Hey guys, don\'t hurt me!'];
    } 

  } else if (currentroom == rooms.alley) {
    if (me.dollars == 0 && 
	me.x > 150 && me.x < 166 &&
	me.y > 80 && me.y < 96) {
      me.dollars = 1;
      PlaySound('coin.wav');
      textpages = ['Me: Great, a dollar!\n' +
		   'I can bring this to N. Lee\n' +
		   'at the school.'];
    } else if (me.y > 117) {
      WarpTo('street', 200, 60);
      ClearText();
      SetPhase(PHASE_PLAYING);
    }

  } else if (currentroom == rooms.street) {
    if (me.x < 21) {
      WarpTo('beach', 578, 93);
      ClearText();
      SetPhase(PHASE_PLAYING);
    } else if (me.x > 514) {
      WarpTo('schoolfront', 43, 95);
      ClearText();
      SetPhase(PHASE_PLAYING);
    } else if (me.x > 181 && me.x < 224 &&
	       me.y < 38) {
      WarpTo('alley', 112, 107);
      SetPhase(PHASE_PLAYING);
      ClearText();
    } else if (me.x > 234 && me.x < 272 &&
	       me.y < 12 && me.z > 8) {
      WarpTo('secret', 171, 103);
      me.z = 0;
      SetPhase(PHASE_PLAYING);
      ClearText();
      textpages = ['Me: Huh.',
		   'Me: Looks like someone was putting\n' +
		   'together a room here but didn\'t\n' +
		   'finish.'];
    }

  } else if (currentroom == rooms.secret) {
    if (me.x > 104 && me.x < 120 &&
	me.y > 79 && me.y < 95) {
      WarpTo('alley', 161, 71);
      me.z = 69;
      SetPhase(PHASE_PLAYING);
      ClearText();
      textpages = ['Me: Wheee!'];

    } else if (me.y > 122) {
      ClearText();
      textpages = ['Me: Climbing down doesn\'t seem\n' +
		   'safe to me.'];
      me.y = 121;
      me.dy = -3;
    }

  } else if (currentroom == rooms.schoolfront) {
    if (me.x < 21) {
      WarpTo('street', 491, 96);
      ClearText();
      SetPhase(PHASE_PLAYING);

    } else if (me.x > 422 && me.y > 33 &&
	       me.x < 475 && me.y < 40) {
      if (me.dollars > 0) {
	cutscene = cutscenes.confrontation;
	after_cutscene = function() {
	  me.dollars = 0;
	  me.facingright = false;
	  WarpTo('classroom', 394, 105);
	  SetPhase(PHASE_PLAYING);
	  ClearText();
	}
	SetPhase(PHASE_CUTSCENE);

      } else {
	ClearText();
	textpages = ['I better not show up without\n' +
		     'some money for N. Lee.'];
	me.y = 40;
	me.dy = 3;
      }
    }
  } else if (currentroom == rooms.classroom) {
    
    // trigger when killing boss.
    if (!gang || gang.humans.length == 0) {
      cutscene = cutscenes.win;
      after_cutscene = function() {
	// :)
	me.dollars = 1;
	ClearText();
	SetPhase(PHASE_TITLE);
      };
      SetPhase(PHASE_CUTSCENE);
    }

  }
}

last = 0;
function Step(time) {
  // Throttle to 30 fps or something we
  // should be able to hit on most platforms.
  // Word has it that 'time' may not be supported on Safari, so
  // compute our own.
  var now = (new Date()).getTime();
  var diff = now - last;
  // debug.innerHTML = diff;
  // Don't do more than 30fps.
  // XXX This results in a frame rate of 21 on RIVERCITY, though
  // I can easily get 60, so what gives?
  if (diff < MINFRAMEMS) {
    skipped++;
    window.requestAnimationFrame(Step);
    return;
  }
  last = now;
  

  frames++;
  if (frames > 1000000) frames = 0;

  switch (phase) {
  case PHASE_PLAYING:
    PlayingStep();
    break;
  case PHASE_CUTSCENE:
    CutSceneStep();
    break;
  case PHASE_TITLE:
    TitleStep();
    break;
  }

  // process music in any state
  UpdateSong();

  // On every frame, flip to 4x canvas
  bigcanvas.Draw4x(ctx);

  if (DEBUG) {
    counter++;
    var sec = ((new Date()).getTime() - start_time) / 1000;
    document.getElementById('counter').innerHTML = 
	'skipped ' + skipped + ' drew ' +
	counter + ' (' + (counter / sec).toFixed(2) + ' fps)';
  }

  // And continue the loop...
  window.requestAnimationFrame(Step);
}

function Start() {
  Init();

  // XXX do show the title!
  SetPhase(PHASE_TITLE);

  /*
  cutscene = cutscenes.intro;
  after_cutscene = function () {
    WarpTo('fishroom', 77, 116);
    SetPhase(PHASE_PLAYING);
    ClearText();
    textpages = ['Time to tend to my debts.'];
  };
  SetPhase(PHASE_CUTSCENE);
  */
  
  // XXX not this!
  // WarpTo('beach', 77, 116);
  // SetPhase(PHASE_PLAYING);

  start_time = (new Date()).getTime();
  window.requestAnimationFrame(Step);
}

resources.WhenReady(Start);
