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

    (* XXX Should be some better way of indicating what songs are available,
       and updating that list (downloads) *)
    val SONGS_FILE = "songs.hero"
    val SONGS_NONFREE = "songs-nonfree.hero"
    val SONGS_DIR = "songs/"

    val cmp = String.compare (* unused *)
    val eq = op =

    exception Setlist of string

    (* val tokey : songinfo -> string = #file *)
    fun tostring (x : songid) : string = SHA1.bintohex x
    fun fromstring (x : string) =
        case SHA1.parse_hex x of
            NONE => raise Setlist "bad SHA-1"
          | SOME s => s

    fun sha1binfile file =
        if FSUtil.exists file
        then SOME (SHA1.hash_stream (SimpleStream.fromfilechunks 512 file))
        else NONE

    val trim = StringUtil.losespecl StringUtil.whitespec o StringUtil.losespecr StringUtil.whitespec
    val songs = StringUtil.readfile SONGS_FILE
    val songs = (songs ^ "\n" ^ StringUtil.readfile SONGS_NONFREE) handle _ => songs
    val songs = String.tokens (fn #"\n" => true | _ => false) songs
    val songs = List.mapPartial 
        (fn s =>
         case String.fields (fn #"|" => true | _ => false) s of
             [file, slowfactor, hard, fave, title, artist, year] =>
                 (case (Int.fromString (trim slowfactor),
                        Int.fromString (trim hard),
                        Int.fromString (trim fave)) of
                      (NONE, _, _) => (print ("Bad slowfactor: " ^ slowfactor ^ "\n"); NONE)
                    | (_, NONE, _) => (print ("Bad hard: " ^ hard ^ "\n"); NONE)
                    | (_, _, NONE) => (print ("Bad fave: " ^ fave ^ "\n"); NONE)
                    | (SOME slowfactor, SOME hard, SOME fave) => 
                          let 
                              val file = FSUtil.dirplus SONGS_DIR (trim file)
                          in
                              case sha1binfile file of
                                  NONE => (print ("Couldn't load song: " ^ file ^ "\n"); NONE)
                                | SOME sha =>
                                      let in
                                          print ("Loaded " ^ file ^ " with " ^ SHA1.bintohex sha ^ "\n");
                                          SOME { file = file, slowfactor = slowfactor, 
                                                 hard = hard, fave = fave,
                                                 title = trim title, artist = trim artist, 
                                                 year = trim year, id = sha }
                                      end
                          end)
           | _ => (print ("Bad line: " ^ s ^ "\n"); NONE)) songs


    fun allsongs () = songs
end
