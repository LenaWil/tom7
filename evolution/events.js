/* events that can happen on the map. */
var events = {
    treestart: { x1: 3994, y1: 3463,
		 x2: 4198, y2: 3589,
		 scx: 3926, scy: 3280 },
    lifeguard: { x1: 6266, y1: 3977, 
		 x2: 6402, y2: 4055,
		 scx: 6187, scy: 3790 }
};

var stuff = {
    // These will get a bm field at runtime with
    // the list of loaded frames from p, scaled 2x.
    // also a field mc to store a movie clip,
    // and a unique index idx
    // x -= 100

    mom: { x: 4050, y: 3533, p: ['mom', 'dad'] },
    dad: { x: 4134, y: 3532, p: ['mom'] },
    shell: { x: 9362, y: 7566, p: ['mom'] }
};
