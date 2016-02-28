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

// Random variables from Gamma(s) distribution, for any shape
// parameter k (scale, aka theta, can be applied by just multiplying
// the resulting variate by the scale).
//
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
//   mean_wait : double - mean time until craving for this person.
//     Some people crave more often than others.
//   next : double - time until next craving. Can be thought of
//     as seconds but should be scale invariant?
//   prefs : array(array(double)) - preference function for varieties. 
//     Outer array is length |snacks|; inner is length
//     |varieties of that snack|; elements are utility.
//   exrec : array(array(double)) - Outer length is length |snacks|;
//     inner is length MAX_ITEMS + 1. exrec[s][n] gives the value
//     of the ExRec(N) function, which is the expected value of
//     the snack we get for applying the commit-or-discard snack
//     choosing procedure on N items for snack s.
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

// OK, so now we have the situation where the player has some
// item in hand, with the given value. What we want to know is,
// do I have a better expected value if I discard it and search
// the rest? This should only depend on the number of remaining
// items, N, and the player's preference function. Call this
// expected value ExRec(N).

// ExRec(0) is 0, because we get no item.
//
// ExRec(1) is the expected value of a single item, which (because
// we assume for simplicity that each item is stocked in equal
// numbers) is just the mean output value of our preference
// function. (In fact, not really: we can always discard the snack,
// so it's really the expectation over max(pref[k], 0) for each k.
// This turns out to be just a special case of the following:)
//
// In the general case for ExRec(N), we will receive one item,
// and then based on what it is, maybe reroll. So we have a
// recurrence
//
// ExRec(N) = 
//   P(get item 0) * max(pref(0), ExRec(N - 1))  +
//   P(get item 1) * max(pref(1), ExRec(N - 1))  +
//   ...
//   P(get item k) * max(pref(k), ExRec(N - 1)).
//
// Since we already know the values of the preferences and
// have the values of ExRec(N - 1) inductively, we can simply
// compute the values up front for each snack type.
function MakeExRec(pref) {
  // ExRec[0] is 0, because we get no snack.
  var ret = [0];
  for (var i = 1; i <= MAX_ITEMS; i++) {
    var ex_rec_next = ret[i - 1];
    var sum = 0.0;
    for (var s = 0; s < pref.length; s++) {
      sum += Math.max(ex_rec_next, pref[s]);
    }
    // Expectation is the mean of these because we assume
    // each is equally likely.
    sum /= pref.length;
    ret[i] = sum;
  }
  return ret;
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

function CheckStock(s) {
  if (s.length === 0) return;
  var seen = {};
  var prev = s[0];
  for (var i = 0; i < s.length; i++) {
    if (seen[s[i]]) {
      throw('non-contiguous ' + s[i] + ' in: ' +
	    s.join(','));
    }
    if (s[i] != prev) {
      seen[prev] = true;
    }
  }
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
    //
    // XXX, actually, I think maybe these should just be random,
    // since players behave as though they are, so we have some kind
    // of mismatched realism here
    var stock = [];
    for (var s = 0; s < num_stocked; s++) {
      stock.push(RandTo(varieties));
    }

    // Bug: Sometimes we get non-contiguous snacks this way?
    var rpref = RandomPreferenceFn(varieties);
    SortByPreference(stock, rpref);
    shelves[i] = stock;

    // Sanity check
    try { 
      CheckStock(stock);
    } catch (e) {
      console.log('ns: ' + num_stocked + ' len: ' + stock.length + 
		  ' pref: ' + rpref.length);
      console.log(rpref);
      console.log(e);
      throw e;
    }
  }
  
  for (var i = 0; i < NUM_PEOPLE; i++) {
    // Generate a random preference function for each shelf;
    // each one is independent.
    var prefs = [];
    var exrecs = [];
    for (var p = 0; p < NUM_SHELVES; p++) {
      var pref = RandomPreferenceFn(snacks[p].varieties);
      prefs.push(pref);
      exrecs.push(MakeExRec(pref));
    }

    // XXX generate from some distribution.
    // This will be the average number of seconds between
    // snack events.
    var mean_wait = 45 * 60;

    people.push({ policy: 0,
		  effort: 0,
		  depth: 0,
		  eaten: 0,
		  mean_wait: mean_wait,
		  next: NextWait(mean_wait),
		  utils: 0,
		  prefs: prefs,
		  exrec: exrecs });
  }

  Redraw();

  // Loop();
}

function Loop() {
  Step();
  Redraw();
  window.setTimeout(Loop, 10);
}

var COLORS = [
  {l: '#770000', h: '#ff9999'},
  {l: '#777700', h: '#ffff99'},
  {l: '#770077', h: '#ff99ff'},
  {l: '#007700', h: '#99ff99'},
  {l: '#007777', h: '#99ffff'},
  {l: '#000077', h: '#9999ff'},
  {l: '#000000', h: '#999999'},
  {l: '#777777', h: '#eeeeee'},
];

(function(){ if (COLORS.length < MAX_VARIETY) throw 'not enough colors'; })();

