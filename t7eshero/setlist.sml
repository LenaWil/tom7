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

    datatype interlude =
        SwitchToGuitar
      | SwitchToDrums
      | GetWomb

    datatype background =
        BG_SOLID of SDL.color

    datatype showpart =
        Song of { song : songid,
                  misses : bool,
                  drumbank : int Vector.vector option,
                  background : background }
      | Postmortem
      | Interlude of interlude

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
    val showfiles = ["belvederes.show"]

    val cmp = String.compare
    val eq = op =

    structure Map = SplayMapFn (struct
                                    type ord_key = songid
                                    val compare = cmp
                                end)

    exception Setlist of string

    (* val tokey : songinfo -> string = #file *)
    fun tostring (x : songid) : string = SHA1.bintohex x
    val fromstring = SHA1.parse_hex

    fun sha1binfile file =
        if FSUtil.exists file
        then SOME (SHA1.hash_stream (SimpleStream.fromfilechunks 512 file))
        else NONE

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
                              val file = FSUtil.dirplus dir (trim file)
                          in
                              case sha1binfile file of
                                  NONE => (print ("Couldn't load song: " ^ file ^ "\n"); NONE)
                                | SOME sha =>
                                      let in
                                          (* print ("Loaded " ^ file ^ " with " ^ SHA1.bintohex sha ^ "\n"); *)
                                          SOME { file = file, slowfactor = slowfactor, 
                                                 hard = hard, fave = fave,
                                                 title = trim title, artist = trim artist, 
                                                 year = trim year, id = sha }
                                      end
                          end)
           | _ => (print ("Bad line: " ^ s ^ "\n"); NONE)) songs

    fun parseshow f =
        case getlines f of
            header :: lines =>
                let val parts = List.mapPartial
                    (fn s =>
                     case map trim (String.fields (StringUtil.ischar #"|") s) of
                         ["song", file, misses, drumbank, background] =>
                             let in
                                 print "unimplemented\n";
                                 NONE
                             end
                       | ["post"] => SOME Postmortem
                       | "interlude" :: l =>
                             (case l of
                                  ["switchtoguitar"] => SOME(Interlude SwitchToGuitar)
                                | ["switchtodrums"] => SOME(Interlude SwitchToDrums)
                                | ["getwomb"] => SOME(Interlude GetWomb)
                                | _ => (print ("Bad interlude: " ^ s ^ "\n"); NONE))
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
