
// Loads all the resources in the list, creating a hash from
// filename to the loaded Image etc. object.
var Resources = function(imgs, wavs, k) {
  this.obj = {};
  this.remaining = imgs.length + wavs.length;
  this.continuation = null;
  var that = this;
  this.Update = function() {
    var elt = document.getElementById('loading');
    if (elt) {
      if (this.remaining > 0) {
	elt.innerHTML = 'loading ' + this.remaining + ' more...';
      } else {
	elt.innerHTML = 'done loading';
      }
    }
    if (this.Ready() && this.continuation) {
      // alert(this.continuation);
      (0, this.continuation)();
    }
  };

  var WaveLoaded = function(sym) {
    return function(event) {
      var req = event.target;
      that.obj[sym] = req.response;
      that.remaining--;
      that.Update();
    };
  };

  this.Ready = function() {
    return this.remaining == 0;
  };

  // Call the continuation as soon as everything is loaded,
  // which might be now.
  this.WhenReady = function(k) {
    if (this.Ready()) {
      k();
    } else {
      this.continuation = k;
    }
  }

  for (var i = 0; i < imgs.length; i++) {
    var img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = function() {
      that.remaining--;
      that.Update();
    };
    img.src = imgs[i];
    this.obj[imgs[i]] = img;
  }

  for (var i = 0; i < wavs.length; i++) {
    req = new XMLHttpRequest();
    req.open('GET', wavs[i], true);
    req.responseType = 'arraybuffer';
    req.addEventListener('load', WaveLoaded(wavs[i]), false);
    req.send();
  }

  this.Get = function(n) {
    return this.obj[n];
  };
};
