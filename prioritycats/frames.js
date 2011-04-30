// Cat frames!

// Each animation state is a list of frames (f) and a divisor (div).
// The divisor slows down the animation by that rate.
//
// For each frame, we save the base name of the png (p),
// and the pixel location (native) of the neck, in the East
// orientation.
var framedata = {
    buttup: {f: [{ p: 'buttup', hx: 30, hy: 15 }], div: 8}
};

var headdata = {
    headnne: {f: ['headnne'], div: 8},
    headne: {f: ['headne'], div: 8},
    heade: {f: ['heade'], div: 8},
    headse: {f: ['headse'], div: 8},
    headsse: {f: ['headsse'], div: 8}
};

