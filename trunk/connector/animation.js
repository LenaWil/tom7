// XXX needs docs

function FlipFramesHoriz(fr) {
  var f = fr.frames;
  var ff = [];
  for (var i = 0; i < f.length; i++) {
    ff.push({f: FlipHoriz(f[i].f), d: f[i].d});
  }
  return new Frames(ff);
}

function RotateFramesCCW(fr) {
  var f = fr.frames;
  var ff = [];
  for (var i = 0; i < f.length; i++) {
    ff.push({f: RotateCCW(f[i].f), d: f[i].d});
  }
  return new Frames(ff);
}

// The 'f' field must be something that you can ctx.drawImage on,
// so an Image or Canvas.
function Frames(arg) {
  if (arg instanceof Image ||
      arg instanceof HTMLCanvasElement) {
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
  // console.log(this.frames[0].f);
  this.height = this.frames[0].f.height;
  this.width = this.frames[0].f.width;
}

function Static(f) { return new Frames(resources.Get(f)); }

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

// XXX Good reference, but specific to "You Owe"
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

function DrawFrame(frame, x, y, opt_fc) {
  ctx.drawImage(frame.GetFrame(arguments.length > 3 ? opt_fc : frames),
		Math.round(x), Math.round(y));
}
