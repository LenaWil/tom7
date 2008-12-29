
structure Render =
struct


    (* val [min, max] = map (valOf o Int.fromString) (CommandLine.arguments ()) *)
    val min = 1
    val max = 36

    val inputs = List.tabulate (max - min, fn i => 
                                ("b" ^ Int.toString (i + min),
                                 StringUtil.padex #"0" ~4 (Int.toString (i + min)) ^
                                 ".pgm"))

    fun onebrain (x, f) =
        let
            val r = Reader.fromfile f
            val { data, ... } = NetPBM.readpgm r
            val () = #close r ()
        in
            data
        end

    val brains = Vector.fromList (map onebrain inputs)
    val maxcolor = Vector.foldl (fn (s, c) => Array.foldl Int.max c s) 0 brains

    val () = Vector.app (Array.modify (fn a => 
                                       let val f = 255.0 * (Math.sqrt (real a / real maxcolor))
                                       in trunc f
                                       end)) brains


    open SDL
    val screen = makescreen (512, 512)

    type w8 = Word8.word
    val () = clearsurface (screen, color (0w0 : w8, 
                                          0w0 : w8,
                                          0w0 : w8,
                                          0w255 : w8))
    val () = flip screen

    fun drawpixel4 (s, x, y, c) =
        let in
            drawpixel (s, 2*x, 2*y, c);
            drawpixel (s, 2*x + 1, 2*y, c);
            drawpixel (s, 2*x + 1, 2*y + 1, c);
            drawpixel (s, 2*x, 2*y + 1, c)
        end

    fun drawpixel16 (s, x, y, c) =
        let in
            drawpixel4 (s, 2*x, 2*y, c);
            drawpixel4 (s, 2*x + 1, 2*y, c);
            drawpixel4 (s, 2*x + 1, 2*y + 1, c);
            drawpixel4 (s, 2*x, 2*y + 1, c)
        end

    fun drawslice s =
        Util.for 0 127
        (fn y =>
         Util.for 0 127
         (fn x =>
          let val c = Word8.fromInt (Array.sub(s, y * 128 + x))
          in drawpixel4 (screen, x, y, color (c, c, c, 0w127 : w8))
          end))


    exception Done
    fun loop () =
        let 
            fun check () =
                case pollevent () of
                    SOME E_Quit => raise Done
                  | SOME (E_KeyDown SDL_ESCAPE) => raise Done
                  | _ => ()
            fun one s = (check (); drawslice s)
        in
            Vector.app one brains;
            flip screen;
            Util.for 0 (Vector.length brains - 1)
              (fn z => one (Vector.sub(brains, (Vector.length brains - 1) - z)));
            flip screen;
            loop ()
        end

    val () = loop () handle Done => ()

end