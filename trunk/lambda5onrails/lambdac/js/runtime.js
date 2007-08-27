
/* This is the LAMBDAC Javascript runtime. It implements various
   things that the code generated by the compiler needs. */

var lc_messages = true;
function lc_message(s) {
    if (lc_messages) {
	var d = document.createElement("div");
	d.innerHTML = s;
	/* var t = document.createTextNode(s); */
	var m = document.getElementById("messages");
	if (m != undefined) m.appendChild(d);
    }
};

function lc_error(s) {
    var m = document.getElementById("page");
    if (m != undefined) m.innerHTML = '<div style="border:2px solid red ; margin : 2em ; padding : 1 em ; width : 300px; text-align : center">' + s + '</div>';
    // alert(s);
};


/* Implementation of imperative queues, used for the "thread" queue. */

function lc_queue () {
    /* queues start empty */
    this.contents = new Array();
};

lc_queue.prototype.enq = function (x) {
    this.contents.push(x);
};

/* PERF this is linear time by definition!! */
lc_queue.prototype.deq = function () {
    /* returns undefined if there are no elements */
    return this.contents.shift ();
};

var lc_threadqueue = new lc_queue ();

/* A thread is a pair of integers and array of values, so that we can use
   function.apply */
function lc_enq_thread(g, f, args) {
    lc_message('enqueue ' + g + '.' + f + '(args)');
    lc_threadqueue.enq( { g : g, f : f, args : args } );
};

/* run a waiting thread, if any. We reschedule this function
   using setTimeout. */
function lc_schedule() {
    // lc_message('schedule.');
    var t = lc_threadqueue.deq ();
    if (t == undefined) {
	/* no more threads to run */
	/* this shouldn't happen, since we call the scheduler once
           for each enqueued thread. */
	alert('no threads!');
    } else {
	var f = globalcode[t.g][t.f];
	/* apply wants a 'this' object, which we don't care about; send undefined */
	f.apply(undefined, t.args);
    }
};

/* XXX maybe inside lc_enq_thread to force it always? */
function lc_yield() {
    /* ?? what timeout to use? */
    setTimeout(lc_schedule, 10);
};

/* another entry point is through the ML5 'say' construct,
   which produces javascript source code (as a string) that
   will enqueue a thread. The support code is as follows: */

/* saved threads. only used by the following two functions */
var lc_saved = [];

function lc_saveentry(g, f, args) {
    lc_saved.push( { g : g, f : f, args : args });
    return lc_saved.length - 1;
};

/* start up a previously saved thread */
function lc_enter(i) {
    lc_threadqueue.enq( lc_saved[i] );
    lc_yield();
};


function lc_clone(obj) {
    for (i in obj) {
        this[i] = obj[i];
    }
};

function lc_jstosi(obj, n) {
    if (n <= 0) {
	return '...';
    } else {
	var otr = '';
	var ctr = '';
	if ((n % 2) == 1) {
	    otr = '<tr>';
	    ctr = '</tr>';
	}

	var s = '<table style="border:1px solid ' + (((n%2)==1)?'#AAAAFF':'#FFAAAA') + 
	        '"><tr><th colspan=2>' + obj + '</th></tr>';
	/* not for strings... causes infinite loop (!) */
	if ((n % 2) != 1) s += '<tr>';
	if (obj == undefined || obj == null) {
	    s += "null|undefined";
	} else {
	    if (obj.localeCompare == undefined) {
		for (i in obj) {
		    s += otr + '<td>' + i + '</td><td>' + lc_jstosi(obj[i], n - 1) + '</td>' + ctr;
		}
	    }
	}
	if ((n % 2) != 1) s += '</tr>';
	return s + '</table>';
    }
};

function lc_jstosi_ascii(obj, n) {
    if (n <= 0) {
	return '...';
    } else {
	var s = '[' + obj + ' with ';
	for (i in obj) {
	    s += i + ' : ' + lc_jstosi(obj[i], n - 1) + ', ';
	}
	return s + ']';
    }
};


function lc_jstos(obj) {
    if (lc_messages)
	return lc_jstosi(obj, 10);
    else return "no-messages";
};

/* PERF no need to keep modifying the string; could just use position */
function lc_tokstream(s) {
    this.str = s;
};

