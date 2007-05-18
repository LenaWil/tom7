
(* FIXME Check that SDL_AUDIODRIVER is dsound otherwise this
   is unusable because of latency *)

structure Test =
struct
(*
  local
      val mb_ = _import "MessageBoxA" : MLton.Pointer.t * string * string * MLton.Pointer.t -> unit ;
  in
      fun message (s, t) = mb_(MLton.Pointer.null, s ^ "\000", t ^ "\000", MLton.Pointer.null)
  end
*)
  fun message _ = ()

  val () = message ("hello", "World")

  type ptr = MLton.Pointer.t

  exception Nope

  exception Test of string

  open SDL

  fun messagebox s = 
      let
        (* val mb = _import "MessageBoxA" stdcall : int * string * string * int -> unit ; *)
      in
        (* mb (0, s ^ "\000", "message", 0) *)
        print (s ^ "\n")
      end

  val width = 256
  val height = 600

  val ROBOTH = 32
  val ROBOTW = 16

  val screen = makescreen (width, height)

(*
  val _ = Util.for 0 (Joystick.number () - 1)
      (fn x => print ("JOY " ^ Int.toString x ^ ": " ^ Joystick.name x ^ "\n"))

  (* XXX requires joystick! *)
  val joy = Joystick.openjoy 0 
  val () = Joystick.setstate Joystick.ENABLE
*)

  val initaudio_ = _import "ml_initsound" : unit -> unit ;
  val () = initaudio_ ()

  val setfreq_ = _import "ml_setfreq" : int * int * int -> unit ;

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

  val redstar = requireimage "testgraphics/redstar.png"
  val STARWIDTH = surface_width redstar
  val STARHEIGHT = surface_height redstar
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
  fun pitchof n = Real.trunc ( 80.0 * Math.pow (2.0, real n / 12.0) )
  val pitches = Vector.fromList (List.tabulate(128, pitchof))
*)
(*
  val pitches = Vector.fromList 
  [8,8,8,9,10,10,11,11,12,13,14,15,16,16,17,19,20,21,22,23,25,26,28,30,32,33,
   35,38,40,42,45,47,50,53,57,60,63,67,71,76,80,85,90,95,101,107,114,120,127,
   135,143,152,161,170,181,191,203,215,228,241,256,271,287,304,322,341,362,
   383,406,430,456,483,511,542,574,608,645,683,724,767,812,861,912,966,1023,
   1084,1149,1217,1290,1366,1448,1534,1625,1722,1824,1933,2047,2169,2298,2435,
   2580,2733,2896,3068,3250,3444,3649,3866,4095,4339,4597,4870,5160,5467,5792,
   6137,6501,6888,7298,7732,8192,8679,9195,9741,10321,10935,11585,12274]
*)
  (* in tenths of a hertz *)
  val pitches = Vector.fromList
  [80,84,89,95,100,106,113,119,126,134,142,151,160,169,179,190,201,213,226,
   239,253,269,285,302,320,339,359,380,403,427,452,479,507,538,570,604,639,
   678,718,761,806,854,905,958,1015,1076,1140,1208,1279,1356,1436,1522,1612,
   1708,1810,1917,2031,2152,2280,2416,2560,2712,2873,3044,3225,3417,3620,3835,
   4063,4305,4561,4832,5119,5424,5747,6088,6450,6834,7240,7671,8127,8610,9122,
   9665,10239,10848,11494,12177,12901,13668,14481,15342,16254,17221,18245,
   19330,20479,21697,22988,24354,25803,27337,28963,30685,32509,34443,36491,
   38661,40959,43395,45976,48709,51606,54675,57926,61370,65019,68886,72982,
   77322,81920,86791,91952,97419,103212,109350,115852,122741]

  val transpose = ref 0
  fun pitchof n =
      let
          val n = n + ! transpose
          val n = if n < 0 then 0 else if n > 127 then 127 else n
      in
          Vector.sub(pitches, n)
      end

  val freqs = Array.array(16, 0)
  fun setfreq (ch, f, vol) =
      let in
