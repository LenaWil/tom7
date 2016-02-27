// Snack Simulator 9000

function makeElement(what, cssclass, elt) {
  var e = document.createElement(what);
  if (cssclass) e.setAttribute('class', cssclass);
  if (elt) elt.appendChild(e);
  return e;
}
function IMG(cssclass, elt) { return makeElement('IMG', cssclass, elt); }
function DIV(cssclass, elt) { return makeElement('DIV', cssclass, elt); }
function DIV(cssclass, elt) { return makeElement('DIV', cssclass, elt); }
function SPAN(cssclass, elt) { return makeElement('SPAN', cssclass, elt); }
function BR(cssclass, elt) { return makeElement('BR', cssclass, elt); }
function TEXT(contents, elt) {
  var e = document.createTextNode(contents);
  if (elt) elt.appendChild(e);
  return e;
}

// Generate a uniformly distributed random integer in [0, n).
var RandTo = function(n) {
  // XXX to get uniform random numbers efficiently, generate
  // random bit patterns, mod by the next power of two, then
  // reject.
  return Math.trunc(Math.random() * n);
}

// Generates two Gaussians at once, keeping state. Pretty much
// a direct port of Marsaglia's pseudocode.
var RandomGaussian = function() {
  var have = false;
  var next = 0.0;
  return function() {
    if (have) {
      have = false;
      return next;
    } else {
      var v1 = 0.0, v2 = 0.0, sqnorm = 0.0;
      // Generate a non-degenerate random point in the unit circle by
      // rejection sampling.
      do {
	v1 = 2.0 * Math.random() - 1.0;
	v2 = 2.0 * Math.random() - 1.0;
	sqnorm = v1 * v1 + v2 * v2;
      } while (sqnorm >= 1.0 || sqnorm == 0.0);
      var multiplier = Math.sqrt(-2.0 * Math.log(sqnorm) / sqnorm);
      next = v2 * multiplier;
      have = true;
      return v1 * multiplier;
    }
  };
}();

function RandomExponential() {
  // n.b. JS Math.random() cannot return 1.0 exactly.
  return -Math.log(1.0 - Math.random());
}

// Random variables from Gamma(s) distribution, for any
// shape parameter (scale can be applied by just multiplying
// the resulting variate by the scale).
// Adapted from numpy, based on Marsaglia & Tsang's method.
// Please see NUMPY.LICENSE.
var RandomGamma = function(shape) {
  if (shape == 1.0) {
    return RandomExponential();
  } else if (shape < 1.0) {
    var one_over_shape = 1.0 / shape;
    for (;;) {
      var u = Math.random();
      var v = RandomExponential();
      if (u < 1.0 - shape) {
	var x = Math.pow(u, one_over_shape);
	if (x <= v) {
	  return x;
	}
      } else {
	var y = -Math.log((1.0 - u) / shape);
	var x = Math.pow(1.0 - shape + shape * y, one_over_shape);
	if (x <= v + y) {
	  return x;
	}
      }
    }
  } else {
    var b = shape - (1.0 / 3.0);
    var c = 1.0 / Math.sqrt(9.0 * b);
    for (;;) {
      var x, v;
      do {
	x = RandomGaussian();
	v = 1.0 + c * x;
      } while (v <= 0.0);

      var v_cubed = v * v * v;
      var x_squared = x * x;
      var u = Math.random();
      if (u < 1.0 - 0.0331 * x_squared * x_squared ||
	  Math.log(u) < 0.5 * x_squared + 
	  b * (1.0 - v_cubed - Math.log(v_cubed))) {
	return b * v_cubed;
      }
    }
  }
}

// Possible policies:
//  - Always sort all shelves (encountered) in reverse preference
//    order (does this have to be paired with a selection method?)
//  - Only put your favorite snack at the back.

// Each shelf holds a different item.
var NUM_SHELVES = 30;
var NUM_PEOPLE = 50;
// The number of varieties of a snack is uniform in [1, MAX_VARIETY]
var MAX_VARIETY = 8;
// TODO: Argument for minimum, based on plurality, etc.
var MIN_ITEMS = 3;
var MAX_ITEMS = 100;

// The current contents of the shelves: An ordered list of
// variety ints.
var shelves = [];
// Parallel array containing snack info.
//   varieties : int   - number of distinct varieties for this snack
//   .. some kind of distance from the previous snack = difficulty?
var snacks = [];
// Array of all people.
//   policy : int
//        0 = don't reorder
//        1 = always sort
//   effort : int  - number of snack swaps (or some other metric)
//   depth : int  - number of snacks skipped
//   eaten : int  - number of snacks consumed
//   utils : double - total number of snack delection points
//   next : double - time until next craving. Can be thought of
//     as seconds but should be scale invariant?
//   prefs : array(array(double)) - preference function for varieties. 
//     Outer array is length |snacks|; inner is length
//     |varieties of that snack|; elements are utility.
var people = [];

