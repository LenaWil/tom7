
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

  return new Uint32Array(cc.getImageData(0, 0,
					 img.width, img.height).data.buffer);
}

// Chop out a part of an image and return it as a canvas. Used for example
// to chop out the letters in a font, but often useful for spriting too.
function ExtractCanvas(img, x, y, w, h) {
  var px32 = Buf32FromImage(img);
  return ExtractBuf32(px32, x, y, w, h);
}

// Extract from a Uint32Array with known width, in case you can preprocess
// with ExtractBuf32 and call this many times. Otherwise, ExtractCanvas is
// probably what you want.
function ExtractBuf32(px32, src_width, x, y, w, h) {
  var c = NewCanvas(w, h);

  var ctx = c.getContext('2d');
  var id = ctx.createImageData(w, h);
  var buf = new ArrayBuffer(id.data.length);
  var buf8 = new Uint8ClampedArray(buf);
  var buf32 = new Uint32Array(buf);

  // copy pixels from source image
  for (var yy = 0; yy < h; yy++) {
    for (var xx = 0; xx < w; xx++) {
      var p = px32[(yy + y) * src_width + xx + x];
      buf32[yy * w + xx] = p;
    }
  }

  id.data.set(buf8);
  ctx.putImageData(id, 0, 0);
  return c;
}

// Create a copy of the context/image, flipping it horizontally
// (rightward facing arrow becomes leftward).
function FlipHoriz(img) {
  var i32 = Buf32FromImage(img);
  var c = NewCanvas(img.width, img.height);
  var ctx = c.getContext('2d');
  var id = ctx.createImageData(img.width, img.height);
  var buf = new ArrayBuffer(id.data.length);
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

// TODO: FlipVert, RotateCW

// Create a copy of the context/image, rotating it counter-clockwise
// (rightward facing arrow becomes upward).
function RotateCCW(img) {
  var i32 = Buf32FromImage(img);
  var c = NewCanvas(img.width, img.height);
  var ctx = c.getContext('2d');
  var id = ctx.createImageData(img.width, img.height);
  var buf = new ArrayBuffer(id.data.length);
  var buf8 = new Uint8ClampedArray(buf);
  var buf32 = new Uint32Array(buf);

  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      var dx = y;
      var dy = img.width - x - 1;
      buf32[dy * img.width + dx] = i32[y * img.width + x];
    }
  }

  id.data.set(buf8);
  ctx.putImageData(id, 0, 0);
  return c;
}

// Img must already be loaded.
function Font(img, w, h, overlap, fontchars) {
  this.width = w;
  this.height = h;
  this.overlap = overlap;

  this.chars = {};
  var px32 = Buf32FromImage(img);
  var srcw = img.width;
  for (var i = 0; i < fontchars.length; i++) {
    var ch = fontchars.charCodeAt(i);
    this.chars[ch] = ExtractBuf32(px32, srcw, i * w, 0, w, h);
  }

  this.Draw = function(ctx, x, y, s) {
    var xx = x;
    for (var i = 0; i < s.length; i++) {
      var ch = s.charCodeAt(i);
      if (ch == 10) {
	xx = x;
	y += this.height - 1;
      } else {
	this.chars[ch] &&
	    ctx.drawImage(this.chars[ch], xx, y);
	xx += this.width - this.overlap;
      }
    }
  };
}


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

function ClearScreen() {
  ctx.clearRect(0, 0, WIDTH, HEIGHT);
}

var BigCanvas = function() {
  this.canvas =
      (function() {
	var c = document.getElementById('bigcanvas');
	if (!c) {
	  c = document.createElement('canvas');
	  document.body.appendChild(c);
	  c.id = 'bigcanvas';
	}
	c.width = WIDTH * PX;
	c.height = HEIGHT * PX;
	c.style.border = '1px solid black';
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
var bigcanvas = new BigCanvas();

// XXX wrap this inside a function blit4x or whatever.

