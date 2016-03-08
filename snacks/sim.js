// Snack Simulator 9000

var DEBUG = false;

var EXIT = false;
document.onkeydown = function(e) {
  e = e || window.event;
  if (e.ctrlKey) return true;

  // ESC
  if (e.keyCode == 27)  {
    EXIT = true;
  }
}
    
function makeElement(what, cssclass, elt) {
  var e = document.createElement(what);
  if (cssclass) e.setAttribute('class', cssclass);
  if (elt) elt.appendChild(e);
  return e;
}
function DIV(cssclass, elt) { return makeElement('DIV', cssclass, elt); }
function CANVAS(cssclass, elt) { return makeElement('CANVAS', cssclass, elt); }
function SPAN(cssclass, elt) { return makeElement('SPAN', cssclass, elt); }
function BR(cssclass, elt) { return makeElement('BR', cssclass, elt); }
function TEXT(contents, elt) {
  var e = document.createTextNode(contents);
  if (elt) elt.appendChild(e);
  return e;
}

var simulation_num = 0;
var SIMULATIONS_PER_FRAME = 100;
var SIMULATIONS_PER_EXPERIMENT = 10000;



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
// This will be the average number of seconds between
// snack events.
var MEAN_WAIT = 2 * 60 * 60;
// Maybe should depend on snack type, like assuming that
// people have similar values for "premium" snacks, based on
// the idea that some snacks just cost more.
//
// Also, based on personal experience, the variance within a snack
// type is usually less than across snack types (and this is
// intuitive since the variance of the snacks themselves is
// obviously less between varities than between snacks). Some people
// just don't like tea or candy but like yogurt.
var PREF_MEAN = 0.75;
// Should certainly include negative values to indicate an
// aversion to a snack.
var PREF_STDDEV = 2.0;

// Generate a random preference function for n items. This is
// represented by a length-n array of utilities.
function RandomPreferenceFn(n) {
  var pref = [];
  for (var i = 0; i < n; i++) {
    pref.push(RandomGaussian() * PREF_STDDEV + PREF_MEAN);
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
  var startlen = stock.length;
  var sorted = stock.slice();
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
  if (stock.length != startlen) throw 'NO';
  var res = stock.slice();
  sorted.sort(function(a, b) { return a - b; });
  res.sort(function(a, b) { return a - b; });
  for (var i = 0; i < res.length; i++) {
    if (sorted[i] != res[i]) throw ('No: ' + sorted.join(',') + ' vs ' +
				    res.join(','));
  }
}

// Policies.
var NO_SORT = 0;
var ALWAYS_SORT = 1;
var FAVORITE_LAST = 2;
var OUTLIER_LAST = 3;

// Note that this does not clone some inner arrays that we
// know are used const. Gross.
function ClonePerson(p) {
  return { policy: p.policy,
	   eaten: p.eaten,
	   utils: p.utils,
	   snack_utils: p.snack_utils,
	   mean_wait: p.mean_wait,
	   next: p.next,
	   // XXX deep clone
	   prefs: p.prefs.slice(),
	   favorite: p.favorite.slice(),
	   outlier: p.outlier.slice(),
	   // XXX deep clone
	   exrec: p.exrec.slice() };
}

function CloneSimulation(s) {
  var p = [];
  for (var i = 0; i < s.people.length; i++) {
    p.push(ClonePerson(s.people[i]));
  }
  var h = [];
  for (var i = 0; i < s.shelves.length; i++) {
    h.push(s.shelves[i].slice());
  }
  return { shelves: h,
	   // XXX deep clone objects.
	   snacks: s.snacks.slice(),
	   people: p,
	   time_left: s.time_left };
}

function NewSimulation() {
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
  var time_left =
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
	}
      }
      favorite.push(fav);
      outliers.push(outlier);
      
      exrecs.push(MakeExRec(pref));
    }
    
    people.push({
      policy: NO_SORT,
      eaten: 0,
      // XXX generate from some distribution
      mean_wait: MEAN_WAIT,
      next: NextWait(MEAN_WAIT),
      utils: 0,
      snack_utils: 0,
      prefs: prefs,
      favorite: favorite,
      outlier: outliers,
      exrec: exrecs });
  }

  return {shelves: shelves, snacks: snacks, people: people,
	  time_left: time_left};
}

function NewStats() {
  return { snacks_left: [],
	   // Total happiness of all players.
	   total_utils: [],
	   // Total happiness of player 0, who may have a selfish policy.
	   p0_utils: [],
	   // Happiness only from eating, player 0.
	   p0_snack_utils: [],
	   // max utils - min utils
	   inequality: [] };
}

