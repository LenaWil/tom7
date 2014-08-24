// XXX probably not needed any more, unless I do arcade mode?
var item_what = 0;
function RandomItem() {
  var it = new Item();
  item_what++;

  var heads = [];
  for (var o in window.heads) {
    heads.push(o);
  }

  var head1 = heads[Math.floor(Math.random() * window.randheads)];
  var head2 = heads[Math.floor(Math.random() * window.randheads)];

  var len = Math.floor(Math.random() * 2);

  switch (item_what % 2) {
    case 0:
    it.width = 2 + len;
    it.height = 1;
    it.shape = [CellHead(head1, LEFT)];
    for (var i = 0; i < len; i++) it.shape.push(CellWire(WIRE_WE));
    it.shape.push(CellHead(head2, RIGHT));
    break;
    case 1:
    it.width = 1;
    it.height = 2 + len;
    it.shape = [CellHead(head1, UP)];
    for (var i = 0; i < len; i++) it.shape.push(CellWire(WIRE_NS));
    it.shape.push(CellHead(head2, DOWN));
    break;
  }
  return it;
}


// Assumes GetItemAt(x, y) == null.
/*
function GetIndicator(x, y) {
  var l = [{ dx: 0, dy: -1, d: DOWN },
	   { dx: 0, dy: 1, d: UP },
	   { dx: -1, dy: 0, d: RIGHT },
	   { dx: 1, dy: 0, d: LEFT }];
  for (var i = 0; i < l.length; i++) {
    var o = l[i];
    var xx = x + o.dx;
    var yy = y + o.dy;
    if (xx >= 0 && xx < TILESW &&
	yy >= 0 && yy < TILESH) {
      var it = item.GetItemAt(xx, yy);
      if (!it) continue;
      var cell = item.GetCellByGlobal(xx, yy);
      if (!cell || cell.type != CELL_HEAD ||
	  cell.facing != o.d) continue;
      if (cell.head == window.goalin &&
	  cell.head == window.goalout)
	return INDICATOR_BOTH;
    }
  }
}
*/
