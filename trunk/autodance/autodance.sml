structure BDDTest =
struct

  val output = Params.param ""
      (SOME ("-output", "Set output for PNG series.")) "output"

  val frames = Params.param "0"
      (SOME ("-frames", "Write this many iterations to PNG series, " ^
             "then stop.")) "frames"

  structure U = Util
  open SDL
  structure Util = U
  structure FU = FrameUtil

(*
  structure Font = FontFn
  (val surf = Images.requireimage "font.png"
   val charmap =
       " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ^
       "`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" (* " *)
   val width = 9
   val height = 16
   val styles = 6
   val overlap = 1
   val dims = 3)
*)

  fun padname s n = s ^ (StringUtil.padex #"0" ~4 (Int.toString n)) ^ ".png"

  fun loop () =
      let
          val START = 158
          val END = 846
          val NUM = END - START
          val cache = FrameCache.create_pattern
              { max = 20,
                prefix =
                "z:\\temp\\test-dance\\dancey",
                padto = 4,
                first = START,
                suffix = ".jpeg" }

          val WIDTH = FrameCache.width cache
          val HEIGHT = FrameCache.height cache

          val FPS = 24
          val SECONDS = 3

          val TPF = 1.0 / real (FPS * SECONDS)
          fun makeframe n =
              let
                  (* linear. *)
                  val t = real n / real (FPS * SECONDS)

                  val frame = FU.sampleinterval (cache, NUM, t, t + TPF)
              in
                  FU.saveframe (padname "out" n, WIDTH, HEIGHT, frame)
              end
      in
          Util.for 0 (FPS * SECONDS) makeframe
      end

  (* XXX HERE *)

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  val () = Params.main0 "No arguments." loop
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               FrameCache.FrameCache s => eprint ("cache: " ^ s)
             | FrameUtil.FrameUtil s => eprint ("frameutil: " ^ s)
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end

end