function NewTask() {
  // hyper-tune parameters, globally
  NUM_SHELVES = RandTo(20) + 2;
  NUM_PEOPLE = RandTo(40) + 2;
  MAX_VARIETY = RandTo(12) + 2;
  MIN_ITEMS = 3;
  MAX_ITEMS = 5 + RandTo(75);
  OUTLIER_RATIO = 1.0 + Math.random() * 2.5;
  COST_TO_LOOK = Math.random() * 0.10;
  MEAN_WAIT = RandomGamma(2.0) * 2 * 60 * 60;
  PREF_MEAN = RandomGamma(2.0) * 0.75;
  PREF_STDDEV = RandomGamma(2.0) * 2.0;

  return {
    experiment_sims_left: SIMULATIONS_PER_EXPERIMENT,
    cstats: NewStats(),
    estats: NewStats()
  };
}

// Entry point.
function Init() {
  task = NewTask(); 
  
  Frame();
}

function Mean(v) {
  if (v.length == 0) return 0;
  var sum = 0;
  for (var i = 0; i < v.length; i++)
    sum += v[i];
  return sum / v.length;
}

function GetStats(sim) {
  var snacks_left = 0;
  for (var s = 0; s < sim.shelves.length; s++)
    snacks_left += sim.shelves[s].length;

  var utils = 0;
  var min = sim.people[0].utils, max = sim.people[0].utils;
  for (var p = 0; p < sim.people.length; p++) {
    utils += sim.people[p].utils;
    min = Math.min(min, sim.people[p].utils);
    max = Math.max(max, sim.people[p].utils);
  }

  return { snacks_left: snacks_left,
	   utils: utils,
	   p0_utils: sim.people[0].utils,
	   p0_snack_utils: sim.people[0].snack_utils,
	   inequality: max - min };
}

function PolicyString(sim) {
  // Hack: Write to console for easy cut and paste, only on
  // the last frame.
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
  for (var i = 0; i < sim.people.length; i++) {
    var p = sim.people[i].policy;
    if (p == last_policy) {
      same_count++;
    } else {
      Flush();
      last_policy = p;
      same_count = 1;
    }
  }
  Flush();
  return s;
}

// Keeps track of what we're working on. This would work better
// as just some state of a for loop, but simulations take a while
// so we want to run them with a settimeout loop. This maintains
// the state across those callbacks.
var task = null;

var best = {
  ratio: 0,
  params: '(no)'
};

var draw_ctr = 0;
function Frame() {
  // We always enter frame with a task that has work to do.
  if (task.experiment_sims_left <= 0) throw 'illegal frame';
 
  for (var i = 0;
       i < SIMULATIONS_PER_FRAME && task.experiment_sims_left > 0;
       i++) {
    var csim = NewSimulation();
    var esim = CloneSimulation(csim);
    
    // Apply experimental condition.
    esim.people[0].policy = OUTLIER_LAST;

    while (esim.time_left > 0) Step(esim);
    while (csim.time_left > 0) Step(csim);
    simulation_num += 2;
    
    function AccStats(thesim, thestats) {
      var st = GetStats(thesim);
      thestats.snacks_left.push(st.snacks_left);
      thestats.total_utils.push(st.utils);
      thestats.p0_utils.push(st.p0_utils);
      thestats.p0_snack_utils.push(st.p0_snack_utils);
      thestats.inequality.push(st.inequality);
      // if (st.p0_snack_utils
    }

    AccStats(csim, task.cstats);
    AccStats(esim, task.estats);

    task.experiment_sims_left--;
  }

  if (task.experiment_sims_left == 0) {
    // Done. Draw it.
   
    document.body.innerHTML = '';

    // HERE: check if the outcome favors the experiment
    var cp0 = Mean(task.cstats.p0_snack_utils);
    var ep0 = Mean(task.estats.p0_snack_utils);
    
    if (cp0 > 0 && ep0 > cp0) {
      var ratio = ep0 / cp0;
      if (ratio > best.ratio) {
	best.ratio = ratio;
	console.log('!!!!!!!!! NEW BEST !!!!!!!!!!!!!');
	best.params = ParamsString();
      }
      console.log('#### Winning! ctrl p0: ' + cp0 + ' < exp p0: ' + ep0);
      DrawParams(true);
      console.log('Policies: ctrl: ' + PolicyString(csim) + ' exp: ' +
		  PolicyString(esim));
      DrawStats(task.cstats, true);
      BR('', document.body);
      BR('', document.body);
      DrawStats(task.estats, true);
    } else {
      DIV('failed', document.body).innerHTML =
	  'Losing experiment: ctrl p0: ' + cp0 + ' &gt; exp p0: ' + ep0;
    }

    // And now a new experiment.
    task = NewTask();
    if (task.experiment_sims_left == 0) throw 'whaa??';
    
  } else if ((draw_ctr % 10) == 0) {
    document.body.innerHTML = '';
    DrawParams(false);
    DrawStats(task.cstats, false);
    BR('', document.body);
    BR('', document.body);
    DrawStats(task.estats, false);
    draw_ctr = 0;
  }

  draw_ctr++;
  
  if (!EXIT) {
    if (task.experiment_sims_left == 0) throw 'huh??';
    window.setTimeout(Frame, 0);
  }
}

