// Snack Simulator 9000

var DEBUG = false;

var EXIT = false;
document.onkeydown = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  // ESC
  if (e.keyCode == 27)  {
    // document.body.innerHTML = '(SILENCED. RELOAD TO PLAY)';
    EXIT = true;
  }
}
    
function makeElement(what, cssclass, elt) {
  var e = document.createElement(what);
  if (cssclass) e.setAttribute('class', cssclass);
  if (elt) elt.appendChild(e);
  return e;
}
function IMG(cssclass, elt) { return makeElement('IMG', cssclass, elt); }
function DIV(cssclass, elt) { return makeElement('DIV', cssclass, elt); }
function CANVAS(cssclass, elt) { return makeElement('CANVAS', cssclass, elt); }
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

var frame_number = 0
var SIMULATIONS_PER_FRAME = 100;

// Possible policies:
//  - Always sort all shelves (encountered) in reverse preference
//    order (does this have to be paired with a selection method?)
//  - Only put your favorite snack at the back.

// Each shelf holds a different item.
var NUM_SHELVES = 15;
var NUM_PEOPLE = 30;
// The number of varieties of a snack is uniform in [1, MAX_VARIETY]
var MAX_VARIETY = 8;
// TODO: Argument for minimum, based on plurality, etc.
var MIN_ITEMS = 3;
var MAX_ITEMS = 50;

var OUTLIER_RATIO = 2.0;

var COST_TO_LOOK = 0.05;

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
//   favorite : variety of the favorite snack for each shelf
//   outlier : true if the favorite snack is an outlier
//   exrec : array(array(double)) - Outer length is length |snacks|;
//     inner is length MAX_ITEMS + 1. exrec[s][n] gives the value
//     of the ExRec(N) function, which is the expected value of
//     the snack we get for applying the commit-or-discard snack
//     choosing procedure on N items for snack s.
var people = [];

var time_until_restock = 0;

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
  var STDDEV = 2.0;
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
    // Discounted because we have to do work to switch.
    var ex_rec_next = ret[i - 1] - COST_TO_LOOK;
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

function PutFavoriteLast(stock, fav) {
  var dst = 0;
  var n = 0;
  for (var src = 0; src < stock.length; src++) {
    if (stock[src] == fav) {
      // skip it, count it, don't advance dst
      n++;
    } else {
      stock[dst] = stock[src];
      dst++;
    }
  }
  
  // Now put n copies of the favorite at the end.
  for (var i = 0; i < n; i++) {
    stock[dst] = fav;
    dst++;
  }
}

function CheckStockContiguous(s) {
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
  Loop();
}

// Policies.
var ALWAYS_SORT = 1;
var NO_SORT = 0;
var FAVORITE_LAST = 2;
var OUTLIER_LAST = 3;

