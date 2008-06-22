(* A player's profile stores personal records, finished songs, achievements, etc. *)
structure Profile :> PROFILE =
struct
    exception Profile of string
    type songid = Setlist.songid

    val FILENAME = "profiles.hero"
    val DEFAULT_PROFILE_PIC = "profilepics/default.png"

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
                     picsurf : SDL.surface ref,
                     records : (songid * Record.record list) list ref,
                     achievements : (achievement * songid option * IntInf.int) list ref,
                     lastused : IntInf.int ref,
                     closet : Items.item list ref,
                     outfit : Items.worn ref
                     }

    val profiles = ref nil : profile list ref

    fun openpic s =
        case SDL.Image.load s of
            (* maybe could be error graphic *)
            NONE => (case SDL.Image.load DEFAULT_PROFILE_PIC of
                         NONE => raise Profile "missing default profile pic?!"
                       | SOME s => s)
          | SOME s => s

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
    (* To keep invariant that nothing has the empty string as a representation *)
    fun ulist nil = "%"
      | ulist l = StringUtil.delimit "?" (map ue l)
    fun unlist "%" = nil
      | unlist s = map une (String.tokens QQ s)

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

    fun ptostring { name, pic, records, achievements, lastused, picsurf = _, closet, outfit } =
        ue (!name) ^ "?" ^ ue (!pic) ^ "?" ^ IntInf.toString (!lastused) ^ "?" ^
        ue (rstostring (!records)) ^ "?" ^ ue (achstostring (!achievements))
        (* XXX closet, outfit *)

    fun pfromstring s =
        case String.tokens QQ s of
            [name, pic, lastused, records, ach] =>
                { name = ref (une name),
                  picsurf = ref (openpic (une pic)),
                  pic = ref (une pic),
                  lastused = ref (valOf (IntInf.fromString lastused) handle Option => raise Profile "bad lastused"),
                  records = ref (rsfromstring (une records)),
                  achievements = ref (achsfromstring (une ach)),

                  (* XXXXXXXXXXXXXXX *)
                  closet = ref (Items.default_closet()),
                  outfit = ref (Items.default_outfit())
                  }
      | _ => raise Profile "bad profile"

    (* FIXME: doesn't save closet, outfit *)
    fun save () = StringUtil.writefile FILENAME (ulist (map ptostring (!profiles)))
    fun load () =
        let
            val s = StringUtil.readfile FILENAME handle _ => "%" (* empty list *)
            val ps = unlist s
        in
            (* XXX LEAK needs to free surface parameters. But we shouldn't double-load anyway. *)
            profiles := map pfromstring ps
        end

    fun all () = !profiles

    val name : profile -> string = ! o #name
    val pic : profile -> string = ! o #pic
    val records : profile -> (songid * Record.record list) list = ! o #records
    val achievements : profile -> (achievement * songid option * IntInf.int) list = ! o #achievements
    val lastused : profile -> IntInf.int = ! o #lastused
    val surface : profile -> SDL.surface = ! o #picsurf
    val closet : profile -> Items.item list = ! o #closet
    val outfit : profile -> Items.worn = ! o #outfit

    fun set f r x = (f r) := x

    val setname : profile -> string -> unit = set #name
    val setpic  : profile -> string -> unit = set #pic
    val setrecords : profile -> (songid * Record.record list) list -> unit = set #records
    val setachievements : profile -> (achievement * songid option * IntInf.int) list -> unit = set #achievements
    val setlastused : profile -> IntInf.int -> unit = set #lastused
    val setcloset : profile -> Items.item list -> unit = set #closet
    val setoutfit : profile -> Items.worn -> unit = set #outfit

    fun genplayer i =
        let
            val s = "Player " ^ Int.toString i
        in
            if List.exists (fn { name, ... } => s = !name) (!profiles) 
            then genplayer (i + 1)
            else s
        end
    fun add_default () = 
        let val p = { name = ref (genplayer 1), 
                      pic = ref DEFAULT_PROFILE_PIC,
                      picsurf = ref (openpic DEFAULT_PROFILE_PIC),
                      lastused = ref(Time.toSeconds (Time.now ())),
                      records = ref nil,
                      achievements = ref nil,
                      closet = ref (Items.default_closet()),
                      outfit = ref (Items.default_outfit()) }
        in 
            profiles := p :: !profiles;
            p
        end

end
