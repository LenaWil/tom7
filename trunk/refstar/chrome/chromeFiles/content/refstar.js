
function refstar() {
    // content.document.getElementsByTagName("div")[0].style.border = "solid blue 3px";

    var e = content.document.getElementById('siteSub');
    e.innerHTML = '<div style="border : 2px solid blue ; font-size : 24px">RefStar!</div>';

    var tb = content.document.getElementById('wpTextbox1');

    // XXX make general!
    var hit = rsCleave('[http://', tb.value);
    if (hit == undefined) {
	e.innerHTML = "there are no urls.";
    } else {
	var url = rsTakeURL(hit.aft);
	if (url == undefined) {
	    e.innerHTML = "it wasn't really a [url]";
	} else {
	    e.innerHTML = "the url: (" + "http://" + url.match +
		")";

	    ifrm = content.document.createElement("IFRAME");
	    ifrm.id = 'refstarload';
	    ifrm.setAttribute("src", 'http://' + url.match);
	    ifrm.style.width = 640+"px";
	    ifrm.style.height = 480+"px";
	    content.document.body.appendChild(ifrm); 

	    setTimeout(rsAnnounce, 2000);
	}
    }
};

function rsAnnounce() {
    var i = content.document.getElementById('refstarload');

    var e = content.document.getElementById('siteSub');
    e.innerHTML = ("title: " + i.title + ', ' + i.contentDocument.title +
		   ', ' + i.contentDocument.URL);

    i.contentDocument.getElementsByTagName("div")[0].style.border = "solid blue 3px";
};

// rsCleave(small, large)
// find the next match of small in large.
// return a two-element array of the
// string preceding the match, and the string
// following the match. If there are no matches,
// return undefined.
function rsCleave(small, large) {
//   alert("rsCleave(" + small + ", " + large + ")");
  for(var i = 0; i < large.length; i ++) {
     if (large.substr(i, small.length) == small) {
	/* match! */
//         alert("match@ " + i);
	 return  { bef : large.substr(0, i),
		   aft : large.substring(i + small.length) };
     }
  }
  return undefined;
};

function rsTakeURL(s) {
  for(var i = 0; i < s.length; i ++) {
      if (s.charAt(i) == ']') {
	  return { match : s.substr(0, i), 
		   tail : s.substring(i) };
      } else if (s.charAt(i) == ' ') return undefined;
  }
  return undefined;
};