lc_tokstream.prototype.next = function () {
    // alert("start(" + this.str + ")");
    /* eat any spaces at start */
    // lc_message('before: [' + this.str + ']');
    if (this.str.length > 0 && this.str.charAt(0) == ' ') {
	for(var j = 0; j < this.str.length; j ++) {
	    if (this.str.charAt(j) != ' ') {
		this.str = this.str.substring(j);
		break;
	    } 
	}
    }
    // lc_message('eaten: [' + this.str + ']');

    // alert("eaten(" + this.str + ")");
    for(var i = 0; i < this.str.length; i ++) {
	if (this.str.charAt(i) == ' ') {
	    var r = this.str.substr(0, i);
	    /* skipping the space */
	    this.str = this.str.substring(i + 1);
	    // alert("[" + r + "/" + this.str + "]");
	    return r;
	}
    }

    /* no separator */
    if (this.str.length > 0) {
	var r = this.str;
	this.str = "";
	return r;
    } else {
	/* no more tokens */
	return undefined;
    }
};

lc_tokstream.prototype.getint = function () {
    var n = this.next ();
    // lc_message('getint of [' + n + ']');
    var s = 1 * n;
    if (s == undefined || isNaN(s)) {
	alert("expected int");
	throw(0);
    } else return s;
};

lc_tokstream.prototype.showrest = function () {
    return this.str;
};


/* Sometimes we have an object and need to create
   a remote reference to it. We can't just send the
   object, so we put it in a local array of objects
   and send the index instead. */
var lc_locals = [];

function lc_add_local(ob) {
    lc_message('adding a local.');
    lc_locals.push(ob);
    return lc_locals.length - 1;
};

/* dictionary used for references. we can use this
   for local objects that can't be marshaled, too. */
var lc_ref_dict = { w : "DP", p : "r" };

/*
    { w : tag, ... } where 

      tag (string)
      DP       p : c, C, a, d, i, s, v, A, r, w
      DR       v : array of { l : String, v : Object }
      DS       v : array of { l : String, v : Object (maybe missing) }
      DE       d : String, v : array of Object
      DL       s : String
      DA       s : array of String, v : Object

*/

function lc_lookup(G, s) {
    var ct = G;
    while (ct != undefined) {
	lc_message("head : " + ct.head);
	if (ct.head == s) return ct.data;
	else ct = ct.next;
    }
    return undefined;
};

