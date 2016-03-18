

// ctx.moveTo(x, y);
// ctx.lineTo(x1, y1);
// ctx.stroke();

// { color: int,
//   x: int, y: int,
//   next: int?    (if null, not connected)
//   }
var points = 
[{"x":2,"y":4,"next":null,"color":0},{"x":3,"y":5,"next":null,"color":1},{"x":5,"y":8,"next":null,"color":0},{"x":4,"y":9,"next":null,"color":1},{"x":1,"y":7,"next":null,"color":0},{"x":0,"y":6,"next":null,"color":1},{"x":11,"y":4,"next":null,"color":0},{"x":12,"y":5,"next":null,"color":1},{"x":13,"y":8,"next":null,"color":0},{"x":12,"y":9,"next":null,"color":1},{"x":9,"y":7,"next":null,"color":0},{"x":8,"y":6,"next":null,"color":1}];

// Maybe should be in "real" coordinates rather than
// grid ones?
// { x: int, y : int, r: int }
var circles = [{x: 2, y: 6, r: 4}, {x: 11, y: 6, r: 4}];
var CELLSIZE = 32;
var CELLSW = 16;
var CELLSH = 16;

var CANVASWIDTH = 512;
var CANVASHEIGHT = 512;

// Return the ids of the circles that contain the point.
function Circles(p) {
  var r = [];
  for (var i = 0; i < circles.length; i++) {
    var c = circles[i];
    // Is the center in the circle?
    var dx = p.x - c.x, dy = p.y - c.y;
    if (dx * dx + dy * dy <= c.r * c.r) {
      r.push(i);
    }
  }
  return r;
}

function Clear() {
  circles = [];
  points = [];
  Draw();
}

function Draw() {
  ctx.clearRect(0, 0, CANVASWIDTH, CANVASHEIGHT);
  // Draw grid
  ctx.strokeStyle = '#ddd';
  ctx.lineWidth = 1;
  for (var y = 0; y <= CELLSH; y++) {
    ctx.beginPath();
    ctx.moveTo(0, y * CELLSIZE);
    ctx.lineTo(CELLSIZE * CELLSW, y * CELLSIZE);
    ctx.stroke();
  }

  for (var x = 0; x <= CELLSW; x++) {
    ctx.beginPath();
    ctx.moveTo(x * CELLSIZE, 0);
    ctx.lineTo(x * CELLSIZE, y * CELLSIZE);
    ctx.stroke();
  }

  // Circles.
  for (var i = 0; i < circles.length; i++) {
    var c = circles[i];
    ctx.beginPath();
    ctx.strokeStyle = '#ccf';
    ctx.lineWidth = 3;
    ctx.ellipse(c.x * CELLSIZE + CELLSIZE / 2, 
		c.y * CELLSIZE + CELLSIZE / 2,
		CELLSIZE * c.r, CELLSIZE * c.r,
		CELLSIZE * c.r, CELLSIZE * c.r,
		360);
    ctx.lineWidth = 3;
    ctx.stroke();
  }

  // All pairs lines.
  for (var i = 0; i < points.length; i++) {
    var p = points[i];
    if (p.next == null) {
      var pc = Circles(p);
      for (var j = i + 1; j < points.length; j++) {
	var q = points[j];
	if (q.next == null && p.color == q.color) {
	  var qc = Circles(q);
	  // XXX hack -- fastest way to compare equality
	  // of circle lists?
	  if ('' + pc == '' + qc) {
	    ctx.beginPath();
	    ctx.lineWidth = 6;
	    ctx.strokeStyle = ['#555', '#BBB'][p.color];
	    ctx.moveTo(p.x * CELLSIZE + CELLSIZE / 2,
		       p.y * CELLSIZE + CELLSIZE / 2);
	    ctx.lineTo(q.x * CELLSIZE + CELLSIZE / 2,
		       q.y * CELLSIZE + CELLSIZE / 2);
	    ctx.stroke();
	  }
	}
      }
    }
  }
  
  // Dots themselves (should be last)
  for (var i = 0; i < points.length; i++) {
    var p = points[i];
    ctx.beginPath();
    // console.log(p);
    ctx.fillStyle = ['#222', '#fff'][p.color];
    ctx.strokeStyle = ['#000', '#222'][p.color];
    ctx.ellipse(p.x * CELLSIZE + CELLSIZE / 2, 
		p.y * CELLSIZE + CELLSIZE / 2,
		CELLSIZE * 0.4, CELLSIZE * 0.4,
		CELLSIZE * 0.4, CELLSIZE * 0.4,
		360);
    ctx.fill();
    ctx.lineWidth = 3;
    ctx.stroke();
  }
}

function Click(e) {
  console.log(e);
  var x = e.offsetX;
  var y = e.offsetY;
  points.push({x: Math.floor(x / CELLSIZE),
	       y: Math.floor(y / CELLSIZE),
	       next: null,
	       color: e.shiftKey ? 1 : 0})
  Draw();
}

var ctx;
function Init() {
  var c = document.getElementById('canvas');
  ctx = c.getContext('2d');
  Draw();

  c.onmousedown = Click;
}
