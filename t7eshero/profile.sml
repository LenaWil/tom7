(* A player's profile stores personal records, finished songs,
   achievements, etc. *)
structure Profile :> PROFILE =
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
  type profile =
    { name : string ref,
      pic : string ref,
      picsurf : SDL.surface ref,
      records : (songid * Record.record) list ref,
      achievements : (achievement * songid option * IntInf.int) list ref,
      lastused : IntInf.int ref,
      closet : Items.item list ref,
      outfit : Items.worn ref }

  val profiles = ref nil : profile list ref

  fun openpic s =
    case SDL.loadimage s of
      (* maybe could be error graphic *)
      NONE => (case SDL.loadimage DEFAULT_PROFILE_PIC of
                 NONE => error "missing default profile pic?!"
               | SOME s => s)
    | SOME s => s

  fun save () =
    let
      fun rtotf (songid, record) =
        (Setlist.tostring songid, Record.totf record)
      fun atotf (ach, songid, when) =
        (atostring ach, Option.map Setlist.tostring songid, when)
      fun ptotf { name, pic, picsurf = _, records, achievements,
                  lastused, closet, outfit } =
        ProfileTF.P { name = !name, pic = !pic,
                      records = map rtotf (!records),
                      achievements = map atotf (!achievements),
                      lastused = !lastused,
                      closet = map Items.id (!closet),
                      outfit = Items.wtostring (!outfit) }

      val f = ProfileTF.F { profiles = map ptotf (!profiles) }
    in
      ProfileTF.F.tofile FILENAME f
    end

  fun load () =
    let
      fun tftor (songid, record) =
        case Setlist.fromstring songid of
          NONE => NONE
        | SOME s => SOME (s, Record.fromtf record)
      fun tftoa (ach, songid, when) =
        (afromstring ach, Option.mapPartial Setlist.fromstring songid, when)
      fun tftop (ProfileTF.P { name, pic, records, achievements,
                               lastused, closet, outfit }) =
        { name = ref name,
          picsurf = ref (openpic pic),
          pic = ref pic,
          lastused = ref lastused,
          records = ref (List.mapPartial tftor records),
          achievements = ref (map tftoa achievements),
          closet = ref (map Items.fromid closet),
          outfit = ref (Items.wfromstring outfit) }

      val ProfileTF.F { profiles = ps } = ProfileTF.F.fromfile FILENAME
      val ps : profile list = map tftop ps
      val ps : profile list =
          ListUtil.sort (fn ({ lastused, ... },
                             { lastused = lastused', ... }) =>
                         (ListUtil.Sorted.reverse IntInf.compare)
                         (!lastused, !lastused')) ps
    in
      (* Don't leak surfaces. *)
      app (fn { picsurf, ... } => SDL.freesurface (!picsurf)) (!profiles);
      profiles := ps
    end handle IO.Io _ => print "No profile file.\n"
             | ProfileTF.Parse _ => print "Couldn't parse profile.\n"

  fun all () = !profiles

  val name : profile -> string = ! o #name
  val pic : profile -> string = ! o #pic
  val records : profile -> (songid * Record.record) list = ! o #records
  val achievements : profile ->
    (achievement * songid option * IntInf.int) list = ! o #achievements
  val lastused : profile -> IntInf.int = ! o #lastused
  val surface : profile -> SDL.surface = ! o #picsurf
  val closet : profile -> Items.item list = ! o #closet
  val outfit : profile -> Items.worn = ! o #outfit

  fun set f r x = (f r) := x

  val setname : profile -> string -> unit = set #name
  val setpic  : profile -> string -> unit = set #pic
  val setrecords : profile ->
    (songid * Record.record) list -> unit = set #records
  val setachievements : profile ->
    (achievement * songid option * IntInf.int) list -> unit =
    set #achievements
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
