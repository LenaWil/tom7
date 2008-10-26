(* A player's profile stores personal records, finished songs, achievements, etc. *)
structure Profile :(*>*) PROFILE =
struct
    exception Profile of string
    type songid = Setlist.songid

    val FILENAME = "profiles.hero"
    val DEFAULT_PROFILE_PIC = "profilepics/default.png"

    open Serialize

    datatype achievement =
        (* get perfect on a song *)
        PerfectMatch

    fun atostring PerfectMatch = "PM"
    fun afromstring "PM" = PerfectMatch
      | afromstring _ = raise Profile "bad achievement"

    (* an individual profile *)
    type profile = { name : string ref,
                     pic : string ref,
                     picsurf : SDL.surface ref,
                     records : (songid * Record.record) list ref,
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


    val (songs_ulist, songs_unlist) = Serialize.list_serializer "\n" #"\\"
    fun rsfromstring ss =
        map (fn s =>
             case String.tokens QQ s of
                 [song, record] => (Setlist.fromstring (une song), Record.fromstring (une record))
               | _ => raise Profile "bad record") (songs_unlist ss)

    fun rstostring rs =
        songs_ulist (map (fn (s, r) =>
                          ue (Setlist.tostring s) ^ "?" ^
                          ue (Record.tostring r)) rs)

    fun achstostring achs =
        ulist (map (fn (a, so, i) =>
                    ue (atostring a) ^ "?" ^ ue (uo Setlist.tostring so) ^ "?" ^ IntInf.toString i) achs)

    fun achsfromstring a =
        map (fn s => 
             case String.tokens QQ s of
                 [ach, so, when] => (afromstring ach, uno Setlist.fromstring so, 
                                     valOf (IntInf.fromString when) handle Option => raise Profile "bad achwhen")
               | _ => raise Profile "bad achs") (unlist a)

    val (pro_ulist, pro_unlist) = Serialize.list_serializer " " #"#"
    fun ptostring { name, pic, records, achievements, lastused, picsurf = _, closet, outfit } =
        pro_ulist [!name, !pic, IntInf.toString (!lastused),
                   rstostring (!records), achstostring (!achievements),
                   StringUtil.delimit "," (map Items.id (!closet)),
                   Items.wtostring (!outfit)]

    fun pfromstring s =
        case pro_unlist s of
            [name, pic, lastused, records, ach, closet, outfit] =>
                { name = ref name,
                  picsurf = ref (openpic pic),
                  pic = ref pic,
                  lastused = ref (valOf (IntInf.fromString lastused) handle Option => raise Profile "bad lastused"),
                  records = ref (rsfromstring records),
                  achievements = ref (achsfromstring ach),
                  closet = ref (map Items.fromid (String.tokens (fn #"," => true | _ => false) closet)),
                  outfit = ref (Items.wfromstring outfit) }
      | _ => raise Profile "bad profile"


    val (profiles_ulist, profiles_unlist) = Serialize.list_serializer "\n--------\n" #"$"
    fun save () = StringUtil.writefile FILENAME (profiles_ulist (map ptostring (!profiles)))
    fun load () =
        let
            val s = StringUtil.readfile FILENAME handle _ => profiles_ulist nil
            val ps = profiles_unlist s
            val ps = map pfromstring ps
            val ps = ListUtil.sort (fn ({ lastused, ... }, { lastused = lastused', ... }) =>
                                    (ListUtil.Sorted.reverse IntInf.compare) (!lastused, !lastused')) ps
        in
            (* XXX LEAK needs to free surface parameters. But we shouldn't double-load anyway. *)
            profiles := ps
        end handle Record.Record s => (Hero.messagebox ("Record: " ^ s); raise Hero.Exit)

    fun all () = !profiles

    val name : profile -> string = ! o #name
    val pic : profile -> string = ! o #pic
    val records : profile -> (songid * Record.record) list = ! o #records
    val achievements : profile -> (achievement * songid option * IntInf.int) list = ! o #achievements
    val lastused : profile -> IntInf.int = ! o #lastused
    val surface : profile -> SDL.surface = ! o #picsurf
    val closet : profile -> Items.item list = ! o #closet
    val outfit : profile -> Items.worn = ! o #outfit

    fun set f r x = (f r) := x

    val setname : profile -> string -> unit = set #name
    val setpic  : profile -> string -> unit = set #pic
    val setrecords : profile -> (songid * Record.record) list -> unit = set #records
    val setachievements : profile -> (achievement * songid option * IntInf.int) list -> unit = set #achievements
    val setlastused : profile -> IntInf.int -> unit = set #lastused
    val setcloset : profile -> Items.item list -> unit = set #closet
    val setoutfit : profile -> Items.worn -> unit = set #outfit

    fun setusednow p = setlastused p (Time.toSeconds (Time.now ()))

    fun genplayer i =
        let
            val s = if i > 100
                    then "Player " ^ Int.toString (i - 100)
                    else BandName.random_name ()
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
