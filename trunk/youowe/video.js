
// New unattached canvas.
function NewCanvas(w, h) {
  var c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  return c;
}

// Not cheap! Has to draw it to a canvas...
function Buf32FromImage(img) {
  var c = NewCanvas(img.width, img.height);
  var cc = c.getContext('2d');
  cc.drawImage(img, 0, 0);

  return new Uint32Array(cc.getImageData(0, 0, img.width, img.height).data.buffer);
}

// Loads all the images in the list, creating a hash from
// filename to the loaded Image object.
var Images = function(l, k) {
  this.obj = {};
  this.remaining = l.length;
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

  for (var i = 0; i < l.length; i++) {
    var img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = function() {
      that.remaining--;
      that.Update();
    };
    img.src = l[i];
    this.obj[l[i]] = img;
  }

  this.Get = function(n) {
    return this.obj[n];
  };
};

// Off screen 
var canvas =
    (function() {
      var c = document.createElement('canvas');
      c.width = WIDTH;
      c.height = HEIGHT;
      c.id = 'canvas';
      // document.body.appendChild(c);
      return c;
    })();

// n.b. not actually needed by BigCanvas, since it takes arg
var ctx = canvas.getContext('2d');
var id = ctx.createImageData(WIDTH, HEIGHT);
var buf = new ArrayBuffer(id.data.length);
// Make two aliases of the data, the second allowing us
// to write 32-bit pixels.
var buf8 = new Uint8ClampedArray(buf);
var buf32 = new Uint32Array(buf);

var BigCanvas = function(elt) {
  this.canvas = 
      (function() { 
	var c = document.createElement('canvas');
	c.width = WIDTH * PX;
	c.height = HEIGHT * PX;
	c.id = 'bigcanvas';
	c.style.border = '1px solid black';
	elt && elt.appendChild(c);
	return c;
      })();

  this.ctx = this.canvas.getContext('2d');
  this.id = this.ctx.createImageData(WIDTH * PX, HEIGHT * PX);

  // One buf we keep reusing, plus two aliases of it.
  this.buf = new ArrayBuffer(this.id.data.length);
  // Used just for the final draw.
  this.buf8 = new Uint8ClampedArray(this.buf);
  // We write RGBA pixels though.
  this.buf32 = new Uint32Array(this.buf);

  // Takes a 2d canvas context assumed to be WIDTH * HEIGHT
  this.Draw4x = function(sctx) {
    // d1x : Uint8ClampedArray, has an ArrayBuffer backing it (.buffer)
    var d1x = sctx.getImageData(0, 0, WIDTH, HEIGHT).data;
    // d1x32 : Uint32Array, aliasing d1x
    var d1x32 = new Uint32Array(d1x.buffer);

    var d = this.buf32;
    // Blit to PXxPX sized pixels.
    // PERF: This is slow!
    // Strength reduction. Unroll. Shorten names.
    // If browser supports native blit without resampling, use it.
    for (var y = 0; y < HEIGHT; y++) {
      for (var x = 0; x < WIDTH; x++) {
	var p = d1x32[y * WIDTH + x];
	// p |= 0xFF000000;
	// PERF
	var o = (y * PX) * (WIDTH * PX) + (x * PX);
	// PERF unroll?
	for (var u = 0; u < PX; u++) {
	  for (var v = 0; v < PX; v++) {
	    d[o + u * WIDTH * PX + v] = p;
	  }
	}
      }
    }

    this.id.data.set(this.buf8);
    this.ctx.putImageData(this.id, 0, 0);
  };
};

// Don't draw directly to this. We copy from the small
// one to the big one at the end of each frame.
var bigcanvas = new BigCanvas(document.body);

// XXX wrap this inside a function blit4x or whatever.