// Generate a random preference function for n items. This is
// represented by a length-n array of utilities.
function RandomPreferenceFn(n) {
  // Maybe should depend on snack type, like assuming that
  // people have similar values for "premium" snacks, based on
  // the idea that some snacks just cost more.
  //
  // Also, based on personal experience, the variance within a snack
  // type is usually less than across snack types (and this is
  // intuitive since the variance of the snacks themselves is
  // obviously less between varities than between snacks). Some people
  // just don't like tea or candy but like yogurt.
  var MEAN = 0.75;
  // Should certainly include negative values to indicate an
  // aversion to a snack.
  var STDDEV = 1.0;
  var pref = [];
  for (var i = 0; i < n; i++) {
    pref.push(RandomGaussian() * STDDEV + MEAN);
  }
  return pref;
}

// Sort all the items by ASCENDING preference, which puts the favored
// items (positive score) at the end. pref is an array of doubles
// (snack preference), with length the same as the number of
// varieties.
function SortByPreference(stock, pref) {
  stock.sort(function (a, b) {
    return pref[a] - pref[b];
  });
}

// Entry point.
function Init() {
  for (var i = 0; i < NUM_SHELVES; i++) {
    var varieties = RandTo(MAX_VARIETY) + 1;
    snacks.push({ varieties: varieties });
    var num_stocked = RandTo(MAX_ITEMS - MIN_ITEMS) + MIN_ITEMS;
    // We stock each item uniformly from the varieties, but in
    // contiguous order. One easy way to do that is to generate a
    // random preference function and sort with it.
    var stock = [];
    for (var s = 0; s < num_stocked; s++) {
      stock.push(RandTo(varieties));
    }

    var rpref = RandomPreferenceFn(num_stocked);
    SortByPreference(stock, rpref);
  }
  
  for (var i = 0; i < NUM_PEOPLE; i++) {
    // Generate a random preference function for each shelf;
    // each one is independent.
    var prefs = [];
    for (var p = 0; p < NUM_SHELVES; p++) {
      var pref = [];
      prefs.push(RandomPreferenceFn(snacks[p].varieties));
    }

    people.push({ policy: 0,
		  effort: 0,
		  depth: 0,
		  eaten: 0,
		  utils: 0,
		  prefs: prefs });
  }
}

function RandFrom(l) {
  return l[RandTo(l.length)];
}

function NameBrand() {
  // One syllable
  var a = ['Ch', 'Pr', 'S', 'Sp', 'Br', 'Ex', 'Pl', 'P',
	   'T', 'Th', 'Tr', 'Sl', 'D', 'Dr', 'G', 'Gr',
	   'Gl', 'K']
  var b = ['a', 'e', 'o', 'u', 'o', 'oo', 'ee', 'i', 'a', 'ea', 'ie']
  var c = ['ke', 'rk', 'ck', 'ch', 'ng', 'g', 'd', 'sh', 'sk',
	   'rg', 'rp', 'p', 'pe', 't', 'tch', 'te', 'ty', 'q',
	   'b', 'be', 'rb', 'x']
  return RandFrom(a) + RandFrom(b) + RandFrom(c);
}

function OneFlavor() {
  var flavors = ['Cherry', 'Vanilla', 'Grape', 'Coffee', 'Strawberry',
		 'Orange', 'Mango'];
  var style_prefix = ['Diet', 'Regular', 'Dr.', 'Mr.', 'Mrs.', 'Caffeine-Free']
  var style_suffix = ['Black', 'X', 'X-Tra', 'Classic', 'Ultra', 'Lite']

  switch (RandTo(5)) {
  case 0: return {pre: RandFromList(style_prefix), suf: ''};
  case 1: return {pre: '', suf: RandFromList(style_suffix)};
  case 2: return {pre: RandFromList(flavors), suf: ''};
  case 3: return {pre: RandFromList(style_prefix), 
		  suf: RandFromList(style_suffix)};
  case 4: return {pre: RandFromList(style_flavors), 
		  suf: RandFromList(style_suffix)};
  }
}

// Snack naming is very important.
//
// Argument is number of varieties.
function NameSnack(n) {
  var brand = NameBrand();
  var ret = {brand: brand, flavors: flavors}
  var used = {};
  while (ret.flavors.length < n) {
    var flav = OneFlavor();
    var fs = flav.pre + '.' + flav.suf;
    // Names must be unique.
    if (used[fs])
      continue;
    ret.flavors.push_back(flav);
    used[fs] = true;
  }

  return ret;
}