(*
          print ("setfreq " ^ Int.toString ch ^ " = " ^
                 Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
*)
          print("setfreq " ^ Int.toString ch ^ " = " ^
                        Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
          setfreq_ (ch, f, vol);
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

  fun noteon (ch, n, v) =
      (case Array.sub(Array.sub(miditable, ch), n) of
           OFF => (* find channel... *)
               (case Array.findi (fn (_, b) => not b) mixes of
                    SOME (i, _) => 
                        let in
                            Array.update(mixes, i, true);
                            setfreq(i, pitchof n, v);
                            Array.update(Array.sub(miditable, ch),
                                         n,
                                         PLAYING i)
                        end
                  | NONE => print "No more mix channels.\n")
         (* re-use mix channel... *)
         | PLAYING i => setfreq(i, pitchof n, v)
                    )

  fun noteoff (ch, n) =
      (case Array.sub(Array.sub(miditable, ch), n) of
           OFF => (* already off *) ()
         | PLAYING i => 
               let in
                   Array.update(mixes, i, false);
                   setfreq(i, pitchof 60, 0);
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

  val () = app (fn l => print (itos (length l) ^ " events\n")) thetracks
(*
  val track1 = (* channelify 1 *) (List.nth (events, 1))
  val track2 = (* channelify 2 *) (List.nth (events, 2))
  val track3 = (* channelify 3 *) (List.nth (events, 3))
*)

  fun getticksi () = Word32.toInt (getticks ())

  (* how many ticks forward do we look? *)
  val MAXAHEAD = 1024

  (* XXX assuming ticks = midi delta times; wrong! 
     (even when slowed by factor of 4 below) *)
  val skip = ref 0
  val often = ref 0
  fun loop' (lt, nil, _) = print "SONG END.\n"
    | loop' (lt, tracks, clearme) =
      let
        val () = often := !often + 1

          (* maybe not so fast?? *)
          val clearme =
            if !often = 3
            then 
              let 
                val () = often := 0
                  fun draw _ nil = nil
                    | draw when ((dt, e) :: rest) = 
                      if when > MAXAHEAD
                      then nil
                      else (case e of
                                MIDI.NOTEON (_, note, 0) => draw (when + dt) rest
                              | MIDI.NOTEON (_, note, vel) => 
                                    let val finger = note mod 5
                                    in
                                    (finger * (STARWIDTH + 2),
                                     (height - 48) - ((when + dt) div 2)) :: 
                                    draw (when + dt) rest
                                    end
                              | MIDI.NOTEOFF (_, note, _)  => draw (when + dt) rest
                              | _ => draw (when + dt) rest
                                    )

                  val todraw = draw 0 (#2 (hd tracks)) (* XXX *)
              in
                  (* erase old events *)
                  app (fn (x, y) => blit(background, x + 8, y, STARWIDTH, STARHEIGHT,
                                         screen, x + 8, y)) clearme;
                  (* draw some upcoming events... *)
                  app (fn (x, y) => blitall(redstar, screen, x + 8, y)) todraw;
                  flip screen;
                  todraw
              end
           else clearme

          val period = (getticksi () + !skip) - lt

          fun doready (tr, (n, evt) :: rest) =
              let val nn = n - period
              in
                  (* easy to drift because we're lte... *)
                  if nn <= 0 
                  then
                      let in
                          (case evt of
                               MIDI.NOTEON(ch, note, 0) => noteoff (ch, note)
                             | MIDI.NOTEON(ch, note, vel) => noteon (ch, note, 12000) 
                             | MIDI.NOTEOFF(ch, note, _) => noteoff (ch, note)
                             | _ => print "unknown event\n");
                          (tr, rest)
                      end
                  else (tr, (nn, evt) :: rest)
              end
            | doready (tr, nil) = (tr, nil)

          (* only keep tracks with events left... *)
          (* PERF could use mappartial *)
          val tracks = List.filter (fn (t, _ :: _) => true | _ => false) (map doready tracks)
      in
          loop (lt + period, tracks, clearme)
      end

  and loop x =
      let in
          (case pollevent () of
               SOME (E_KeyDown { sym = SDLK_ESCAPE }) => raise Test "EXIT"
             | SOME E_Quit => raise Test "EXIT"
             | SOME (E_KeyDown { sym = SDLK_i }) => skip := !skip + 2000
             | SOME (E_KeyDown { sym = SDLK_o }) => transpose := !transpose - 1
             | SOME (E_KeyDown { sym = SDLK_p }) => transpose := !transpose + 1
             | _ => ()
               );
          loop' x
      end

  fun slow l = map (fn (delta, e) => (delta * 6, e)) l

(*              
  and key ( cur as { nexttick, intention = i } ) = 
    case pollevent () of
      SOME (E_KeyDown { sym = SDLK_ESCAPE }) => () (* quit *)

    | SOME (E_MouseMotion { xrel, yrel, ...}) =>
        let in 
          botdx := !botdx + xrel; botdy := !botdy + yrel;
          botdx := (if !botdx > 4 then 4
                   else (if !botdx < ~4 then ~4
                         else !botdx));
          botdy := (if !botdy > 4 then 4
                    else (if !botdy < ~4 then ~4
                          else !botdy));
          loop cur
        end

    | SOME (E_KeyDown { sym = SDLK_RETURN }) =>
        let in
          paused := not (!paused);
          loop cur
        end

    | SOME (E_KeyDown { sym = SDLK_PERIOD }) => 
        let in
          advance := true;
          loop cur
        end

    | SOME (E_KeyDown { sym = SDLK_q }) =>
        (setfreq 256;
         loop cur)

    | SOME (E_KeyDown { sym = SDLK_w }) =>
        (setfreq 400;
         loop cur)

    | SOME (E_KeyDown { sym = SDLK_e }) =>
        (setfreq 512;
         loop cur)


    | SOME (E_KeyDown { sym = SDLK_i }) =>
        (scrolly := !scrolly - 3;
         loop cur)
    | SOME (E_KeyDown { sym = SDLK_j }) =>
        (scrollx := !scrollx - 3;
         loop cur)
    | SOME (E_KeyDown { sym = SDLK_k }) =>
        (scrolly := !scrolly + 3;
         loop cur)
    | SOME (E_KeyDown { sym = SDLK_l }) =>
        (scrollx := !scrollx + 3;
         loop cur)

(*
    | SOME (E_KeyDown { sym = SDLK_b }) => 
        loop { nexttick = nexttick, intention = I_BOOST :: i }
*)

    | SOME (E_KeyDown { sym = SDLK_LEFT }) =>
        (setfreq (!freq - 50);
         loop cur)

    | SOME (E_KeyDown { sym = SDLK_RIGHT }) =>
        (setfreq (!freq + 30);
         loop cur)

    | SOME (E_KeyDown { sym }) =>
          let in
              print ("unknown key " ^ SDL.sdlktos sym ^ "\n");
              loop { nexttick = nexttick, intention = i }
          end

    | SOME E_Quit => ()
    | _ => loop cur
*)

  val tracks = slow (MIDI.merge thetracks)

  val () = loop (getticksi (), [(0, tracks)], nil)
    handle Test s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
