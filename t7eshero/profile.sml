(* A player's profile stores personal records, finished songs, achievements, etc. *)
structure Profile :> PROFILE =
struct
    exception Profile of string
    type songid = Setlist.songid

    val FILENAME = "profiles.hero"

    datatype achievement =
        (* get perfect on a song *)
        PerfectMatch

    fun QQ #"?" = true
      | QQ _ = false

    fun atostring PerfectMatch = "PM"
    fun afromstring "PM" = PerfectMatch
      | afromstring _ = raise Profile "bad achievement"

    (* an individual profile *)
    type profile = { name : string ref,
		     pic : string ref,
		     records : (songid * Record.record list) list ref,
		     achievements : (achievement * songid option * IntInf.int) list ref,
		     lastused : IntInf.int ref }

    val profiles = ref nil : profile list ref

    fun uo f NONE = "-"
      | uo f (SOME x) = "+" ^ f x
    fun uno f "-" = NONE
      | uno f s =
	if CharVector.sub(s, 0) = #"+"
	then SOME (f (String.substring(s, 1, size s - 1)))
	else raise Profile "bad option"

    val ue = StringUtil.urlencode
    val une = (fn x => case StringUtil.urldecode x of
	       NONE => raise Profile "bad urlencoded string"
	     | SOME s => s)
    fun ulist l = StringUtil.delimit "?" (map ue l)
    fun unlist l = map une (String.tokens QQ l)

    fun rsfromstring ss =
	map (fn s =>
	     case String.tokens QQ s of
		 [song, recs] => (Setlist.fromstring song, map Record.fromstring (unlist recs))
	       | _ => raise Profile "bad record") (unlist ss)

    fun rstostring rs =
	ulist (map (fn (s, rl) =>
		    ue (Setlist.tostring s) ^ "?" ^
		    ulist (map Record.tostring rl)) rs)

    fun achstostring achs =
	ulist (map (fn (a, so, i) =>
		    ue (atostring a) ^ "?" ^ ue (uo Setlist.tostring so) ^ "?" ^ IntInf.toString i) achs)

    fun achsfromstring a =
	map (fn s => 
	     case String.tokens QQ s of
		 [ach, so, when] => (afromstring ach, uno Setlist.fromstring so, 
				     valOf (IntInf.fromString when) handle Option => raise Profile "bad achwhen")
	       | _ => raise Profile "bad achs") (unlist a)

    fun ptostring { name, pic, records, achievements, lastused } =
	ue (!name) ^ "?" ^ ue (!pic) ^ "?" ^ IntInf.toString (!lastused) ^ "?" ^
	ue (rstostring (!records)) ^ "?" ^ ue (achstostring (!achievements))

    fun pfromstring s =
	case String.tokens QQ s of
	    [name, pic, lastused, records, ach] =>
		{ name = ref (une name),
		  pic = ref (une pic),
		  lastused = ref (valOf (IntInf.fromString lastused) handle Option => raise Profile "bad lastused"),
		  records = ref (rsfromstring (une records)),
		  achievements = ref (achsfromstring (une ach)) }
      | _ => raise Profile "bad profile"

    fun save () = StringUtil.writefile FILENAME (ulist (map ptostring (!profiles)))
    fun load () =
	let
	    val s = StringUtil.readfile FILENAME
	    val ps = unlist s
	in
	    profiles := map pfromstring ps
	end

    fun all () = !profiles

    val name : profile -> string = ! o #name
    val pic : profile -> string = ! o #pic
    val records : profile -> (songid * Record.record list) list = ! o #records
    val achievements : profile -> (achievement * songid option * IntInf.int) list = ! o #achievements
    val lastused : profile -> IntInf.int = ! o #lastused

    fun set f r x = (f r) := x

    val setname : profile -> string -> unit = set #name
    val setpic  : profile -> string -> unit = set #pic
    val setrecords : profile -> (songid * Record.record list) list -> unit = set #records
    val setachievements : profile -> (achievement * songid option * IntInf.int) list -> unit = set #achievements
    val setlastused : profile -> IntInf.int -> unit = set #lastused

end