function Redraw() {
  document.body.innerHTML = '';
  var d = DIV('shelves', document.body);
  for (var i = 0; i < snacks.length; i++) {
    var sh = DIV('shelf', d);
    for (var v = 0; v < shelves[i].length; v++) {
      var sn = DIV('snack', sh);
      sn.style.border = '2px solid ' + COLORS[shelves[i][v]].l;
      sn.style.background = COLORS[shelves[i][v]].h;
    }
  }

  // People
  for (var i = 0; i < people.length; i++) {
    var p = people[i];
    var pp = DIV('person', d);
    pp.innerHTML = '' + p.eaten + ' for ' + p.utils.toFixed(1) +
      '<br>next: ' + p.next.toFixed(0) + 's';
  }
}

function Step() {
  // First, find the person with the first 'next' time.
  // If we kept the people in a heap, this would be much more
  // efficient. Linear search for now.
  var best_i = -1, best_next = null;
  for (var i = 0; i < people.length; i++) {
    if (best_next === null || people[i].next < best_next) {
      best_next = people[i].next;
      best_i = i;
    }
  }

  // Fast-forward to this moment, by subtracting from all
  // people's next-times (including the winner).
  for (var i = 0; i < people.length; i++) {
    people[i].next -= best_next;
  }
  
  var player = people[best_i];

  // Eating works like this: The player randomly selects a starting
  // shelf, then iteratively inspects items in that queue until
  // eating one, or abandoning the shelf.
  //
  // We assume that a player is not "tricked" by hidden items --
  // the player estimates the distribution of future items as
  // though they are randomly distributed.
  //
  // Note that if the player has not already found her favorite
  // among the varieties, there is always some positive expected
  // value to searching the rest, since she gets to apply the
  // max() operator. Most people are "satisficers" in this scenario,
  // and this is meaningful to the current problem, since it concerns
  // moving snacks to the back in order to minimize the chance that
  // they are selected. We could do this through a few methods, for
  // example, explicitly modeling the cost of searching the snacks.
  // Maybe a good way is to pick a simple stochastic method that
  // has critical properties:
  //  - The player shouldn't always search through the entire list.
  //  - The more the player's preference function varies, the more
  //    willing she should be to explore deeper.
  //  - If the player already has her favorite snack, she shouldn't
  //    search any further.
  //  - ...
  //
  // So, one idea is to constrain the player to commit to the snack in
  // hand, or "discard" it and continue searching. This is not
  // realistic (of course the player can go back, and indeed we don't
  // even discard snacks in the model), but it is parameterless, and
  // appears to have desired properties. It may not have property 2
  // above -- if the player likes pretty much every snack, then there
  // is little cost to searching the entire shelf, even if only for
  // a tiny fraction of a util. This needs some more thought--it may
  // be okay, or we may simply need to add a small cost to searching,
  // which is easily integrated into the formula above.
  //
  // If the player abandons a shelf, she proceeds to the next one,
  // up to N times? (XXX todo)

  var shelf_idx = RandTo(shelves.length);
  var shelf = shelves[shelf_idx];
  var prefs = player.prefs[shelf_idx];
  var exrec = player.exrec[shelf_idx];
  console.log('player ' + best_i + ' starts on shelf ' + shelf_idx +
	      ', which has ' + shelf.length + ' snacks of ' +
	      prefs.length + ' varieties');
  if (shelf.length != 0) {
    var cur = 0;
    var cur_value = prefs[shelf[cur]];
    for (;;) {
      var num_left = shelf.length - cur;
      if (num_left > 0 &&
	  cur_value < exrec[num_left]) {
	// swap for next one
	console.log('Player ' + best_i + ' skips depth ' + cur +
		    ' because E=' + exrec[num_left].toFixed(2) + 
		    ' > cur=' + cur_value.toFixed(2));
	cur++;
	cur_value = prefs[shelf[cur]];
      } else {
	// not willing or able to swap.
	if (cur_value > 0 && cur < shelf.length) {
	  // Note: Would make sense to allow moving to the
	  // next shelf here based on an estimate of its
	  // value?
	  shelf.splice(cur, 1);
	  console.log('Player ' + best_i + ' goes ' + cur +
		      ' snacks deep, and eats for ' + cur_value.toFixed(2) +
		      ' utils.');
	  player.eaten++;
	  player.utils += cur_value;
	  break;
	} else {
	  console.log('Player ' + best_i + ' gets no snack.');
	  // TODO: Some chance of going to next shelf--
	  // if it's just a fixed probability it's really
	  // no different than just waiting for the next
	  // hunger event, though?
	  break;
	}
      }
    }
  }

  // Put the eater back in the queue.
  player.next = NextWait(player.mean_wait);
}

function NextWait(mean) {
  // I think the intuition here is that we want the distance
  // between two hunger events, so shape = 2.0. But should
  // really justify this.
  return RandomGamma(2.0) * mean;
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

// XXX generate names for people
function NamePerson() {

}
