structure Setlist :> SETLIST =
struct

    (* using midi name for now *)
    type songinfo =
        { file : string,
          slowfactor : int,
          hard : int,
          fave : int,
          title : string,
          artist : string,
          year : string }
    (* XXX add MD5, loaded midi? *)
    type songid = string

    (* XXX Should be some better way of indicating what songs are available,
       and updating that list (downloads) *)
    val SONGS_FILE = "songs.hero"
    val SONGS_NONFREE = "songs-nonfree.hero"

    (* XXX use MD5. Do I even need these two functions? *)
    (* fun cmp ({ file, ... } : songinfo, { file = file2, ... } : songinfo) = String.compare (file, file2)
    fun eq (a, b) = cmp(a, b) = EQUAL *)
    val cmp = String.compare
    val eq = op =

    val tokey : songinfo -> string = #file
    fun tostring x = x
    fun fromstring x = x (* XXX check legal *)

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
                          let val file = trim file
                          in
                              SOME { file = file, slowfactor = slowfactor, 
                                     hard = hard, fave = fave,
                                     title = trim title, artist = trim artist, 
                                     year = trim year }
                          end)
           | _ => (print ("Bad line: " ^ s ^ "\n"); NONE)) songs


    fun allsongs () = songs
end