function Reset() {
  shelves = [];
  snacks = [];
  people = [];
  time_until_restock =
      60 * // seconds
      60 * // minutes
      8 * // (work) hours
      3;   // days

  for (var i = 0; i < NUM_SHELVES; i++) {
    var varieties = RandTo(MAX_VARIETY) + 1;
    snacks.push({ varieties: varieties });
    var num_stocked = RandTo(MAX_ITEMS - MIN_ITEMS) + MIN_ITEMS;
    var stock = [];
    for (var s = 0; s < num_stocked; s++) {
      stock.push(RandTo(varieties));
    }

    // Each item is just uniformly random. Players behave as though
    // snacks are randomly distributed.
    shelves[i] = stock;
  }
  
  for (var i = 0; i < NUM_PEOPLE; i++) {
    // Generate a random preference function for each shelf;
    // each one is independent.
    var prefs = [];
    var exrecs = [];
    var favorite = [];
    var outliers = [];
    for (var p = 0; p < NUM_SHELVES; p++) {
      var pref = RandomPreferenceFn(snacks[p].varieties);
      prefs.push(pref);

      var spref = [];
      for (var z = 0; z < snacks[p].varieties; z++) {
	spref.push(z);
      }
      SortByPreference(spref, pref);

      // Favorite is at the end.
      var fav = spref[spref.length - 1];
      var outlier = false;
      if (spref.length >= 2) {
	var fav2 = spref[spref.length - 2];
	if (pref[fav] > 0 &&
	    pref[fav] >= pref[fav2] * OUTLIER_RATIO) {
	  outlier = true;
	  // console.log('on shelf ' + p + ' snack ' + fav +
	  // ' is an outlier: ' +
	  // pref.join(','));
	}
      }
      /*
      var fav = 0;
      var bestscore = pref[0];
      for (var z = 1; z < pref.length; z++) {
	if (pref[z] > bestscore) {
	  fav = z;
	  bestscore = pref[z];
	}
      }
      */
      favorite.push(fav);

      var fav2 = 0;
      var bestscore = pref[0];

      exrecs.push(MakeExRec(pref));
      outliers.push(outlier);
    }

    // console.log('favorites: ' + favorite.join(','));
    
    // XXX generate from some distribution.
    // This will be the average number of seconds between
    // snack events.
    var mean_wait = 2 * 60 * 60;

    people.push({ // policy: NO_SORT, // ALWAYS_SORT, //
      policy: (i == 0) ? OUTLIER_LAST : NO_SORT,
      // policy: NO_SORT, // FAVORITE_LAST,
      effort: 0,
      depth: 0,
      eaten: 0,
      mean_wait: mean_wait,
      next: NextWait(mean_wait),
      utils: 0,
      snack_utils: 0,
      prefs: prefs,
      favorite: favorite,
      outlier: outliers,
      exrec: exrecs });
  }
}

function OneSimulation() {
  // XXX this should really be based on time, because it's definitely
  // possible to end up in a situation where there are no snacks of
  // positive value to anyone!
  while (time_until_restock > 0) {
    Step();
    // Redraw();
  }
}

var NUM_SIMULATIONS = 100000;
function SimulationDone() {
  return frame_number * SIMULATIONS_PER_FRAME >= NUM_SIMULATIONS;
}

var snacks_at_start = [];
var snacks_at_end = [];
// Total happiness of all players.
var total_utils = [];
// Happiness from eating, player 0.
var p0_snack_utils = [];
// Total happiness of player 0, who may sort.
var p0_utils = [];
// max utils - min utils
var inequality = [];

function Loop() {
  snacks_at_end = [];
  total_utils = [];
  p0_utils = [];
  p0_snack_utils = [];
  inequality = [];

  Frame();
}

function Frame() {
  var start = performance.now();

  for (var i = 0; i < SIMULATIONS_PER_FRAME; i++) {
    Reset();
    /*
    var snacks_start = 0;
    for (var s = 0; s < shelves.length; s++)
      snacks_start += shelves[s].length;
    snacks_at_start.push(snacks_start);
    */
    
    OneSimulation();

    var snacks_left = 0;
    for (var s = 0; s < shelves.length; s++)
      snacks_left += shelves[s].length;
    snacks_at_end.push(snacks_left);

    var utils = 0;
    var min = people[0].utils, max = people[0].utils;
    for (var p = 0; p < people.length; p++) {
      utils += people[p].utils;
      min = Math.min(min, people[p].utils);
      max = Math.max(max, people[p].utils);
    }
    total_utils.push(utils);
    p0_utils.push(people[0].utils);
    p0_snack_utils.push(people[0].snack_utils);
    // console.log(min);
    inequality.push(max - min);
  }

  frame_number++;
  if (SimulationDone() || frame_number % 10 == 0) {
    Redraw();
  }

  if (SimulationDone()) {
    EXIT = true;
  }
  
  // console.log(performance.now() - start);
  if (!EXIT) {
    window.setTimeout(Frame, 0);
  }
}

