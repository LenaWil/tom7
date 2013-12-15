
// Audio stuff.
// https://developer.apple.com/library/safari/documentation/AudioVideo/Conceptual/Using_HTML5_Audio_Video/PlayingandSynthesizingSounds/PlayingandSynthesizingSounds.html
var audioctx = new webkitAudioContext();
var TYPE_SINE = 0, TYPE_SQUARE = 1, TYPE_SAW = 2, TYPE_TRI = 3;

// Just for demo purposes
var r = 0x50, g = 0x80, b = 0xFE, a = 0xFF, f = 0xFFFFFF;
var note = null;

/*
  if (frames % 60 == 0) {
    var sine = audioctx.createOscillator();
    sine.type = TYPE_SINE;
    var lowpass = audioctx.createBiquadFilter();
    lowpass.type = 0; // LOWPASS
    lowpass.frequency.value = 1000;
    sine.connect(lowpass);
    lowpass.connect(audioctx.destination);

    sine.noteOn(0);
    note = sine;
  } else if (frames % 60 == 10) {
    note.noteOff(0);
    note = null;
  }
  frames++;
*/

function ClearSong() {
  // XXX
}

var MSPERTICK = 4.0;
function StartSong(s) {
  ClearSong();
  song = s;
  tracks = [];
  var now = (new Date()).getTime();
  for (var i = 0; i < song.length; i++) {
    var type = TYPE_SINE;
    switch (song[i].inst) {
      case 'SAW': type = TYPE_SAW;
      case 'SQUARE': type = TYPE_SQUARE;
      default: TYPE_SINE;
    }

    var notes = song[i].notes.slice(0);
    for (var j = 0; j < notes.length; j++) {
      notes[j].d *= MSPERTICK;
    }

    tracks.push({ type: type, 
		  notes: notes,
		  idx: 0,
		  active: [],
		  lastend: now,
		  });

  }
  
  UpdateSong(s);
}

function DoSoundEvent(tr, e, d) {
  if ('on' in e) {
    if (tr.active[e.on]) {
      // Don't want to leak...
      console.log ('double-on.');
      break;
    }

    var src = audioctx.createOscillator();
    src.type = tr.type;

    var lowpass = audioctx.createBiquadFilter();
    lowpass.type = 0; // LOWPASS
    lowpass.frequency.value = 8192;
    src.connect(lowpass);
    lowpass.connect(audioctx.destination);

    src.noteOn(d);
    tr.active[e.on] = src;

  } else if ('off' in e) {
    var src = tr.active[e.off];
    delete tr.active[e.off];
    if (src) {
      src.noteOff(d);
    }

  } else {
    console.log ('bad sound event');
  }
}

