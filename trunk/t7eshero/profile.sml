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

    fun error s =
        let in
            print ("Profile error: " ^ s ^ "\n");
            raise Profile s
        end

    fun atostring PerfectMatch = "PM"
    fun afromstring "PM" = PerfectMatch
      | afromstring _ = error "bad achievement"

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
                         NONE => error "missing default profile pic?!"
                       | SOME s => s)
          | SOME s => s


    val (songs_ulist, songs_unlist) = (Serialize.ulistnewline, Serialize.unlistnewline)
    fun rsfromstring ss =
        map (fn s =>
             case String.tokens QQ s of
                 [song, record] => (expectopt "songid" Setlist.fromstring (une song),
                                    Record.fromstring (une record))
               | _ => error "bad record") (songs_unlist ss)

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
                 [ach, so, when] =>
                     (afromstring ach, uno (expectopt "ach-songid" Setlist.fromstring) so,
                      expectopt "bad achwen" IntInf.fromString when)
               | _ => error "bad achs") (unlist a)

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
                  lastused = ref (valOf (IntInf.fromString lastused) handle Option => error "bad lastused"),
                  records = ref (rsfromstring records),
                  achievements = ref (achsfromstring ach),
                  closet = ref (map Items.fromid (String.tokens (fn #"," => true | _ => false) closet)),
                  outfit = ref (Items.wfromstring outfit) }
      | _ => error "bad profile"


    val (profiles_ulist, profiles_unlist) =
        Serialize.list_serializerex (fn #"\r" => false | _ => true) "\n--------\n" #"$"
    fun save () = StringUtil.writefile FILENAME (profiles_ulist (map ptostring (!profiles)))
    fun load () =
        let
            val s = StringUtil.readfile FILENAME handle _ => profiles_ulist nil
            val ps = profiles_unlist s
            val ps = map pfromstring ps
            val ps : profile list =
                ListUtil.sort (fn ({ lastused, ... }, { lastused = lastused', ... }) =>
                               (ListUtil.Sorted.reverse IntInf.compare)
                               (!lastused, !lastused')) ps
        in
            (* XXX LEAK needs to free surface parameters.
               But we shouldn't double-load anyway. *)
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

    fun local_records () =
        let
            val alls =
                List.concat
                (map (fn p =>
                      let
                          val name = name p
                          val records = records p
                          val t = lastused p
                      in
                          map (fn (songid, r) => (songid, (name, r, t))) records
                      end) (all()))

            (* Now we have a list of (id, (name, record, time)) values.
               Collate them by song id. *)
            val alls = ListUtil.stratify Setlist.cmp alls
            (* Now get the best one from each. hd can't fail because
               stratify never returns empty inner lists *)
            val best = ListUtil.mapsecond (hd o ListUtil.sort
                                           (fn ((n, r, t), (nn, rr, tt)) =>
                                            case Record.cmp (r, rr) of
                                                EQUAL => IntInf.compare (t, tt)
                                              | ord => ord)) alls
        in
            best
        end

end
