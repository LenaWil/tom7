
/* Some utilities that can be included wherever. 
   There's no doubt a better way to get these functions
   to be available (static?)
 */

private function loadBitmap3x(name) {
    var bm = BitmapData.loadBitmap(name);
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
    var MINT = 0xFF85e59c;
    for (var y = 0; y < bm.height; y++) {
	for (var x = 0; x < bm.height; x++) {
	    var c = bm.getPixel32(x, y);
	    if (c == MINT) {
		c = 0xffffb525;
	    }
	    bmcad.setPixel32(x, y, c);
	}
    }
    return bmcad;
}