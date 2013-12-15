
// Audio stuff.
// https://developer.apple.com/library/safari/documentation/AudioVideo/Conceptual/Using_HTML5_Audio_Video/PlayingandSynthesizingSounds/PlayingandSynthesizingSounds.html
var audioctx = 
    (window.webkitAudioContext && new webkitAudioContext()) ||
    (window.AudioContext && new AudioContext());
var TYPE_SINE = 0, TYPE_SQUARE = 1, TYPE_SAW = 2, TYPE_TRI = 3;

function ClearSong() {
  // XXXX!
  for (var i = 0; i < tracks.length; i++) {
    for (var o in tracks[i].active) {
      var s = tracks[i].active[o];
      s.stop(0);
    }
  }
  song = null;
  tracks = [];
}

var song = null;
var tracks = [];
var MSPERTICK = 4.0;
function StartSong(s) {
  ClearSong();
  song = s;
  tracks = [];
  var now = audioctx.currentTime * 1000.0; // (new Date()).getTime();
  for (var i = 0; i < song.length; i++) {
    var type = TYPE_SINE;
    switch (song[i].inst) {
      case 'SAW': type = TYPE_SAW; break;
      case 'SQUARE': type = TYPE_SQUARE; break;
      case 'TRIANGLE': type = TYPE_TRI; break;
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
		  basetime: now });
  }
  
  UpdateSong(s);
}

function MidiFreq(m) {
  return 440.0 * Math.pow(2, (m - 69) / 12.0);
}

function DoSoundEvent(tr, e, d) {
  // console.log('dosoundevent ' + e.on + ' ' + e.off + ' @' + d);
  if ('on' in e) {
    if (tr.active[e.on]) {
      // Don't want to leak...
      console.log ('double-on.');
      return;
    }

    var src = audioctx.createOscillator();
    src.type = tr.type;
    // 256 + 10 * e.on;
    src.frequency.value = MidiFreq(e.on);
    var gain = audioctx.createGain();
    gain.gain.value = 0.275;
    src.connect(gain);

    var lowpass = audioctx.createBiquadFilter();
    lowpass.type = 0; // LOWPASS
    lowpass.frequency.value = 4096; // 8192;
    gain.connect(lowpass);
    lowpass.connect(audioctx.destination);

    src.start(audioctx.currentTime + d / 1000.0);
    tr.active[e.on] = src;

  } else if ('off' in e) {
    var src = tr.active[e.off];
    delete tr.active[e.off];
    if (src) {
      // console.log('turn off at ' + (audioctx.currentTime + d));
      src.stop(audioctx.currentTime + d / 1000.0);
    }

  } else if ('w' in e) {
    // Nothing; just for alignment at the end.

  } else {
    console.log ('bad sound event');
  }
}

function UpdateTrack(now, playuntil, tr) {
  // idx points to an event with some delta time.
  // we've already handled all the events up until
  // that point. We save the basetime, which is the
  // wall time against which the next event's delta
  // is measured.

  for (;;) {
    var note = tr.notes[tr.idx];
    var playtime = tr.basetime + note.d;
    if (playtime <= playuntil) {
      // Note is in the window; play it.
      DoSoundEvent(tr, tr.notes[tr.idx], playtime - now);
    } else {
      // If this note is not in the window then no note will be.
      // Basetime stays the same; we're still looking at the
      // same index.
      return true;
    }

    // Move on to the next note.
    tr.idx++;
    if (tr.idx == tr.notes.length) tr.idx = 0;
    tr.basetime = playtime;
  }

  // unreachable
}

var MSPERSCHEDULE = 100;
function UpdateSong() {
  var now = audioctx.currentTime * 1000.0; // (new Date()).getTime();
  var playuntil = now + MSPERSCHEDULE;

  var played = false;
  // We have to run all the events with delta time
  // less than late immediately.
  for (var i = 0; i < tracks.length; i++) {
    // console.log(tracks[i]);
    played = UpdateTrack(now, playuntil, tracks[i]) || played;
  }
}