var lc_dictdict  = { w : "DP", p : "d" };
var lc_wdictdict = { w : "DP", p : "w" };
function lc_umg(G, loc, d, b) {
    switch(d.w) {
    case "DL": {
	var nd = lc_lookup(G, d.s);
	if (nd == undefined) {
	    alert("um couldn't lookup " + d.s);
	    throw(0);
	}
	return lc_umg(G, loc, nd, b);
    }
    case "D@": {
	/* just changes focus */
	return lc_umg(G, d.a, d.v, b);
    }
    case "DH": {
	var G2 = { head : d.d, data : "*wvoid*", next : G };
	return lc_umg(G2, "*blurred*", d.v, b);
    }
    case "DE": {
	var thed = lc_umg(G, loc, lc_dictdict, b)
	var G2 = { head : d.d, data : thed, next : G };
	var a = { d : thed };
	/* then find a series of values */
	for(var i = 0; i < d.v.length; i ++) {
	    a["v" + i] = lc_umg(G2, loc, d.v[i], b);
	}
	return a;
    }
    case "DR": {
	var a = { };
	for(var i = 0; i < d.v.length; i ++) {
	    var s2 = b.next ();
	    if (d.v[i].l != s2) {
		alert("labels mismatch " + d.v[i].l + " " + s2);
		throw(0);
	    }
	    a[s2] = lc_umg(G, loc, d.v[i].v, b);
	}
	return a;
    }
    case "DP": {
	switch(d.p) {
	case "c": {
	    // lc_message('at dp c: [' + b.showrest () + ']');
	    var g = b.getint ();
	    var f = b.getint ();
	    // lc_message('so I make: ' + g + ' ' + f);
	    return { g : g, f : f };
	}
	case "C": return b.getint ();
	case "a": return unescape(b.next ());
	case "r": {
	    /* a reference is always marshaled as an integer. */
	    var ri = b.getint ();
	    /* but we might reconstitute it depending on where
               we are. */
	    if (loc == "home") return lc_locals[ri];
	    else if (loc == "*blurred*") {
		alert("tried to reconstitute ref when blurred...");
		throw(0);
	    } else return ri;
	}
	case "w": {
	    /* world dictionary, represented as a string */
	    return unescape(b.next ());
	}
	case "d": {
	    var t = b.next ();
	    switch(t) {
	    case "DP": {
		var p = b.next ();
		/* XX should check it's valid? */
		// lc_message("dp " + p + "/");
		return { w : "DP", p : p };
	    }
	    case "DL": return { w : "DL", s : b.next () }
	    case "DR": {
		/* DR 11 DP i 2 0 1 1234 */
		var n = b.getint ();
		var a = [];
		for(var i = 0; i < n; i ++) {
		    var l = b.next ();
		    var v = lc_umg(G, loc, lc_dictdict, b);
		    a.push({ l : l, v : v });
		}
		return { w : "DR", v : a };
	    }
	    case "DE": {
		var nam = b.next ();
		var n = b.getint ();
		var a = [];
		for(var i = 0; i < n; i ++) {
		    a.push(lc_umg(G, loc, lc_dictdict, b));
		}
		return { w : "DE", d : nam, v : a };
	    }
	    case "D@": {
		var d = lc_umg(G, loc, lc_dictdict, b);
		var a = lc_umg(G, loc, lc_wdictdict, b);
		return { w : "D@", a : a, v : d };
	    }
	    case "DH": {
		var d = b.next ();
		var v = lc_umg(G, loc, lc_dictdict, b);
		return { w : "DH", d : d, v : v };
	    }
	    default:
		alert('unimplemented unmarshal actual dict: ' + t);
		throw(0);
	    }
	}
	/* allarrow is just an int */
	case "A": return b.getint ();
	case "i": return b.getint ();
	/* skip the initial period */
	case "s": return unescape(b.next ().substring(1));
	case "v": alert("can't unmarshal at void"); throw(0);
	default: alert("bad prim dict: " + d.p); throw(0);
	}
    }

    default:
	alert('unimplemented umg: ' + d.w);
	throw 0;
    }
};

function lc_unmarshal(d, b) {
    return lc_umg(undefined, "home", d, new lc_tokstream(b));
};

/* a thread has arrived at this world, as marshaled bytes */
var lc_comedict = { w : "DE", d : "entry", v : [{ w : "DP", p : "c"}, { w : "DL", s : "entry"}] };

function lc_come(bytes) {
    lc_message('come ' + bytes);
    var pack = lc_unmarshal(lc_comedict, bytes);
    lc_message('unmarshal success.');
    lc_message('unmarshal result: ' + lc_jstos(pack));
    var f = pack.v0;
    var arg = pack.v1;
    lc_enq_thread(f.g, f.f, [ arg ]);
    lc_yield();
};

/* jump to the server, using these marshaled bytes */
function lc_go(bytes) {
    var req;
    if (window.XMLHttpRequest) {
        req = new XMLHttpRequest();

        req.onreadystatechange = function () {
	    /* just die; continuation happens when the server
               calls us back on the toclient connection. 
               but, we might want to alert the programmer
               to failure (how do we detect it?) by an exception.

               it seems that in mozilla when the connection fails,
               we'll have readyState 4 and exceptions thrown when
               accessing status or statusText.
            */
	    lc_message('go ' + req.readyState);
	    // alert ('go readystate: ' + req.readyState);
	    // + ' ' + req.status + ' ' + req.responseText);
	};
	/* post (we'll send body), toserver url, asynchronous */
        req.open("POST", session_serverurl + session_id, true);
	req.setRequestHeader ('Content-Type', 'application/ml5');
	req.setRequestHeader ('Connection', 'close');
        req.send(bytes);
    } else if (window.ActiveXObject) {
	alert('IE not supported (yet?)');
	/* 
        req = new ActiveXObject("Microsoft.XMLHTTP");
        if (req) {
            req.onreadystatechange = think;
            req.open("GET", url, true);
            req.send();
        }
        */
    }
};

function lc_go_mar(addr, bytes) {
    /* what we do depends on which world this is. */
    switch(addr) {
    case "home":
	/* self-call */
	lc_come(bytes);
	break;
    case "server":
	/* call to server */
	lc_go(bytes);
	break;
    default:
	alert('unknown addr ' + addr);
    }
};

