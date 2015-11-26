structure Setlist :> SETLIST =
struct

    (* As SHA-1 binary data, 20 chars *)
    type songid = string

    (* using midi name for now *)
    type songinfo =
        { file : string,
          slowfactor : int,
          hard : int,
          fave : int,
          title : string,
          artist : string,
          year : string,
          id : songid }

    (* message at top and bottom *)
    type interlude = string * string


    datatype background =
        BG_SOLID of SDL.color
      | BG_RANDOM of int

    datatype command =
        WombOn
      | WombOff

    datatype showpart =
        Song of { song : songid,
                  misses : bool,
                  drumbank : int Vector.vector option,
                  background : background }
      | Postmortem
      | Interlude of interlude
      | Wardrobe
      | Command of command
      | Game of { song : songid, misses: bool,
                  drumbank : int Vector.vector option,
                  background : background }

    type showinfo =
        { name : string,
          date : string,
          parts : showpart list }

    (* XXX Should be some better way of indicating what songs are available,
       and updating that list (downloads) *)
    val SONGS = ("songs.hero", "songs/")
    val SONGS_NONFREE = ("songs-nonfree.hero", "songs-nonfree/")
    val songfiles = [SONGS, SONGS_NONFREE]

    (* XXXX Definitely should do better than this! *)
    val showfiles = ["belvederes.show", "practice.show"]

    val cmp = String.compare
    val eq = op =

    structure Map = SplayMapFn (struct
                                    type ord_key = songid
                                    val compare = cmp
                                end)

    structure SM = SplayMapFn (struct
                                   type ord_key = string
                                   val compare = String.compare
                               end)

    exception Setlist of string

    (* val tokey : songinfo -> string = #file *)
    fun tostring (x : songid) : string = SHA1.bintohex x
    val fromstring = SHA1.parse_hex

    fun sha1binfile file =
        if FSUtil.exists file
        then SOME (SHA1.hash_stream (SimpleStream.fromfilechunks 512 file))
        else NONE

    (* maps (base) filenames to songids. *)
    val files = (ref SM.empty) : songid SM.map ref

    fun getlines f = Script.linesfromfile f handle _ => nil

    val trim = StringUtil.losespecl StringUtil.whitespec o StringUtil.losespecr StringUtil.whitespec
    val songs = List.concat (map (fn (f, d) => map (fn s => (s, d)) (getlines f)) songfiles)
    val songs = List.mapPartial
        (fn (s, dir) =>
         case String.fields (StringUtil.ischar #"|") s of
             [file, slowfactor, hard, fave, title, artist, year] =>
                 (case (Int.fromString (trim slowfactor),
                        Int.fromString (trim hard),
                        Int.fromString (trim fave)) of
                      (NONE, _, _) => (print ("Bad slowfactor: " ^ slowfactor ^ "\n"); NONE)
                    | (_, NONE, _) => (print ("Bad hard: " ^ hard ^ "\n"); NONE)
                    | (_, _, NONE) => (print ("Bad fave: " ^ fave ^ "\n"); NONE)
                    | (SOME slowfactor, SOME hard, SOME fave) =>
                          let
                              val fileext = FSUtil.dirplus dir (trim file)
                          in
                              case sha1binfile fileext of
                                  NONE => (print ("Couldn't load song: " ^ fileext ^ "\n"); NONE)
                                | SOME sha =>
                                      let in
                                          files := SM.insert(!files, trim file, sha);
                                          (* print ("Loaded " ^ file ^ " with " ^ SHA1.bintohex sha ^ "\n"); *)
                                          SOME { file = fileext, slowfactor = slowfactor,
                                                 hard = hard, fave = fave,
                                                 title = trim title, artist = trim artist,
                                                 year = trim year, id = sha }
                                      end
                          end)
           | _ => (print ("Bad line: " ^ s ^ "\n"); NONE)) songs

    val songmap = foldl (fn (s as { id, ... }, m) => Map.insert (m, id, s)) Map.empty songs
    fun getsong id =
        case Map.find (songmap, id) of
            SOME s => s
          | NONE => raise Setlist ("couldn't find song id " ^ id)

    fun parse_songlike Ctor (file, misses, drumbank, background) =
      (case SM.find (!files, file) of
         NONE => (print ("!! couldn't find file: [" ^ file ^ "]\n"); NONE)
       | SOME s =>
           let
             val db =
               (case drumbank of
                  "" => NONE
                | _ => (case map Int.fromString
                          (String.fields (StringUtil.ischar #",") drumbank) of
                          [SOME a, SOME b, SOME c, SOME d, SOME e] =>
                            SOME (Vector.fromList [a, b, c, d, e])
                        | _ => (print ("!!! bad drumbank: " ^
                                       drumbank ^ "\n"); NONE)))
             val misses = misses <> "nomiss"
           in
             SOME (Ctor
                   { song = s, misses = misses, drumbank = db,
                     (* XXX parse background. at least colors... *)
                     background =
                     (case String.fields (StringUtil.ischar #" ") background of
                        ["random", n] =>
                          (case Int.fromString n of
                             SOME x => BG_RANDOM x
                           | NONE => BG_RANDOM 50)
                      | _ =>
                             case explode background of
                               [#"#", r, rr, g, gg, b, bb] =>
                                 (case map Word8.fromString [implode [r, rr],
                                                             implode [g, gg],
                                                             implode [b, bb]] of
                                    [SOME R, SOME G, SOME B] =>
                                      BG_SOLID (SDL.color (R, G, B, 0wxFF))
                                  | _ => BG_SOLID (SDL.color (0wx33, 0wx0, 0wx0, 0wxFF)))
                             | _ => BG_SOLID (SDL.color (0wx33, 0wx0, 0wx0, 0wxFF)))
                        })
           end)

    fun parseshow f =
      case getlines f of
        header :: lines =>
          let val parts = List.mapPartial
            (fn s =>
             case map trim (String.fields (StringUtil.ischar #"|") s) of
               ["song", file, misses, drumbank, background] =>
                 parse_songlike Song (file, misses, drumbank, background)
             | ["game", file, misses, drumbank, background] =>
                 parse_songlike Game (file, misses, drumbank, background)
             | ["post"] => SOME Postmortem
             | ["ward"] => SOME Wardrobe
             | ["command", "wombon"] => SOME (Command WombOn)
             | ["command", "womboff"] => SOME (Command WombOff)
             | ["interlude", m1, m2] => SOME(Interlude (m1, m2))
             | _ => (print ("(" ^ f ^ ") Bad line: " ^ s ^ "\n"); NONE)) lines
          in
            case map trim (String.fields (StringUtil.ischar #"|") header) of
              ["show", name, date] => SOME { name = name, date = date, parts = parts }
            | _ => (print ("Bad show starting: " ^ header ^ "\n"); NONE)
          end
      | nil => (print ("Empty show: " ^ f ^ "\n"); NONE)

    val shows = List.mapPartial parseshow showfiles

    fun allsongs () = songs
    fun allshows () = shows

end
