
function DomMaker(ty) {
  return function(cl, par) {
    var elt = document.createElement(ty);
    if (cl) {
      elt.setAttribute('class', cl);
      elt.setAttribute('className', cl);
    }
    par && par.appendChild(elt);
    return elt;
  };
}
var DIV = DomMaker('DIV');
var SPAN = DomMaker('SPAN');
var A = DomMaker('A');
var INPUT = DomMaker('INPUT');
var TABLE = DomMaker('TABLE');
var TBODY = DomMaker('TBODY');
var TR = DomMaker('TR');
var TD = DomMaker('TD');
var TH = DomMaker('TH');
var BR = DomMaker('BR');
// var IMG = DomMaker('IMG');
var SCRIPT = DomMaker('SCRIPT');

function IMG(cl, par) {
  var img = DomMaker('IMG')(cl, par);
  img.draggable = false;
  return img;
}

function TEXT(s, par) {
  var elt = document.createTextNode(s);
  par && par.appendChild(elt);
  return elt;
}


function px(i) {
  return '' + i + 'px';
}

function objstring(obj) {
  return JSON.stringify(obj);
}

function getMillis() {
  return (new Date()).getTime();
}

function settimeoutk(ms, k) {
  window.setTimeout(k, ms);
}

// XXX maybe better for game if deterministic?
function shuffle(a) {
  for (var i = 0; i < a.length; i++) {
    var j = Math.floor(Math.random() * a.length);
    if (i != j) {
      var t = a[i];
      a[i] = a[j];
      a[j] = t;
    }
  }
}
