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

    (* No exponential notation *)
    fun ertos r = if (r > ~0.000001 andalso r < 0.000001) then "0.0" else (Real.fmt (StringCvt.FIX (SOME 4)) r)
        
    (* Don't use SML's dumb ~ *)
    fun rtos r = if r < 0.0 
                 then "-" ^ ertos (0.0 - r)
                 else ertos r

    (* XXX move this to simple svg library *)
    datatype svgelem =
        Rect of { x : real, y : real, width : real, height : real,
                  stroke : string option, fill : string option,
                  opacity : real option }
      (* angle is rotation angle, in degrees clockwise. NONE means regular left-to-right. 
         Rotation center is the left hand end of the baseline. *)
      | Text of { x : real, y : real, style : string option, text : string, angle : real option }
        (* use "none" for no fill *)
      | Line of { fill : string, stroke : string, strokewidth : real option,
                  points : (real * real) list, opacity : real option }

    fun oattr_real name NONE = ""
      | oattr_real name (SOME v) = " " ^ name ^ "=\"" ^ rtos v ^ "\""
    fun attr_real name v = oattr_real name (SOME v)

    fun oattr_str name NONE = ""
      | oattr_str name (SOME v) = " " ^ name ^ "=\"" ^ v ^ "\"" (* XXX escape string *)
    fun attr_str name v = oattr_str name (SOME v)

    fun attr_realpairs name rs =
        " " ^ name ^ "=\"" ^
        StringUtil.delimit "," (map (fn (r1, r2) => rtos r1 ^ "," ^ rtos r2) rs) ^ "\""

    fun matrix { x1, x2, y1, y2, angle } =
