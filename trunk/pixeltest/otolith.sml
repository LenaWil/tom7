
val () = print "Hello.\n";

exception Quit

val WIDTH = 320
val HEIGHT = 200

local
    (* If you get link errors about __imp, it's probably because you
       didn't import with "private" (or "public") visibility. It seems
       the default is now to expect a DLL to provide the symbol, which
       is what __imp is about. *)
    val init = _import "InitGame" private : unit -> unit ;
    val fillscreen = _import "FillScreenFrom" private : Word32.word Array.array -> unit ;
    val ctr = ref 0

    val pixels = Array.array(WIDTH * HEIGHT, 0wxFFAAAAAA : Word32.word)

    val rc = ARCFOUR.initstring "anything"

    local
        val orb = Word32.orb
        infix orb
    in
        fun mixcolor (r, g, b, a) =
            Word32.<< (a, 0w24) orb
            Word32.<< (b, 0w16) orb
            Word32.<< (g, 0w8) orb
            r
    end
in
    val _ = init ()
    val start = Time.now()
    fun keypress () =
        case SDL.pollevent () of
            NONE => ()
          | SOME SDL.E_Quit => raise Quit
          | SOME (SDL.E_KeyDown { sym = SDL.SDLK_ESCAPE }) => raise Quit
          | _ => ()

    fun randomize () =
        Util.for 0 (HEIGHT - 1)
        (fn y =>
         Util.for 0 (WIDTH - 1)
         (fn x =>
          let
              fun byte () = Word32.fromInt (Word8.toInt (ARCFOUR.byte rc))
              val r = byte ()
              val g = byte ()
              val b = byte ()
              val a = 0wxFF : Word32.word
              val color = mixcolor (r, g, b, a)
          in
              Array.update(pixels, y * WIDTH + x, color)
          end
          ))

    fun loop () =
        let
            val () = keypress ()

            val () = randomize ()
            val () = fillscreen pixels
            val () = ctr := !ctr + 1
        in
            if !ctr mod 1000 = 0
            then
                let
                    val now = Time.now ()
                    val sec = Time.toSeconds (Time.-(now, start))
                    val fps = real (!ctr) / Real.fromLargeInt (sec)
                in
                    print (Int.toString (!ctr) ^ " (" ^
                           Real.fmt (StringCvt.FIX (SOME 2)) fps ^ ")\n")
                end
            else ();
            loop()
        end

    val () = loop ()
end
