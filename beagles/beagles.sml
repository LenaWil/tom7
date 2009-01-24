
structure Beagles =
struct

    exception Beagles of string

    fun readcsv f = CSV.readex [CSV.ALLOW_CRLF, CSV.TRIM_WHITESPACE] (Reader.fromfile f)
    val filenames = ["01-introducing.txt",
                     "02-meet.txt",
                     "03-second.txt",
                     "04-hard.txt",
                     "05-something.txt",
                     "06-65.txt",
                     "07-vi.txt",
                     "08-help.txt",
                     "09-rubber.txt",
                     "10-yesterday.txt",
                     "11-revolver.txt",
                     "12-sgt.txt",
                     "13-magical.txt",
                     "14-white.txt",
                     "15-yellow.txt",
                     "16-abbey.txt",
                     "17-hey.txt",
                     "18-let.txt"]

    type rating = string * real
    type result = { album : string * rating * rating,
                    songs : (string * rating * rating) list }

    fun blank s = StringUtil.losespecsides StringUtil.whitespec s = ""

    fun parse ((albumname :: _) :: lines) : result =
        let
            val songsrev = ref nil
            fun readlines ((songname :: laura :: lauras :: tom :: toms :: _) :: rest) =
                (print ("songname [" ^ songname ^ "]\n") ;
                (* skip if there's no song name. *)
                if blank songname
                then readlines rest
                else (case (Real.fromString lauras, Real.fromString toms) of
                          (SOME ls, SOME ts) => 
                              if StringUtil.lcase songname = "album"
                              then ((laura, ls), (tom, ts))
                              else 
                                  let in
                                      songsrev := (songname, (laura, ls), (tom, ts)) :: !songsrev;
                                      readlines rest
                                  end
                        | _ => let in
                                  print ("Warning: Incomplete data for " ^ songname ^ "\n");
                                  readlines rest
                               end)

                    )
              | readlines ((songname :: _) :: rest) =
                    let in
                        if blank songname
                        then ()
                        else print ("Short line for " ^ songname ^ "\n");
                        readlines rest
                    end
              | readlines (nil :: rest) = readlines rest
              | readlines nil = raise Beagles ("Didn't find album line (" ^ albumname ^ ")")

            val (albuml, albumt) = readlines lines
        in
            { album = (albumname, albuml, albumt),
              songs = rev (!songsrev) }
        end
      | parse _ = raise Beagles "Didn't start with album header?"

    val pages : result list = map parse (map readcsv filenames)
        handle e as Beagles s => (print ("Couldn't parse: " ^ s ^ "\n"); raise e)
             | e as CSV.CSV s => (print ("Couldn't parse CSV: " ^ s ^ "\n"); raise e)

end
