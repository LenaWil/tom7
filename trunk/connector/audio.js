
// Audio stuff.
// https://developer.apple.com/library/safari/documentation/AudioVideo/Conceptual/Using_HTML5_Audio_Video/PlayingandSynthesizingSounds/PlayingandSynthesizingSounds.html
var audioctx =
    (window.webkitAudioContext && new webkitAudioContext()) ||
    (window.AudioContext && new AudioContext());
var TYPE_SINE = 0, TYPE_SQUARE = 1, TYPE_SAW = 2, TYPE_TRI = 3;

function ClearSong() {
  for (var i = 0; i < tracks.length; i++) {
    for (var o in tracks[i].active) {
      var s = tracks[i].active[o];
      s.stop(0);
    }
  }
  song = null;
  tracks = [];
}

function PlaySound(s) {
  // var src = audioctx.createBufferSource();
  // var buf = resources.Get(s);
  // src.buffer = audioctx.createBuffer(buf, false);

  var src = audioctx.createBufferSource();
  src.buffer = resources.Get(s);
  // Volume?
  src.connect(audioctx.destination);
  src.start(0); // noteOn(0);
}

// assumes they are named sound1.wav ... soundn.wav.
function PlayASound(base, n) {
  var d = Math.round(Math.random() * (n - 1)) + 1;
  PlaySound(base + d + '.wav');
}

var song = null;
var tracks = [];
var MSPERTICK = 4.0;
function StartSong(s) {
  ClearSong();
  if (!s) return;
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
    var m = song.multiply || 1;
    for (var j = 0; j < notes.length; j++) {
      // Copy the object so we don't modify the
      // original song. Ugh..
      var obj = {};
      for (var o in notes[j]) {
	obj[o] = notes[j][o];
      }
      notes[j] = obj;
      notes[j].d *= MSPERTICK * m;
    }

    tracks.push({ type: type,
		  notes: notes,
		  volume: song[i].volume || 1.0,
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
    switch (tr.type) {
      case TYPE_SINE:
      src.type = "sine";
      break;
      case TYPE_TRI:
      src.type = "triangle";
      break;
      case TYPE_SAW:
      src.type = "sawtooth";
      break;
      case TYPE_SQUARE:
      src.type = "square";
      break;
    }
    // src.type = tr.type;
    // 256 + 10 * e.on;
    src.frequency.value = MidiFreq(e.on);
    var gain = audioctx.createGain();
    var m = tr.volume || 1.0;
    gain.gain.value = 0.20 * m;
    src.connect(gain);

    var lowpass = audioctx.createBiquadFilter();
    lowpass.type = "lowpass"; // 0; // LOWPASS
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