var MSPERSCHEDULE = 100.0;
function UpdateSong(s) {
  var now = (new Date()).getTime();

  // idx points to an event with some delta time.
  // we've already handled all the events up until
  // that point. The last time we ran, we did all
  // the events some window [start, end]. In general,
  // end was after some event (part way into the
  // current delta time, but what we do is simply
  // rewind and pretend that we ended at the exact
  // millisecond so that track[idx].d is measured
  // correctly.
  // However, because of that fact and because we
  // are only called periodically, we are now late:
  var late = now - last;
  // We have to run all the events with delta time
  // less than late immediately.
  for (var i = 0; i < tracks.length; i++) {
    var tr = tracks[i];
    for (; tr.idx < tr.notes.length; tr.idx++) {
      var note = tr.notes[tr.idx];
      // include e.g. something with delta time 0
      if (note.d <= late) {
	late -= note.d;
	// No delay.
	DoSoundEvent(track, tr.notes[tr.idx], 0);
      }
    }
  }

  // That may have reduced late, but usually not,
  // given that 

  for (var i = 0; i < tracks.length; i++) {
    var tr = tracks[i];
    for (; tr.idx < tr.notes.length; tr.idx++) {
      var note = tr.notes[tr.idx];
      if (note.

    }
  }
}

var overworld = [{ inst: 'SAW', notes: [{d:0,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:45},{d:30,off:45},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:45},{d:30,off:45},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:52},{d:30,off:52},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:52},{d:30,off:52},{d:30,on:24},{d:30,off:24},{d:30,on:24},{d:30,off:24},{d:30,on:24},{d:30,off:24},{d:30,on:48},{d:30,off:48},{d:30,on:24},{d:30,off:24},{d:30,on:24},{d:30,off:24},{d:30,on:24},{d:30,off:24},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:45},{d:30,off:45},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:33},{d:30,off:33},{d:30,on:45},{d:30,off:45},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:53},{d:30,off:53},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:29},{d:30,off:29},{d:30,on:53},{d:30,off:53},{d:30,on:31},{d:30,off:31},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:36},{d:30,off:36},{d:30,on:48},{d:30,off:48},{d:30,on:43},{d:30,off:43},{d:30,on:43},{d:30,off:43},{d:30,on:43},{d:30,off:43},{d:30,on:55},{d:30,off:55},{d:30,on:43},{d:30,off:43},{d:30,on:43},{d:30,off:43},{d:30,on:43},{d:30,off:43}]},
{ inst: 'SQUARE', notes: [{d:960,on:52},{d:135,off:52},{d:165,on:55},{d:90,off:55},{d:30,on:50},{d:135,off:50},{d:225,on:57},{d:90,off:57},{d:30,on:52},{d:180,off:52},{d:840,on:52},{d:135,off:52},{d:165,on:55},{d:90,off:55},{d:30,on:50},{d:135,off:50},{d:225,on:57},{d:90,off:57},{d:30,on:52},{d:180,off:52},{d:600,on:52},{d:30,off:52},{d:0,on:50},{d:30,off:50},{d:0,on:48},{d:30,off:48},{d:30,on:50},{d:30,off:50},{d:30,on:45},{d:120,off:45},{d:240,on:48},{d:60,off:48},{d:0,on:50},{d:60,off:50},{d:0,on:45},{d:120,off:45},{d:240,on:45},{d:60,off:45},{d:0,on:48},{d:60,off:48},{d:0,on:40},{d:120,off:40},{d:660,on:60},{d:0,on:52},{d:30,off:52},{d:0,off:60},{d:0,on:59},{d:0,on:50},{d:30,off:50},{d:0,off:59},{d:0,on:57},{d:0,on:48},{d:30,off:48},{d:0,off:57},{d:30,on:64},{d:0,on:50},{d:30,off:50},{d:0,off:64},{d:30,on:55},{d:0,on:45},{d:150,off:45},{d:30,off:55},{d:0,on:57},{d:60,off:57},{d:0,on:60},{d:120,off:60},{d:0,on:55},{d:60,off:55},{d:0,on:57},{d:60,off:57},{d:0,on:41},{d:0,on:64},{d:120,off:41},{d:30,off:64},{d:30,on:64},{d:60,off:64},{d:0,on:60},{d:30,off:60},{d:0,on:62},{d:60,off:62},{d:0,on:55},{d:30,off:55},{d:0,on:57},{d:60,off:57},{d:0,on:60},{d:60,off:60},{d:0,on:52},{d:120,off:52},{d:0,on:50},{d:60,off:50},{d:0,on:55},{d:180,off:55},{d:0,on:57},{d:60,off:57},{d:0,on:60},{d:0,on:52},{d:60,off:60},{d:0,on:61},{d:15,off:61},{d:0,on:62},{d:165,off:62},{d:0,off:52},{d:240,on:64},{d:60,off:64},{d:0,on:62},{d:180,off:62},{d:0,on:64},{d:60,off:64},{d:0,on:57},{d:120,on:53},{d:60,off:53},{d:0,off:57},{d:0,on:64},{d:60,off:64},{d:0,on:62},{d:180,off:62},{d:0,on:64},{d:60,off:64},{d:0,on:53},{d:0,on:57},{d:180,off:57},{d:0,off:53},{d:0,on:55},{d:60,off:55},{d:0,on:60},{d:0,on:64},{d:180,off:64},{d:0,off:60},{d:0,on:55},{d:180,off:55},{d:0,on:57},{d:60,off:57},{d:0,on:52},{d:0,on:60},{d:60,off:60},{d:0,on:61},{d:15,off:61},{d:0,on:62},{d:165,off:62},{d:0,off:52}]}];
