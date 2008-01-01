
(* FIXME Check that SDL_AUDIODRIVER is dsound otherwise this
   is unusable because of latency *)

structure Test =
struct

  fun messagebox _ = ()

  (* Comment this out on Linux, or it will not link *)
  local
      val mb_ = _import "MessageBoxA" : MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
  in
      fun messagebox s = mb_(MLton.Pointer.null, s ^ "\000", "Message!\000", MLton.Pointer.null)
  end

  type ptr = MLton.Pointer.t

  exception Nope

  exception Test of string
  exception Exit

  open SDL

  val width = 256
  val height = 600

  val ROBOTH = 32
  val ROBOTW = 16

  val screen = makescreen (width, height)

  (* XXX these should describe what kind of track it is *)
  datatype label =
      Music of int

  (* XXX assumes joystick 0 *)
(*
  val _ = Util.for 0 (Joystick.number () - 1)
      (fn x => messagebox ("JOY " ^ Int.toString x ^ ": " ^ Joystick.name x ^ "\n"))
*)

  (* XXX requires joystick! *)
  val joy = Joystick.openjoy 0 
  val () = Joystick.setstate Joystick.ENABLE

  val initaudio_ = _import "ml_initsound" : unit -> unit ;
  val setfreq_ = _import "ml_setfreq" : int * int * int * int -> unit ;
  val () = initaudio_ ()

  fun requireimage s =
    case Image.load s of
      NONE => (print ("couldn't open " ^ s ^ "\n");
               raise Nope)
    | SOME p => p

  val robotr = requireimage "testgraphics/robot.png"
  val robotl = requireimage "testgraphics/robotl.png" (* XXX should be able to flip graphics *)
  val robotr_fade = alphadim robotr
  val robotl_fade = alphadim robotl
  val solid = requireimage "testgraphics/solid.png"

  val background = requireimage "testgraphics/background.png"

  val stars = Vector.fromList
      [requireimage "testgraphics/greenstar.png",
       requireimage "testgraphics/redstar.png",
       requireimage "testgraphics/yellowstar.png",
       requireimage "testgraphics/bluestar.png",
       requireimage "testgraphics/orangestar.png"]
       
  val STARWIDTH = surface_width (Vector.sub(stars, 0))
  val STARHEIGHT = surface_height (Vector.sub(stars, 0))
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val blackfade = requireimage "testgraphics/blackfade.png"
  val robobox = requireimage "testgraphics/robobox.png"
  val blackall = alphadim blackfade
  val () = clearsurface(blackall, color (0w0, 0w0, 0w0, 0w255))

  val () = blitall(background, screen, 0, 0)

  datatype dir = UP | DOWN | LEFT | RIGHT
  datatype facing = FLEFT | FRIGHT

  val botx = ref 50
  val boty = ref 50
  val botface = ref FRIGHT
  (* position of top-left of scroll window *)
  val scrollx = ref 0
  val scrolly = ref 0
  (* (* in sixteenths of a pixel per frame *) *)
  val botdx = ref 0
  val botdy = ref 0

  val paused = ref false
  val advance = ref false

  (* note 60 is middle C = 256hz,
     so 0th note is 8hz.
     *)
(* XXX no floats on mingw, urgh
  fun pitchof n = Real.trunc ( 800.0 * Math.pow (2.0, real n / 12.0) )
  val pitches = Vector.fromList (List.tabulate(128, pitchof))
*)

  (* in hundredths of a hertz *)
  val pitches = Vector.fromList
  [800,847,897,951,1007,1067,1131,1198,1269,1345,1425,1510,1600,1695,1795,
   1902,2015,2135,2262,2397,2539,2690,2850,3020,3200,3390,3591,3805,4031,4271,
   4525,4794,5079,5381,5701,6040,6399,6780,7183,7610,8063,8542,9050,9589,
   10159,10763,11403,12081,12799,13561,14367,15221,16126,17085,18101,19178,
   20318,21526,22807,24163,25600,27122,28735,30443,32253,34171,36203,38356,
   40637,43053,45614,48326,51199,54244,57470,60887,64507,68343,72407,76713,
   81274,86107,91228,96652,102399,108489,114940,121774,129015,136687,144815,
   153426,162549,172215,182456,193305,204799,216978,229880,243549,258031,
   273375,289630,306853,325099,344431,364912,386610,409599,433956,459760,
   487099,516063,546750,579261,613706,650199,688862,729824,773221,819200,
   867912,919520,974198,1032127,1093500,1158523,1227413]

  val transpose = ref 5 (* XXX? *)
  fun pitchof n =
      let
          val n = n + ! transpose
          val n = if n < 0 then 0 else if n > 127 then 127 else n
      in
          Vector.sub(pitches, n)
      end

  (* must agree with sound.c *)
  val INST_NONE   = 0
  val INST_SQUARE = 1
  val INST_SAW    = 2
  val INST_NOISE  = 3

  val freqs = Array.array(16, 0)
  fun setfreq (ch, f, vol, inst) =
      let in
