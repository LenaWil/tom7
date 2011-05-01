// Cat frames!

// Each animation state is a list of frames (f) and a divisor (div).
// The divisor slows down the animation by that rate.
//
// For each frame, we save the base name of the png (p),
// and the pixel location (native) of the neck, in the East
// orientation.
var framedata = {
    buttup: {f: [{ p: 'buttup', hx: 30, hy: 15 }], div: 8},
    rest: {f: [{ p: 'rest', hx: 30, hy: 17 }], div: 8},
    jump: {f: [{ p: 'jump', hx: 33, hy: 3 }], div: 8},
    run: {f: [{ p: 'run1', hx: 36, hy: 6},
	      //            { p: 'run15', hx: 36, hy: 6},
              { p: 'run2', hx: 37, hy: 6}], div: 4}
};

var headdata = {
    headnne: {f: ['headnne'], div: 8},
    headne: {f: ['headne'], div: 8},
    heade: {f: ['heade'], div: 8},
    headse: {f: ['headse'], div: 8},
    headsse: {f: ['headsse'], div: 8},
    headssw: {f: ['headssw'], div: 8},
    headsw: {f: ['headsw'], div: 8},
    headw: {f: ['headw'], div: 8},
    headnw: {f: ['headnw'], div: 8},
    headnnw: {f: ['headnnw'], div: 8},
    headrest: {f: ['headrest'], div: 8}
};

function reverseHead(wh) {
    if (wh == 'headnne') return 'headnnw';
    else if (wh == 'headne') return 'headnw';
    else if (wh == 'heade') return 'headw';
    else if (wh == 'headse') return 'headsw';
    else if (wh == 'headsse') return 'headssw';
    else if (wh == 'headssw') return 'headsse';
    else if (wh == 'headsw') return 'headsw';
    else if (wh == 'headw') return 'heade';
    else if (wh == 'headnw') return 'headne';
    else if (wh == 'headnnw') return 'headnne';
    else return wh;
}