var HISTOWIDTH = 800;
var HISTOBINS = 400;
var HISTOHEIGHT = 120;
function DrawHistogram(title, values, par, log) {
  function GetMinMax(values) {
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
    return { min: min, max: max };
  }
  
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
    if (bins[i] > max_bin) {
      max_bin = bins[i];
      bmedian = i;
    }
  }

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

  if (log) {
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

function DrawSim(sim) {
  var top = DIV('sim', document.body);

  var d = DIV('shelves', top);
  for (var i = 0; i < sim.snacks.length; i++) {
    var sh = DIV('shelf', d);
    for (var v = 0; v < sim.shelves[i].length; v++) {
      var sn = DIV('snack', sh);
      sn.style.border = '1px solid ' + COLORS[sim.shelves[i][v]].l;
      sn.style.background = COLORS[sim.shelves[i][v]].h;
    }
  }

  // People
  for (var i = 0; i < sim.people.length; i++) {
    var p = sim.people[i];
    var pp = DIV('person', d);
    pp.innerHTML = '' + p.eaten + ' for ' + p.utils.toFixed(1) +
      '<br>next: ' + p.next.toFixed(0) + 's';
  }
}

function ParamsString() {
  var l = ['NUM_SHELVES', 'NUM_PEOPLE',
	   'MAX_VARIETY', 'MIN_ITEMS',
	   'MAX_ITEMS', 'OUTLIER_RATIO',
	   'COST_TO_LOOK', 'MEAN_WAIT',
	   'PREF_MEAN', 'PREF_STDDEV'];
  var s = '';
  for (var i = 0; i < l.length; i++) {
    if (s != '') s += ', ';
    s += l[i] + ': ' + window[l[i]];
  }
  return s;
}

function DrawParams(log) {
  var s = ParamsString();
  DIV('params', document.body).innerHTML = s;
  if (log) console.log(s);
}

function DrawStats(stats, log) {
  DrawHistogram('total utils', stats.total_utils, document.body, log);
  BR('', document.body);

  /*
  DrawHistogram('p0 utils', stats.p0_utils, document.body, log);
  BR('', document.body);
  */

  DrawHistogram('p0 snack utils', stats.p0_snack_utils, document.body, log);
  BR('', document.body);

  /*
  DrawHistogram('inequality', stats.inequality, document.body, log);
  BR('', document.body);
  */

  TEXT('sim/s: ' + (simulation_num /
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

function ChooseSnack(s, shelf_idx, player_idx) {
  var player = s.people[player_idx];
  var shelf = s.shelves[shelf_idx];
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

function Step(s) {
  // First, find the person with the first 'next' time.
  // If we kept the people in a heap, this would be much more
  // efficient. Linear search for now.
  var best_i = -1, best_next = null;
  for (var i = 0; i < s.people.length; i++) {
    if (best_next === null || s.people[i].next < best_next) {
      best_next = s.people[i].next;
      best_i = i;
    }
  }

  // Fast-forward to this moment, by subtracting from all
  // people's next-times (including the winner).
  for (var i = 0; i < s.people.length; i++) {
    s.people[i].next -= best_next;
  }
  // Also advance restocking time.
  s.time_left -= best_next;

  var player = s.people[best_i];
  var start_shelf_idx = RandTo(s.shelves.length);

  for (var shelf_offset = 0; shelf_offset < s.shelves.length; shelf_offset++) {
    var shelf_idx = (start_shelf_idx + shelf_offset) % s.shelves.length;
    var res = ChooseSnack(s, shelf_idx, best_i);
    if (res) {
      var next_shelf_idx = (shelf_idx + 1) % s.shelves.length;
      var next_shelf = s.shelves[next_shelf_idx];
      // Expected value of switching to the next shelf. We say that
      // looking to the next shelf is free.
      var e_next = player.exrec[next_shelf_idx][next_shelf.length];
      // We don't allow going back to the first shelf. We also keep
      // the current snack if it's better than what we expect to
      // find on the next shelf.
      if (shelf_offset == s.shelves.length - 1 ||
	  res.value >= e_next) {
	if (DEBUG) console.log('player ' + best_i + ' eats snack idx ' +
		    res.idx + ' from shelf ' + shelf_idx + 
		    ', with value ' + res.value + ' >= E(next)= ' +
		    e_next);
	var shelf = s.shelves[shelf_idx];
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