(*
          print ("setfreq " ^ Int.toString ch ^ " = " ^
                 Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
*)
          print("setfreq " ^ Int.toString ch ^ " = " ^
                        Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
          setfreq_ (ch, f, vol, inst);
          (* "erase" old *)
          blitall (blackfade, screen, Array.sub(freqs, ch), 16 * (ch + 1));
          (* draw new *)
          (if vol > 0 then blitall (solid, screen, f, 16 * (ch + 1))
           else ());
          Array.update(freqs, ch, f);
          flip screen
      end



  datatype status = 
      OFF
    | PLAYING of int
  (* for each channel, all possible midi notes *)
  val miditable = Array.array(16, Array.array(127, OFF))
  val NMIX = 12 (* XXX get from C code *)
  val mixes = Array.array(NMIX, false)

  fun noteon (ch, n, v, inst) =
      (case Array.sub(Array.sub(miditable, ch), n) of
           OFF => (* find channel... *)
               (case Array.findi (fn (_, b) => not b) mixes of
                    SOME (i, _) => 
                        let in
                            Array.update(mixes, i, true);
                            setfreq(i, pitchof n, v, inst);
                            Array.update(Array.sub(miditable, ch),
                                         n,
                                         PLAYING i)
                        end
                  | NONE => print "No more mix channels.\n")
         (* re-use mix channel... *)
         | PLAYING i => setfreq(i, pitchof n, v, inst)
                    )

  fun noteoff (ch, n) =
      (case Array.sub(Array.sub(miditable, ch), n) of
           OFF => (* already off *) ()
         | PLAYING i => 
               let in
                   Array.update(mixes, i, false);
                   setfreq(i, pitchof 60, 0, INST_NONE);
                   Array.update(Array.sub(miditable, ch),
                                n,
                                OFF)
               end)
      

  (* FIXME totally ad hoc!! *)
  val itos = Int.toString
  val f = (case CommandLine.arguments() of 
               [st] => st
             | _ => "totally-membrane.mid")
  val r = (Reader.fromfile f) handle _ => 
      raise Test ("couldn't read " ^ f)
  val m as (ty, divi, thetracks) = MIDI.readmidi r
  val _ = ty = 1
      orelse raise Test ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")

  (* val () = app (fn l => print (itos (length l) ^ " events\n")) thetracks *)

  fun getticksi () = Word32.toInt (getticks ())

  (* how many ticks forward do we look? *)
  val MAXAHEAD = 1024

  (* For 360 X-Plorer guitar, which strangely swaps yellow and blue keys *)
  fun joymap 0 = 0
    | joymap 1 = 1
    | joymap 3 = 2
    | joymap 2 = 3
    | joymap 4 = 4
    | joymap _ = 999 (* XXX *)

  fun fingeron f =
      let val x = 8 + 6 + f * (STARWIDTH + 18)
          val y = height - 42
      in
          if f >= 0 andalso f <= 4
          then blitall(Vector.sub(stars, f),
                       screen, x, y)
          else ()
      end

  fun fingeroff f =
      let val x = 8 + 6 + f * (STARWIDTH + 18)
          val y = height - 42
      in
          if f >= 0 andalso f <= 4
          then blit(background, x, y, STARWIDTH, STARHEIGHT,
                    screen, x, y)
          else ()
      end

  (* XXX assuming ticks = midi delta times; wrong! 
     (even when slowed by factor of 4 below) *)
  val skip = ref 0
  val often = ref 0
  fun loop' (lt, nil, _) = print "SONG END.\n"
    | loop' (lt, track as ( (n, (label, evt)) :: trackrest ), clearme) =
      let
        val () = often := !often + 1

        (* maybe not so fast?? *)
        val clearme =
          if !often = 3
          then 
            let 
              val () = often := 0
                fun draw _ nil = nil
                  | draw when ((dt, (label, e)) :: rest) = 
                    if when > MAXAHEAD
                    then nil
                    else 
                        (case label of
                             Music inst => (* XXX should do for score tracks, not music tracks *)
                                 (* but for now don't show drum tracks, at least *)
                                 if inst = INST_SAW (* <> INST_NOISE *)
                                 then
                                     (case e of
                                          MIDI.NOTEON (_, note, 0) => draw (when + dt) rest
                                        | MIDI.NOTEON (_, note, vel) => 
                                              let val finger = note mod 5
                                              in
                                                  (finger,
                                                   (* XXX fudge city *)
                                                   6 + finger * (STARWIDTH + 18),
                                                   (height - 48) - ((when + dt) div 2)) :: 
                                                  draw (when + dt) rest
                                              end
                                        | MIDI.NOTEOFF (_, note, _)  => draw (when + dt) rest
                                        | _ => draw (when + dt) rest)
                                 else draw (when + dt) rest
                           (* otherwise... ? *)
                                      )

                val todraw = draw 0 track
              in
                  (* erase old events *)
                  app (fn (_, x, y) => blit(background, x + 8, y, STARWIDTH, STARHEIGHT,
                                            screen, x + 8, y)) clearme;
                  (* draw some upcoming events... *)
                  app (fn (f, x, y) => blitall(Vector.sub(stars, f), 
                                               screen, x + 8, y)) todraw;
                  flip screen;
                  todraw
              end
            else clearme

          val period = (getticksi () + !skip) - lt

          val nn = n - period

          val track = 
              (* easy to drift because we're lte... *)
              if nn <= 0 
              then
                  let in
                      (case label of
                           Music inst =>
                               (case evt of
                                    MIDI.NOTEON(ch, note, 0) => noteoff (ch, note)
                                  | MIDI.NOTEON(ch, note, vel) => noteon (ch, note, 12000, inst) 
                                  | MIDI.NOTEOFF(ch, note, _) => noteoff (ch, note)
                                  | _ => print "unknown event\n")
                          (* otherwise no sound..? *) 
                               );
                      trackrest
                  end
              else ((nn, (label, evt)) :: trackrest)
      in
          loop (lt + period, track, clearme)
      end

  and loop x =
      let in
          (case pollevent () of
               SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Exit
             | SOME E_Quit => raise Exit
             | SOME (E_KeyDown { sym = SDLK_i }) => skip := !skip + 2000
             | SOME (E_KeyDown { sym = SDLK_o }) => transpose := !transpose - 1
             | SOME (E_KeyDown { sym = SDLK_p }) => transpose := !transpose + 1
             (* Assume joystic events are coming from the one joystick we enabled
                (until we have multiplayer... ;)) *)
             | SOME (E_JoyDown { button, ... }) => fingeron (joymap button)
             | SOME (E_JoyUp { button, ... }) => fingeroff (joymap button)
             | _ => ()
               );
          loop' x
      end

  (* fun slow l = map (fn (delta, e) => (delta * 6, e)) l *)
  fun slow l = map (fn (delta, e) => (delta * 3, e)) l

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  (* Label all of the tracks
     This uses the track's name to determine its label. *)
  fun label tracks =
      let
          fun onetrack tr =
              case findname tr of
                  NONE => (print "Discarded track with no name.\n"; NONE)
                | SOME "" => (print "Discarded track with empty name.\n"; NONE)
                | SOME name => 
                      (case CharVector.sub(name, 0) of
                           #"+" =>
                           SOME (case CharVector.sub (name, 1) of
                                     #"Q" => Music INST_SQUARE
                                   | #"W" => Music INST_SAW
                                   | #"N" => Music INST_NOISE
                                   | _ => (print "?? expected Q or W or N\n"; raise Test ""),
                                 tr)
                         | _ => (print "?? expected + or ...\n"; raise Test ""))
      in
          List.mapPartial onetrack tracks
      end
      
  val tracks = label thetracks
  val tracks = slow (MIDI.mergea tracks)

  val () = loop (getticksi (), tracks, nil)
    handle Test s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | Exit => ()
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