(*
        StringUtil.delimit " " (map rtos
                                [Math.cos angle,
                                 Math.sin angle,
                                 ~(Math.sin angle),
                                 Math.cos angle,
                                 y1 * Math.sin angle - x1 * Math.cos angle + x2,
                                 y2 - x1 * Math.sin angle - y1 * Math.cos angle])
*)
        let 
            val ca = Math.cos (angle * Math.pi / 180.0)
            val sa = Math.sin (angle * Math.pi / 180.0)
        in
            StringUtil.delimit " " (map rtos
                                    [ca, sa, ~sa, ca,
                                     ~x1 * ca + y1 * sa + x2,
                                     ~x1 * sa - y1 * ca + y2])
        end

    fun elem (Rect { x, y, width, height, stroke, fill, opacity }) =
              "<rect" ^ 
              attr_real "x" x ^
              attr_real "y" y ^
              attr_real "width" width ^
              attr_real "height" height ^
              oattr_str "stroke" stroke ^
              oattr_str "fill" fill ^
              oattr_real "opacity" opacity ^ "/>"
      | elem (Text { x, y, style, text, angle = NONE }) =
              "<text xml:space=\"preserve\"" ^
              attr_real "x" x ^
              attr_real "y" y ^
              oattr_str "style" style ^ ">" ^ text ^ "</text>" (* XXX escape text *)
      | elem (Text { x, y, style, text, angle = SOME a }) =
              "<text xml:space=\"preserve\" " ^
              "transform=\"matrix(" ^ matrix { x1 = 0.0, y1 = 0.0, x2 = x, y2 = y, angle = a } ^ ")\" " ^
              oattr_str "style" style ^ ">" ^ text ^ "</text>" (* XXX escape text *)
      | elem (Line { fill, stroke, strokewidth, opacity, points }) =
              "<polyline" ^
              attr_str "fill" fill ^
              attr_str "stroke" stroke ^
              oattr_real "opacity" opacity ^
              oattr_real "stroke-width" strokewidth ^
              attr_realpairs "points" points ^ "/>"

    fun header (x, y, w, h) =
       let in
          "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" ^
          "<!-- Generator: Simple SVG -->\n" ^
          "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" " ^
          "\"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\" [\n" ^
          "<!ENTITY ns_flows \"http://ns.adobe.com/Flows/1.0/\">\n" ^
          "]>\n" ^
          "<svg version=\"1.1\"\n" ^
          " xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n" ^
          " xmlns:a=\"http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/\"\n" ^
          " x=\"" ^ Int.toString x ^ "px\" y=\"" ^ Int.toString y ^ "px\"" ^
          " width=\"" ^ Int.toString w ^ "px\" height=\"" ^ Int.toString h ^ "px\"\n" ^
          " xml:space=\"preserve\">\n"
       end

    fun footer () = "</svg>\n"

    fun common wr WIDTH HEIGHT_PER_PT =
        let
            (* create n vertical ticks, song rating height, starting at x,y. *)
            fun song_ticks x y 0 = ()
              | song_ticks x y n =
                let
                in
                    wr (elem (Line { fill = "none",
                                     stroke = "#000000",
                                     opacity = SOME 0.2,
                                     strokewidth = SOME 0.75,
                                     points = [(x, y), (x, y + HEIGHT_PER_PT * 4.0)] }));
                    wr "\n";
                    song_ticks (x + WIDTH) y (n - 1)
                end

            fun song_names x y songs =
                ListUtil.appi 
                (fn (s, i) =>
                 let in
                     wr (elem (Text { x = x + (real i * WIDTH) + 3.0, y = ~6.0,
                                      style = SOME "font-size:12px;fill:#777777;font-family:Helvetica",
                                      angle = SOME (360.0 - 75.0),
                                      text = s }));
                     wr "\n"
                 end) songs

            fun plot_ticks x y topdata botdata topc botc fill =
                (* first, draw the filled region. *)
                let
                    val data = ListUtil.mapi (fn (r, i) => (x + real i * WIDTH, y + HEIGHT_PER_PT * (4.0 - (r - 1.0))))
                    val topdata = data topdata
                    val botdata = data botdata
                in
                    wr (elem (Line { fill = fill,
                                     opacity = SOME 0.15,
                                     stroke = "none",
                                     strokewidth = NONE,
                                     points = topdata @ rev botdata }));
                    wr "\n";
                    wr (elem (Line { fill = "none",
                                     opacity = NONE,
                                     stroke = topc,
                                     strokewidth = SOME 2.0,
                                     points = topdata }));
                    wr "\n";
                    wr (elem (Line { fill = "none",
                                     opacity = NONE,
                                     stroke = botc,
                                     strokewidth = SOME 2.0,
                                     points = botdata }));
                    wr "\n"
                end

        in
            { song_ticks = song_ticks,
              plot_ticks = plot_ticks,
              song_names = song_names
              }
        end

    (* OK, now it's time to make some graphs. First is easy: rate all songs in the order
       they appear throughout the projects. *)
    fun all_songs f =
        let
            val () = print ("Writing " ^ f ^ "\n")
            val f = TextIO.openOut f
            fun wr s = TextIO.output(f, s)
            val WIDTH = 16.0
            val HEIGHT_PER_PT = 75.0

            val { song_ticks, ... } = common wr WIDTH HEIGHT_PER_PT

            (* draw album boxes *)
            fun album_boxes x y ({ album : string * rating * rating, songs } :: rest) =
                let
                    val width = real (length songs - 1) * WIDTH
                    fun ratebox (_, score) fill stroke =
                        wr (elem (Rect { x = x, y = y + HEIGHT_PER_PT * (4.0 - (score - 1.0)),
                                         opacity = SOME 0.15, stroke = SOME stroke,
                                         fill = SOME fill, width = width,
                                         height = HEIGHT_PER_PT * (score - 1.0) }))

                    val (tx, ty, a) = if length songs <= 2
                                      then (x - (if length songs <= 1
                                                 then 6.0
                                                 else 0.0), y + HEIGHT_PER_PT * 4.0 + 20.0, 30.0)
                                      else (x + 2.0, y + HEIGHT_PER_PT * 4.0 + 20.0, 18.0)
                in
                    (* draw in the background the two rating boxes. *)
                    ratebox (#2 album) "#9334BF" "#4A006D";
                    ratebox (#3 album) "#006CD8" "#003B7C";
                    wr "\n";
                    wr (elem (Text { x = tx,
                                     y = ty,
                                     style = SOME "font-size:12px;fill:#777777;font-family:Helvetica",
                                     angle = SOME a,
                                     text = #1 album }));
                    wr "\n";
                    album_boxes (x + width + WIDTH) y rest
                end
              | album_boxes _ _ nil = ()

            fun song_plot x y pts =
                let
                    fun get _ f nil = nil
                      | get x f (r :: rest) =
                        (x, y + HEIGHT_PER_PT * (4.0 - (#2 (f r) - 1.0))) :: get (x + WIDTH) f rest
                in
                    wr (elem (Line { fill = "none",
                                     stroke = "#A600DD",
                                     opacity = NONE,
                                     strokewidth = SOME 2.0,
                                     points = get x #2 pts }));

                    wr (elem (Line { fill = "none",
                                     stroke = "#2242FF",
                                     opacity = NONE,
                                     strokewidth = SOME 2.0,
                                     points = get x #3 pts }))
                end

            val flat_songs = List.concat (map #songs pages)

        in
            wr (header (0, 0, 1000, 1000));
            song_ticks 0.0 0.0 (length flat_songs);
            album_boxes 0.0 0.0 pages;
            song_plot 0.0 0.0 flat_songs;
            wr (footer ());
            TextIO.closeOut f
        end

    (* Songs ranked by disparity. *)
    fun two_sides sort leftkeep rightkeep f =
        let
            val () = print ("Writing " ^ f ^ "\n")
            val f = TextIO.openOut f
            fun wr s = TextIO.output(f, s)
            val WIDTH = 16.0
            val HEIGHT_PER_PT = 75.0
            val MAX_SIDE = 30
            val SKIP_DOTDOTDOT = 100.0

            val { song_ticks, plot_ticks, song_names, ... } = common wr WIDTH HEIGHT_PER_PT

            (* We only care about songs for this one. *)
            val flat_songs = List.concat (map #songs pages)
            val flat_songs = map (fn (name, (_, l), (_, t)) => (name, l, t, t - l)) flat_songs

            (* And we sort by the difference in score (positive means tom liked it more) *)
            val flat_songs = ListUtil.sort sort flat_songs

            (* Okay, now we want to figure out a prefix to show on the left side of the graph, 
               and a suffix to show on the right. The only requirement is that there be at least
               one disagreement in each, and all on the left tom likes more, and all on the right
               tom likes less. (It is absolutely possible that this could not be satisfied, but
               unlikely for us...) *)
            fun chop f _ nil = nil
              | chop f 0 _ = nil
              | chop f n (a :: r) = 
                if f a
                then a :: chop f (n - 1) r
                else nil

            val tom_more = chop leftkeep MAX_SIDE (rev flat_songs)
            val tom_less = rev (chop rightkeep MAX_SIDE flat_songs)

            val () = print ("Tom liked " ^ Int.toString (length tom_more) ^ " songs more\n")
            val () = print ("Tom liked " ^ Int.toString (length tom_less) ^ " songs less\n")

            val lefthand = 0.0
            val righthand = WIDTH * real (length tom_more) + SKIP_DOTDOTDOT
        in
            wr (header (0, 0, 1000, 1000));

            song_ticks 0.0 0.0 (length tom_more);
            song_ticks (WIDTH * real (length tom_more) + SKIP_DOTDOTDOT) 0.0 (length tom_less);

            (* Draw the ... in the center *)
            wr (elem (Text { x = WIDTH * real (length tom_more) + (SKIP_DOTDOTDOT * 0.27),
                             y = HEIGHT_PER_PT * 3.75,
                             style = SOME "font-size:46px;fill:#777777;font-family:Helvetica",
                             angle = NONE,
                             text = "..." }));

            song_names lefthand 0.0 (map #1 tom_more);
            plot_ticks lefthand 0.0 (map #3 tom_more) (map #2 tom_more) "#2242FF" "#A600DD" "#1351CE";
                       
            song_names righthand 0.0 (map #1 tom_less);
            plot_ticks righthand 0.0 (map #2 tom_less) (map #3 tom_less) "#A600DD" "#2242FF" "#A139D8";

            wr (footer ());
            TextIO.closeOut f
        end

    val greatest_disparities = two_sides (fn ((_, l, t, d), (_, ll, tt, dd)) => 
                                          case Real.compare (d, dd) of
                                              EQUAL => Real.compare (l, ll)
                                            | ord => ord) (fn a => #4 a > 0.0) (fn a => #4 a < 0.0)
    val tom_favorites = two_sides (fn ((_, l, t, _), (_, ll, tt, _)) =>
                                   case Real.compare (t, tt) of
                                       EQUAL => Real.compare (l, ll)
                                     | ord => ord) (fn _ => true) (fn _ => true)
    val laura_favorites = two_sides (fn ((_, l, t, _), (_, ll, tt, _)) =>
                                     case Real.compare (l, ll) of
                                         EQUAL => Real.compare (t, tt)
                                       | ord => ord) (fn _ => true) (fn _ => true)

    val () = all_songs "allsongs.svg"
    val () = greatest_disparities "disparities.svg"
    val () = tom_favorites "tomfaves.svg"
    val () = laura_favorites "laurafaves.svg"

end