function GetMinMax(values) {
  // values.sort(function(a, b) { return a - b; });
  var min = values[0];
  var max = values[0];
  for (var i = 1; i < values.length; i++) {
    var v = values[i];
    if (isNaN(v)) {
      throw ('idx ' + i + ' contains NaN');
    }

    min = Math.min(min, v);
    max = Math.max(max, v);
  }
  return {min: min, max: max};
}

var HISTOWIDTH = 800;
var HISTOBINS = 400;
var HISTOHEIGHT = 120;
function DrawHistogram(title, values, par) {
  DIV('htitle', par).innerHTML = title + ' × ' + values.length;
  var c = CANVAS('chisto', par);
  c.width = HISTOWIDTH;
  c.height = HISTOHEIGHT;
  var ctx = c.getContext('2d');

  var histobins = 800;
  var histowidth = 1;
  if (values.length < 100) {
    histobins = 100;
    histowidth = 8;
  } else if (values.length < 1000) {
    histobins = 200;
    histowidth = 4;
  } else if (values.length < 10000) {
    histobins = 400;
    histowidth = 2;
  }
  
  if (values.length == 0) {
    // no data
    ctx.fillStyle = '#ff0';
    // Maybe draw checker pattern or something?
    ctx.fillRect(20, 20, 80, 80);
    return;
  }

  var minmax = GetMinMax(values);
  var min = minmax.min;
  var max = minmax.max;
  var datawidth = max - min;
  // console.log('min ' + min + ' max ' + max + ' dw ' + datawidth);
  // var binwidth = datawidth / histobins;
  var sum = 0;
  
  var bins = [];
  for (var i = 0; i < histobins; i++)
    bins[i] = 0;
  for (var i = 0; i < values.length; i++) {
    var v = values[i];
    sum += v;
    var off = v - min;
    // XXX sloppy to avoid generating b=length for max val.
    var b = Math.floor((off / datawidth) * (histobins - 0.5));
    // console.log(values[i] + ' becomes ' + val + ' then ' + b);
    bins[b]++;
  }

  var mean = sum / values.length;
  var bmean = Math.floor(((mean - min) / datawidth) *
			 (histobins - 0.5));
  var bmedian = 0;
  
  // Get the maximum value of any bin, for scale. Note: min_bin is
  // always 0.
  var max_bin = 1;
  for (var i = 0; i < bins.length; i++) {
    // console.log(i + ' = ' + bins[i]);
    if (bins[i] > max_bin) {
      max_bin = bins[i];
      bmedian = i;
    }
  }
  // console.log('max bin: ' + max_bin);

  var median = (bmedian / (histobins - 0.5)) * datawidth + min;

  // Find the highest density interval, assuming that it is a single
  // interval. There may be a faster or more accurate way to do this
  // (intervals that are multimodal can definitely produce incorrect
  // results here, and this same issue presents a small effect at the
  // edges of the interval in typical noisy cases).

  // Interval described is [blow, bhigh).
  var blow = bmedian, bhigh = bmedian;
  var bmass = bins[bmedian];
  var target_mass = values.length * 0.95;
  while (bmass < target_mass) {
    if (blow == 0) {
      // Must extend high end.
      bmass += bins[bhigh];
      bhigh++;
    } else if (bhigh == bins.length - 1) {
      // Must extend low end.
      blow--;
      bmass += bins[blow];
    } else {
      // Take the bin with more mass.
      var l = bins[blow - 1], h = bins[bhigh];
      if (l > h) {
	blow--;
	bmass += l;
      } else {
	bhigh++;
	bmass += h;
      }
    }
  }

  var low = (blow / (histobins - 0.5)) * datawidth + min;
  var high = (bhigh / (histobins - 0.5)) * datawidth + min;
  
  ctx.fillStyle = '#000';
  
  for (var i = 0; i < bins.length; i++) {
    var height = Math.round(bins[i] / max_bin * HISTOHEIGHT);
    var omheight = HISTOHEIGHT - height;
    if (i == bmean && i == bmedian) {
      ctx.fillStyle = '#F0F'
    } else if (i == bmean) {
      ctx.fillStyle = '#F00'
    } else if (i == bmedian) {
      ctx.fillStyle = '#00F'
    } else if (i >= blow && i < bhigh) {
      ctx.fillStyle = '#000';
    } else {
      ctx.fillStyle = '#777';
    }
    ctx.fillRect(i * histowidth, omheight, histowidth, height);
  }
  
  ctx.font = "10px verdana,helvetica,sans-serif";
  ctx.fillStyle = '#700';
  ctx.fillText('Mean: ' + mean.toFixed(2), 4, 10);
  ctx.fillStyle = '#007';
  ctx.fillText('Median: ' + median.toFixed(2), 4, 24);
  ctx.fillStyle = '#000';
  ctx.fillText('ival: [' +
	       low.toFixed(2) + ', ' +
	       high.toFixed(2) + ']',
	       4, 38);

  if (SimulationDone()) {
    console.log(title + ' × ' + values.length + ' = ' +
		'Mean: ' + mean.toFixed(2) + ' [' +
		low.toFixed(2) + ', ' + high.toFixed(2) + '] ' +
		'Median: ' + median.toFixed(2));
  }
}