/* we maintain a single open connection to the server
   that waits for messages */
// XXX proxies might rewrite this, urgh
// also, there is no guarantee that the whole message
// will have arrived on the first call to readyState.
// probably we should bracket the message somehow
var lc_toclient;
function lc_handle_toclient() {
    if (lc_toclient.readyState == 4) {
	// alert('got server message!');
	lc_message('got server message');
	var m = lc_toclient.responseText;
	if (m == undefined || m == '') {
	    lc_error('server message is empty, assuming termination');
	} else {
	    // lc_message(escape(m));
	    /* attempt to find the bracketed expression
               <lambda5message>MSG</lambda5message> */
	    var otag = '<lambda5message>';
	    var ctag = '</lambda5message>';
	    var start = m.indexOf(otag);
	    var end   = m.indexOf(ctag);

	    if (start >= 0 && end > start) {
		var u = m.substring(start + otag.length, end);
		lc_come(u);
		/* then reinstate the connection */
		lc_make_toclient();
	    } else {
		lc_message('server message is malformed or incomplete, waiting...');
	    }
	}
    }
    /* otherwise nice to show status somewhere? */
};
/* assumes toclient connection doesn't exist or can
   be safely lost */
function lc_make_toclient() {
    if (window.XMLHttpRequest) {
        lc_toclient = new XMLHttpRequest();

        lc_toclient.onreadystatechange = lc_handle_toclient;

	/* get (no data), toclient url, must be asynchronous because
           the whole point is to wait until the server is ready to
           notify us (push) */
        lc_toclient.open("GET", session_clienturl + session_id, true);
	lc_toclient.setRequestHeader ('Content-Type', 'application/ml5');
	lc_toclient.setRequestHeader ('Connection', 'close');
        lc_toclient.send('');
    } else if (window.ActiveXObject) {
	alert('IE not supported (yet?)');
    }
};

/*
    { w : tag, ... } where 

      tag (string)
      DP       p : c, C, a, d, i, s, v, r, or A
      DR       v : array of { l : String, v : Object }
      DS       v : array of { l : String, v : Object (maybe missing) }
      DE       d : String, v : array of Object
      DL       s : String  (lookup this var for typedict)
      DW       s : String  (lookup this var for worlddict)
      DA       s : array of String, w : array of String, v : Object
      D@       v : Object, a : String
*/

