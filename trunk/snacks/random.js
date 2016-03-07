// TODO: Clean up and start js-util with this.

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
