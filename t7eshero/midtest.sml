
(* FIXME Check that SDL_AUDIODRIVER is dsound otherwise this
   is unusable because of latency *)

structure Test =
struct

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

  val width = 640
  val height = 480

  val TILESW = width div 16
  val TILESH = height div 16

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

  val freq = ref 256
  val vol  = ref 32000
  val setfreq_ = _import "ml_setfreq" : int * int -> unit ;

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

  val redhi = requireimage "testgraphics/redhighlight.png"
  val greenhi = requireimage "testgraphics/greenhighlight.png"
  val robobox = requireimage "testgraphics/robobox.png"

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

  fun setfreq (n, v) =
      let in
          print ("setfreq " ^ Int.toString n ^ "\n");
          freq := n;
          vol := v;
          setfreq_ (n, v);
          (* PERF *)
          clearsurface (screen, color (0w0, 0w0, 0w0, 0w0));
          blitall (robotl, screen, n, 32);
          flip screen
      end

  (* FIXME totally ad hoc!! *)
  val itos = Int.toString
  val f = "totally-membrane.mid"
  val r = (Reader.fromfile f) handle _ => 
      raise Test ("couldn't read " ^ f)
  val m as (ty, divi, events) = MIDI.readmidi r
  val _ = ty = 1
      orelse raise Test ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")

  val () = app (fn l => print (itos (length l) ^ " events\n")) events
  val track = List.nth (events, 2)

  fun getticksi () = Word32.toInt (getticks ())

  (* note 60 is middle C = 256hz,
     so 0th note is 8hz.
     *)
(* XXX no floats on mingw, urgh
  fun pitchof n = Real.trunc ( 8.0 * Math.pow (2.0, real n / 12.0) )
*)
  val pitches = Vector.fromList 
  [8,8,8,9,10,10,11,11,12,13,14,15,16,16,17,19,20,21,22,23,25,26,28,30,32,33,
   35,38,40,42,45,47,50,53,57,60,63,67,71,76,80,85,90,95,101,107,114,120,127,
   135,143,152,161,170,181,191,203,215,228,241,256,271,287,304,322,341,362,
   383,406,430,456,483,511,542,574,608,645,683,724,767,812,861,912,966,1023,
   1084,1149,1217,1290,1366,1448,1534,1625,1722,1824,1933,2047,2169,2298,2435,
   2580,2733,2896,3068,3250,3444,3649,3866,4095,4339,4597,4870,5160,5467,5792,
   6137,6501,6888,7298,7732,8192,8679,9195,9741,10321,10935,11585,12274]

  fun pitchof n = Vector.sub(pitches, n)

  (* XXX assuming ticks = midi delta times; wrong! *)
  fun loop (lt, nil) = print "SONG END.\n"
    | loop (lt, (0, evt) :: rest) =
      (* do it now! *)
      let in
          (case evt of
               MIDI.NOTEON(_, note, 0) => setfreq (note, 0)
             | MIDI.NOTEON(_, note, vel) => setfreq (pitchof note, 32000)
             | MIDI.NOTEOFF _ => (setfreq (pitchof 60, 0))
             | _ => print "unknown event\n");
          
          loop (lt, rest)
      end
    | loop (lt, (n, evt) :: rest) =
           let val period = getticksi () - lt
               val nd = n - period
           in
               delay 0;
               loop (lt + period, 
                     (if nd < 0 then 0 else nd, evt) :: rest)

           end

  fun slow l = map (fn (delta, e) => (delta * 4, e)) l

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

  val () = loop (getticksi (), slow track)
    handle Test s => messagebox ("exn test: " ^ s)
        | SDL s => messagebox ("sdl error: " ^ s)
        | e => messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e)

end