function lc_marshalg(G, loc, dict, va) {
    switch(dict.w) {
    case "DR": {
	var s = '';
	for(var i = 0; i < dict.v.length; i ++) {
	    s += ' ' + dict.v[i].l + ' ' + lc_marshalg(G, loc, dict.v[i].v, va[dict.v[i].l]);
	}
	return s;
    }
    case "DH": {
	/* shamrock doesn't change the representation, but it does
           blur the focus. The body cannot be marshaled with respect
           to a particular concrete world, since it is parametric
           in its world. The dictionary variable should never be
           looked up; the dynamic dictionary is instead installed
           via an embedded AllLam. (Or else this shamrock does not
           use its world variable at all.) */
	var G2 = { head : dict.d, data : "*wvoid*", next : G };
	return lc_marshalg(G2, "*blurred*", dict.v, va);
    }
    case "D@": {
	/* just changes focus */
	return lc_marshalg(G, dict.a, dict.v, va);
    }
    case "DP": {
	switch(dict.p) {
	case "c": return va.g + ' ' + va.f;
	case "C": return ''+va;
	case "A": return ''+va; /* allarrow is a number */
	case "a": return escape(va);
	/* always prepend a period so that parsing won't be confused
           by the empty string */
	case "s": return '.' + escape(va);
	case "i": return ''+va;
	case "r": {
	    /* when marshaling a ref, we have different behavior depending
               on where the ref lives. If it is a local ref (loc is "home")
               then we put it in a table. If it is a remote ref, then it
               is already represented as a remote label (int) so we just
               marshal it as an integer. */
	    if (loc == "home") {
		var i = lc_add_local(va);
		return ''+i;
            } else if (loc == "*blurred*") {
		// Maybe this can happen if closure conversion is too
		// conservative?
		alert("unimplemented: tried to marshal blurred ref");
		throw(0);
	    } else {
		return ''+va;
	    }
	}
        case "w": return escape(va);
	case "d": {
	    /* ah, how the tables have turned! */
	    switch (va.w) {
	    case "DP":
		/* we use the same code as the p field, conveniently */
		return 'DP ' + va.p;
	    case "DL":
		return 'DL ' + va.s;
		break;
	    case "DR": {
		var s = 'DR ' + va.v.length;
		for(var i = 0; i < va.v.length; i ++) {
		    /* it is filled with dictionaries as well */
		    s += ' ' + va.v[i].l + ' ' + lc_marshalg(G, loc, lc_dictdict, va.v[i].v);
		}
		return s;
	    }
	    case "DE": {
		var s = 'DE ' + va.d + ' ' + va.v.length;
		for(var i = 0; i < va.v.length; i ++) {
		    s += ' ' + lc_marshalg(G, loc, lc_dictdict, va.v[i]);
		}
		return s;
	    }
	    case "DF": {
		return 'DF ' + escape(va.l);
	    }
	    case "D@": {
		return 'D@ ' + lc_marshalg(G, loc, lc_dictdict, va.v) + ' ' +
		    lc_marshalg(G, loc, lc_wdictdict, va.a);
	    }
	    case "DH": {
		return 'DH ' + va.d + ' ' + lc_marshalg(G, loc, lc_dictdict, va.v);
            }
	    default:
		alert('unimplemented dict to be marshaled: ' + va.w);
		throw 'unimplemented';
	    }
	}
	case "v": {
	    alert('tried to marshal void'); 
	    throw 0;
	}
	default:
	    alert('bad dp dict:' + dict.p);
	    throw 0;
	}
	break;
    }
    case "DE": {
	var thed = va.d;
	/* marshal the dictionary */
	var s = lc_marshalg(G, loc, lc_dictdict, thed);

	/* PERF hmm. could use prototype? but then lookup is slower... */
	
	// var G2 = new lc_clone(G);
	// G2[dict.d] = thed;
	var G2 = { head : dict.d, data : thed, next : G };

	/* then add all the components */
	for(var i = 0; i < dict.v.length; i ++) {
	    s += ' ' + lc_marshalg(G2, loc, dict.v[i], va['v' + i]);
	}
	return s;
    }
    case "DL": {
	var dd = lc_lookup(G, dict.s);
	if (dd == undefined) {
	    alert('marshal dl failed: ' + dict.s);
	    throw(0);
	}
	return lc_marshalg(G, loc, dd, va);
    }
    default:
	alert('unimplemented or bad dictionary in marshal: ' + dict.w);
	/* throw "lc_marshalg";*/
	return 'unimplemented-marshal';
    }
};

function lc_marshal(dict, va) {
    lc_message('<b>marshal</b> dict: ' + lc_jstos(dict));
    lc_message('<b>marshal</b> value: ' + lc_jstos(va));
    return lc_marshalg({dummy : 0}, "home", dict, va);
};

/* XXX need an actual representation for exceptions. */
var Match = 0;

/* We should perhaps support an overlay network where
   there are multiple named worlds and some general way of
   specifying them. Otherwise there is just one other world,
   namely the server: */
var server = "server";
/* We need our own address, too. Note that 'home' is a javascript
   builtin (function that sends us home) so there's some potential
   for weirdness here. Probably the stdlib should import it at another
   label... */
var home   = "home";

/* start this immediately; we'll need it */
lc_make_toclient ();

/* XXX separate this stuff out into separate js files, as support code
   for the stdlib. */
var lc_domnode_dict = lc_ref_dict;

function lc_domsetobj(node, field, o) {
    node[field] = o;
};

function lc_document_getelementbyid(s) {
    var x = document.getElementById(s);
    if (x == null || x == undefined) throw "getelementbyid failed";
    else return x;
};

function lc_domgetobj(node, field) {
    return node[field];
};

function lc_nomessages(unit) {
    var m = document.getElementById("messages");
    if (m != undefined) m.innerHTML = '';
    lc_messages = false;
};

function lc_newdate(unit) {
    return new Date();
};

function lc_time_difference(st, en) {
    return 0 + (en - st);
};

function lc_time_lessthan(a, b) {
    return (a < b) ? { t : "true" } : { t : "false" };
}

function lc_time_eq(a, b) {
    return (a === b) ? { t : "true" } : { t : "false" };
}

/* XXX should be a prim, not extern */
function lc_itos(i) {
    return ''+i;
};

