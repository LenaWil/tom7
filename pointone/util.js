
/* Some utilities that can be included wherever. 
   There's no doubt a better way to get these functions
   to be available (static?)
 */

private function loadBitmap2x(name) {
  var bm = BitmapData.loadBitmap(name);
  if (bm == null) {
    trace('bm ' + name + ' was null');
  }
  var bmx : BitmapData =
      new BitmapData(bm.width * 2, bm.height * 2, true, 0x000000);
  var grow = new Matrix();
  grow.scale(2, 2);
  bmx.draw(bm, grow);
  return bmx;
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

private function toDecimal(number, factor) {
  return Math.round(number * factor) / factor;
}

public function createGlobalMC(name, bitmap, depth) {
  var mc = createMovieAtDepth(name, depth);
  mc.attachBitmap(bitmap, 'b', 1);
  return mc;
}

public function clearBitmap(bm) {
  bm.fillRect(new Rectangle(0, 0, bm.width, bm.height), 0);
}