var COLORS = [
  {l: '#000077', h: '#9999ff'},
  {l: '#007700', h: '#99ff99'},
  {l: '#770000', h: '#ff9999'},
  {l: '#777700', h: '#ffff99'},
  {l: '#770077', h: '#ff99ff'},
  {l: '#007777', h: '#99ffff'},
  {l: '#000000', h: '#999999'},
  {l: '#777777', h: '#eeeeee'},
];

(function(){ if (COLORS.length < MAX_VARIETY) throw 'not enough colors'; })();

function Redraw() {
  document.body.innerHTML = '';
  var sim = DIV('sim', document.body);

  var d = DIV('shelves', sim);
  for (var i = 0; i < snacks.length; i++) {
    var sh = DIV('shelf', d);
    for (var v = 0; v < shelves[i].length; v++) {
      var sn = DIV('snack', sh);
      sn.style.border = '1px solid ' + COLORS[shelves[i][v]].l;
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

  // Stats


  /*
  DrawHistogram('snacks at start', snacks_at_start, document.body);
  BR('', document.body);
  */

  if (SimulationDone()) {
    var policies = [];
    var last_policy = -1;
    var same_count = 0;
    var s = '';
    function Flush() {
      if (same_count == 0) return;
      if (s != '') s += ', ';
      if (same_count > 1) {
	s += last_policy + '×' + same_count;
      } else {
	s += last_policy;
      }
      same_count = 0;
    }
    for (var i = 0; i < people.length; i++) {
      var p = people[i].policy;
      if (p == last_policy) {
	same_count++;
      } else {
	Flush();
	last_policy = p;
	same_count = 1;
      }
    }
    Flush();
    console.log('Policies: ', s);
  }
  
  DrawHistogram('snacks at end', snacks_at_end, document.body);
  BR('', document.body);

  DrawHistogram('total utils', total_utils, document.body);
  BR('', document.body);
  
  DrawHistogram('p0 utils', p0_utils, document.body);
  BR('', document.body);

  DrawHistogram('p0 snack utils', p0_snack_utils, document.body);
  BR('', document.body);

  DrawHistogram('inequality', inequality, document.body);
  BR('', document.body);

  TEXT('sim/s: ' + ((frame_number * SIMULATIONS_PER_FRAME) /
		    (performance.now() / 1000.0)).toFixed(2),
       document.body);
}

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
// After selecting a snack from a shelf, the player can abandon it in
// order to search the next shelf, unless that shelf has already been
// searched.

function ChooseSnack(shelf_idx, player_idx) {
  var player = people[player_idx];
  var shelf = shelves[shelf_idx];
  var prefs = player.prefs[shelf_idx];
  var exrec = player.exrec[shelf_idx];
  if (DEBUG) console.log('player ' + player_idx + ' tries shelf ' + shelf_idx +
	      ', which has ' + shelf.length + ' snacks of ' +
	      prefs.length + ' possible varieties');
  if (shelf.length != 0) {
    var cur = 0;
    var cur_value = prefs[shelf[cur]];
    for (;;) {
      var num_left = shelf.length - cur;
      if (num_left > 0 &&
	  cur_value < exrec[num_left - 1] - COST_TO_LOOK) {
	// swap for next one
	if (DEBUG) console.log('Player ' + player_idx + ' skips depth ' + cur +
		    ' because E=' + exrec[num_left].toFixed(2) + 
		    ' > cur=' + cur_value.toFixed(2));
	cur++;
	cur_value = prefs[shelf[cur]];
	player.utils -= COST_TO_LOOK;
      } else {
	// not willing or able to swap.
	if (cur_value > 0 && cur < shelf.length) {
	  if (DEBUG) console.log('Player ' + player_idx + ' goes ' + cur +
		      ' snacks deep, taking one worth ' + cur_value.toFixed(2) +
		      ' utils.');
	  return {idx: cur, value: cur_value};
	} else {
	  if (DEBUG) console.log('Player ' + player_idx + ' gets no snack.');
	  return null;
	}
      }
    }
  }
};

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
  // Also advance restocking time.
  time_until_restock -= best_next;

  var player = people[best_i];
  var start_shelf_idx = RandTo(shelves.length);

  for (var shelf_offset = 0; shelf_offset < shelves.length; shelf_offset++) {
    var shelf_idx = (start_shelf_idx + shelf_offset) % shelves.length;
    var res = ChooseSnack(shelf_idx, best_i);
    if (res) {
      var next_shelf_idx = (shelf_idx + 1) % shelves.length;
      var next_shelf = shelves[next_shelf_idx];
      // Expected value of switching to the next shelf. We say that
      // looking to the next shelf is free.
      var e_next = player.exrec[next_shelf_idx][next_shelf.length];
      // We don't allow going back to the first shelf. We also keep
      // the current snack if it's better than what we expect to
      // find on the next shelf.
      if (shelf_offset == shelves.length - 1 ||
	  res.value >= e_next) {
	if (DEBUG) console.log('player ' + best_i + ' eats snack idx ' +
		    res.idx + ' from shelf ' + shelf_idx + 
		    ', with value ' + res.value + ' >= E(next)= ' +
		    e_next);
	var shelf = shelves[shelf_idx];
	shelf.splice(res.idx, 1);
	player.eaten++;
	player.utils += res.value;
	player.snack_utils += res.value;
	
	// Reshuffle shelf if in policy.
	if (player.policy == ALWAYS_SORT) {
	  SortByPreference(shelf, player.prefs[shelf_idx]);
	} else if (player.policy == FAVORITE_LAST) {
	  if (DEBUG) console.log('player ' + best_i + ' puts his favorite, ' +
		      player.favorite[shelf_idx] + ' last in ' +
		      shelf.join(','));
	  PutFavoriteLast(shelf, player.favorite[shelf_idx]);
	  if (DEBUG) console.log('and now it is: ' + shelf.join(','));
	} else if (player.policy == OUTLIER_LAST) {
	  if (player.outlier[shelf_idx]) {
	    if (DEBUG) console.log('player ' + best_i + ' puts his favorite, ' +
				   player.favorite[shelf_idx] + ' last in ' +
				   shelf.join(','));
	    PutFavoriteLast(shelf, player.favorite[shelf_idx]);
	    if (DEBUG) console.log('and now it is: ' + shelf.join(','));
	  }
	}

	break;
      } else {
	if (DEBUG) console.log('player ' + best_i + ' goes to next shelf #' +
		    next_shelf_idx + ' because E(next) = ' +
		    e_next + ' > chosen value = ' + res.value);
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
