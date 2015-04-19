// Expects:
// var portmantout --- the portmantout string.
// var spans --- as output by
//     IntervalTree<int, int>::ToJSON(itos, itos).

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

function OverlappingPoint(point, tree) {
  var ret = [];
  // format is an array [l, center, by_begin, r, by_end].
  //                     0  1       2         3  4
  while (tree != null) {
    if (point < tree[1]) {
      var beg = tree[2];
      for (var i = 0; i < beg.length && beg[i][0] <= point; i++) {
	ret.push(beg[i]);
      }
      tree = tree[0];

    } else if (tree[1] < point) {
      var end = tree[4];
      for (var i = end.length - 1; i >= 0 && point < end[i][1]; i--) {
	ret.push(end[i]);
      }
      tree = tree[3];

    } else {
      // Point is exactly the center.
      var beg = tree[2];
      for (var i = 0; i < beg.length; i++) {
	ret.push(beg[i]);
      }
      // Early exit!
      return ret;
    }
  }
  return ret;
}



var LINELENGTH = 80;
var charwidth;

function MouseHandler(start_idx) {
  return function(event) {
    // console.log(idx);
    var r = event.currentTarget.getBoundingClientRect &&
	event.currentTarget.getBoundingClientRect();
    if (!r) return;
    var xoff = event.clientX - r.left;
    var xx = Math.floor(xoff / charwidth);
    if (xx < LINELENGTH) {
      var idx = start_idx + xx;
      // console.log(start_idx + '+' + xx + ' = ' + idx + 
      //             ' which is ' + portmantout[idx]);
      var olap = OverlappingPoint(idx, spans);
      var s = [];
      for (var i = 0; i < olap.length; i++) {
	s.push(portmantout.substr(olap[i][0],
				  olap[i][1] - olap[i][0]));
      }
      console.log(s.join(', '));
    }
  };
}

function EnrichTree(t) {
  if (t == null) return;
  // format is an array [l, center, by_begin, r].

  // First delta-unencode the spans; make the second field
  // the *end* rather than the *length*.
  for (var i = 0; i < t[2].length; i++) {
    t[2][i][1] += t[2][i][0];
  }

  // Add a 4th element, by_end, which is by_begin sorted by its end
  // position.
  var bb = t[2].slice();
  bb.sort(function(a, b) {
    return a[1] - b[1];
  });
  t[4] = bb;

  // And recurse.
  EnrichTree(t[0]);
  EnrichTree(t[3]);
}

function Init() {
  EnrichTree(spans);

  // Get a single character's width; assume monospace. Supports
  // fractional widths, though.
  var deleteme = DIV('container', document.body);
  var ch = SPAN('', DIV('l', deleteme));
  TEXT('x', ch);
  var rect = ch.getBoundingClientRect();
  charwidth = rect.width;

  // Start over.
  document.body.innerHTML = '';

  BR('', document.body);
  var ctr = DIV('container', document.body);
  for (var i = 0; i < portmantout.length; i += LINELENGTH) {
    var line = DIV('l', ctr);
    // Note that substr will just take up to the end of the
    // string if we don't have enough characters left.
    var s = portmantout.substr(i, LINELENGTH);
    var t = document.createTextNode(s);
    line.appendChild(t);
    line.onmousemove = MouseHandler(i);
  }
}
