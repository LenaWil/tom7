
/* Some utilities that can be included wherever. 
   There's no doubt a better way to get these functions
   to be available (static?)
 */

private function loadBitmap3x(name) {
    var bm = BitmapData.loadBitmap(name);
    if (bm == null) {
	trace('bm ' + name + ' was null');
    }
    var bm3x : BitmapData =
      new BitmapData(bm.width * 3, bm.height * 3, true, 0x000000);
    var grow = new Matrix();
    grow.scale(3, 3);
    bm3x.draw(bm, grow);
    return bm3x;
}

private function convertToCanadian(bm) {
    var bmcad = new BitmapData(bm.width, bm.height, true, 0x000000);

    // PERF?
    var MINTR = 0x85;
    var MINTG = 0xe6;
    var MINTB = 0x9c;
    for (var y = 0; y < bm.height; y++) {
	for (var x = 0; x < bm.width; x++) {
	    var c = bm.getPixel32(x, y);
	    var r = (c >> 16) & 255;
	    var g = (c >> 8) & 255;
	    var b = c & 255;

	    if (Math.abs(r - MINTR) < 3 &&
		Math.abs(g - MINTG) < 3 &&
		Math.abs(b - MINTB) < 3) {
		c = 0xffffb525;
	    }
	    bmcad.setPixel32(x, y, c);
	}
    }
    return bmcad;
}

private function convertToReferee(bm) {
    var bmcad = new BitmapData(bm.width, bm.height, true, 0x000000);

    // PERF?
    var MINTR = 0x85;
    var MINTG = 0xe6;
    var MINTB = 0x9c;
    for (var y = 0; y < bm.height; y++) {
	for (var x = 0; x < bm.width; x++) {
	    var c = bm.getPixel32(x, y);
	    var r = (c >> 16) & 255;
	    var g = (c >> 8) & 255;
	    var b = c & 255;

	    if (Math.abs(r - MINTR) < 3 &&
		Math.abs(g - MINTG) < 3 &&
		Math.abs(b - MINTB) < 3) {

		if (y <= 33 || int(x / 3) % 2) {
		    c = 0xFF000000;
		} else {
		    c = 0xFFFFFFFF;
		}

	    }
	    bmcad.setPixel32(x, y, c);
	}
    }
    return bmcad;
}

private function flipHoriz(bm) {
    var fliphoriz = new Matrix();
    fliphoriz.scale(-1,1);
    fliphoriz.translate(bm.width, 0);
    var fbm = new BitmapData(bm.width, bm.height, true, 0);
    fbm.draw(bm, fliphoriz);
    return fbm;
}

public function setDepthOf(m : MovieClip, n : Number) {
    var other : MovieClip = _root.getInstanceAtDepth(n);
    if (other == m) {
	// trace('' + m + ' already there @' + n);
	return;
    }
    if (other != undefined) {
	// PERF: Instead of being recursive, this could
	// immediately swap with that element, then
	// continue in a loop...
	// trace('' + m + '/' + other + ' conflict @' + n);
	setDepthOf(other, n - 1);
    }
    m.swapDepths(n);
}

private function createMovieAtDepth(name, depth) {
    var i = _root.getNextHighestDepth();
    var mc = _root.createEmptyMovieClip(name, i);
    // setDepthOf(mc, depth);
    mc.swapDepths(depth);
    return mc;
}
