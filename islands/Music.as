/* Music and in-tune death sounds.
 */
class Music extends MovieClip {

  var bouncy = {
  name : 'bouncymp3',
  death : function(ms) {
      if (ms < 22000)
        return 'bouncydeath1mp3';
      else
        return 'bouncydeath2mp3';
    }
  };

  var noisy = {
  name : 'noisymp3',
  death : function(ms) {
      if (ms < 13500)
        return 'noisydeath1mp3';
      else
        return 'noisydeath2mp3';
    }
  };

  var title = {
  name : 'titlemp3',
  death : function(ms) {
      // XXXXX
      if (ms < 13500)
        return 'noisydeath1mp3';
      else
        return 'noisydeath2mp3';
    }
  };

  var current = undefined;

  var backgroundclip : MovieClip;
  var sfxclip : MovieClip;

  public function onLoad() {
    this.createEmptyMovieClip("backgroundclip", 1);
    this.createEmptyMovieClip("sfxclip", 2);
  }

  public function setmusic(song) {
    if (current != undefined) {
      current.sound.stop();
    }
    current = { song: song,
                mc: backgroundclip,
                sound: new Sound(backgroundclip),
                volume: 0 };
    current.sound.attachSound(song.name);
    current.sound.setVolume(0);
    current.sound.start(0, 99999);
    trace('current is: ' + current);
    trace('now the song is: ' + song.name);
  }

  var nsfx : Number = 0;

  // One prime mover should call this.
  public function tick() {
    if (current != undefined && current.volume < 100 /* && nsfx == 0 */) {
      current.volume += 2;
      current.sound.setVolume(current.volume);
    }
  }

  public function position() {
    return current.sound.position;
  }

  public function playdeathsound() {
    // No death sound if no music playing.
    if (current != undefined) {
      current.volume = 5;
      current.sound.setVolume(5);
      // trace('vol: ' + current.sound.getVolume());
      nsfx++;
      var leak = new Sound(sfxclip);
      leak.attachSound(current.song.death(current.sound.position));
      leak.setVolume(100);
      // leak.setTransform({ll : 5, rr: 5, lr : 0, rl : 0});
      leak.start(0);
      // doesn't work?
      leak.onSoundComplete = function() {
        trace('deathsound ends');
        nsfx--;
      };
    } else {
      trace('no song, no deathsound!');
    }
  }

}
