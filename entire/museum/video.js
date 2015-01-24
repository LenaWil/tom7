
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


// Main canvas, not the zoomed one. If there's no
// #canvas on the page, then we create one off-screen.
var canvas =
    (function() {
      var c = document.getElementById('canvas');
      if (!c) {
	c = document.createElement('canvas');
	// Off-screen.
	// document.body.appendChild(c);
	c.id = 'canvas';
      }
      c.width = WIDTH;
      c.height = HEIGHT;
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

