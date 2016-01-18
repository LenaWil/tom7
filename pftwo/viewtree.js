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

function StatsRec(node) {
  // Total expansions and max score.
  var stats = { e: node.e || 0, ms: node.s };
  
  if (node.c) {
    for (var i = 0; i < node.c.length; i++) {
      var s = StatsRec(node.c[i]);
      if (s.ms > stats.ms) stats.ms = s.ms;
      if (s.e == s.e) {
	stats.e += s.e;
      }
    }
  }

  node.stats = stats;
  
  return stats;
}

function AppendScore(elt, s) {
  var d = DIV('score', elt);
  var pct = (s * 100.0) + '%';
  d.style.backgroundImage =
      'linear-gradient(90deg,#77f,#77f ' + pct + ',#eef ' + pct + ',#eef)';
  d.innerHTML = '' + s;
}

function BuildRec(div, node) {
  if (node.g) {
    var img = IMG('screenshot', div);
    img.src = 'tree/' + node.i + '.png';
  } else {
    var img = DIV('missingimg', div);
    TEXT('?', img);
  }

  if (node.e) {
    TEXT('Expansions here: ' + node.e, div);
    BR('', div);
    TEXT('Expansions subtree: ' + node.stats.e, div);
    BR('', div);
    TEXT('Score here: ' + node.s, div);
    BR('', div);
    TEXT('Max score subtree: ' + node.stats.ms, div);
  } else {
    TEXT('(never visited)', div);
  }
  BR('clear', div);
  
  // XXX sort children by total expansions or score?
 
  if (node.c) {
    // Sort descending.
    node.c.sort(function(a, b) {
      if (a.stats.e == b.stats.e) {
	if (a.stats.ms == b.stats.ms) return 0;
	else if (a.stats.ms > b.stats.ms) return -1;
	else return 1;
      }
      else if (a.stats.e > b.stats.e) return -1;
      else return 1;
    });

    for (var i = 0; i < node.c.length; i++) {
      if (i > 20) {
	// XXX make it possible to expand?
	TEXT('(And ' + (node.c.length - i) + ' hidden...)',
	     DIV('', div));
	break;
      }
      var ch = DIV('unexpanded', div);
      AppendScore(ch, node.c[i].stats.ms);
      TEXT('[' + node.c[i].i + ']: ' +
	   node.c[i].stats.e + ' expansion(s), ' +
	   node.c[i].stats.ms + ' max score ' +
	   '»', ch);
      ch.onclick = function(chelt, child) {
	// XXX actually just delete it?
	return function () {
	  var d = DIV('node');
	  chelt.parentNode.insertBefore(d, chelt.nextSibling);
	  chelt.onclick = undefined;
	  chelt.parentNode.removeChild(chelt);
	  BuildRec(d, child);
	};
      }(ch, node.c[i]);
    }
  }
  BR('clear', div);
}

function Init() {
  StatsRec(treedata);
  
  document.body.innerHTML = '';
  var top = DIV('', document.body);
  var div = DIV('node', top);
  BuildRec(div, treedata);
}
