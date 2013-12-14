
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
