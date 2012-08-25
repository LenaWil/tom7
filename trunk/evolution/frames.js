// Frames of animation, mostly for the cell itself.

// Each animation state is a list of frames (f) and a divisor (div).
// The divisor slows down the animation by that rate.
//
// For each frame, we save the base name of the png (p).
//
// Canonically, these images are "facing right".
var framedata = {
    moving: {f: [{ p: 'moving1' },
                 { p: 'moving2' },
                 { p: 'moving3' },
                 { p: 'moving4' }], div: 2},
    stopped: {f: [{ p: 'stopped' }], div: 8}
    // XXX more!
};
