
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


function getmouseposwithin(e, elt) {
  e = e || window.event;

  // XXX assumes parent is document.body; wrong
  var origx = elt.offsetLeft, origy = elt.offsetTop;

  return { x: e.clientX - origx,
	   y: e.clientY - origy };
}
