structure MidiDance =
struct

  (* The rate at which you intend to play the output frames back. *)
  val fps = Params.param "30"
      (SOME ("-frames", "Output FPS.")) "fps"

  (* I found this by putting the cursor on the beginning of the second
     measure, which told me was 2 seconds (tempo 120). 480 ticks
     transpire in a measure (I looked at the output of track
     printing), so 480/2 is the ticks per second. *)
  val tps = Params.param "240"
      (SOME ("-frames", "MIDI ticks per second.")) "tps"


  structure U = Util
  open SDL
  structure Util = U
  structure FU = FrameUtil
  structure WP = Waypoints

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

  exception MidiDance of string


  (* We only care about the starts of the notes in the track called DANCE.
     Just returns a list of integers. *)
  fun loadmidi mf =
    let
	val itos = Int.toString
	val r = (Reader.fromfile mf) handle _ => 
	    raise MidiDance ("couldn't read " ^ mf)
	val m as (ty, divi, thetracks) = MIDI.readmidi r
	val _ = ty = 1
	    orelse raise MidiDance ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
	val () = print ("MIDI division is " ^ itos divi ^ "\n")
	val _ = divi > 0
	    orelse raise MidiDance ("Division must be in PPQN form!\n")

	fun findname nil = NONE
	  | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
	  | findname (_ :: rest) = findname rest

	fun gettrack s tracks =
	    case List.filter (fn t => findname t = SOME s) tracks of
		[t] => SOME t
	      | _ => NONE

	fun maketicks t =
	    let 
		fun noteson extra ((delta, e) :: l) =
		    let val delta = delta + extra
		    in
			case e of
			    MIDI.NOTEON(_, note, 0) => noteson delta l
			  | MIDI.NOTEON(_, note, v) => delta :: noteson 0 l
			  | _ => noteson delta l
		    end
		  | noteson _ nil = nil
	    in
		noteson 0 t
	    end

    in
	case gettrack "DANCE" thetracks of
	    NONE => raise MidiDance "Couldn't find a track called DANCE."
	  | SOME t => 
		let 
		    val ticks = maketicks t
		in
		    print (mf ^ " contains " ^ Int.toString (length ticks) ^ " event(s).\n");
		    ticks
		end
    end

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  exception Done
  fun process_events () =
      let in
	  (case pollevent () of
	       NONE => ()
	     | SOME evt =>
		   case evt of
		       E_KeyDown { sym = SDLK_ESCAPE } => raise Done
		     | E_Quit => raise Done
		     | _ => ());
	  SDL.delay 1
      end

  fun start (midifile, wayfile) =
    let
      val track_in_ticks = loadmidi midifile
      val waypoints = WP.loadfile wayfile
      val cache = FrameCache.create_pattern
	  { max = 20,
	    prefix = WP.prefix waypoints,
	    padto = WP.padto waypoints,
	    first = WP.start waypoints,
	    suffix = WP.suffix waypoints }
      val WIDTH = FrameCache.width cache
      val HEIGHT = FrameCache.height cache
      val NUM = WP.num waypoints
      val screen = makescreen (WIDTH, HEIGHT)

      val () = print ("in ticks: " ^
		      StringUtil.delimit " " (map Int.toString track_in_ticks) ^
		      "\n")

      val tps = Params.asint 240 tps
      val () = print ("Ticks per second: " ^ Real.fmt (StringCvt.FIX (SOME 3)) (real tps) ^ "\n")
      val track_in_seconds : real list = 
	  map (fn delta => real delta / real tps) track_in_ticks

      val () = print ("in sec: " ^
		      StringUtil.delimit " " (map (Real.fmt (StringCvt.FIX (SOME 3))) 
					      track_in_seconds) ^
		      "\n")

      (* In frames, possibly fractional. *)
      val fps = Params.asint 30 fps
      val track : real list = 
	  map (fn delta => delta * real fps) track_in_seconds

      val () = print ("in frames: " ^
		      StringUtil.delimit " " (map (Real.fmt (StringCvt.FIX (SOME 3))) track) ^
		      "\n")

      local 
	  val n = ref 0
	  fun padname s n = s ^ (StringUtil.padex #"0" ~4 (Int.toString n)) ^ ".png"
      in
	  fun writeframe f msg =
	      let
		  val s = SDL.unpixels (WIDTH, HEIGHT, f)
		  val filename = padname "midi" (!n)
	      in
		  process_events ();
		  SDL.blitall (s, screen, 0, 0);
		  SDL.freesurface s;
		  Font.draw (screen, 0, 0, msg);
		  Font.draw (screen, 0, Font.height, "^3" ^ filename);
		  SDL.flip screen;

		  FU.saveframe (filename, WIDTH, HEIGHT, f);
		  n := !n + 1
	      end
      end

      (* extra represents time (in frames) we've already used up by output
	 frames. It's always in the interval [0, 1). This occurs when
	 the delta does not happen on a frame boundary. 

	 Think of the real time clock time at this moment being extra,
	 but if we were to just play back the frames, the last frame would
	 have happened at time (0 - extra).
	 

				 delta 5.1
	       v-------------------------------v
	                                       :
	       zero reference point for delta measurement
	       v                               : 
	       |     |     |     |     |     | :   |     |     |
		   ^                           :
		   extra 0.6                   :
	  ... +----++----++----++----++----++----+
	      |####||::::||::::||::::||::::||::::|
	      |####||::::||::::||::::||::::||::::|
	  ... +----++----++----++----++----++----+
		whole frames.                  ^-^
		### already output;            next_extra   = 0.5
		::: will be output during      (extra + frames) - delta
		this step.                       0.6      5        5.1
		                               |      |      |      |   ...

	                                ... +----+
					    |####|
					    |####|
					... +----+
		                               :
		                               ^-----------------^
		                                  next delta

	 *)
      fun loop (extra : real) (events : real list) (curframe : int) =
	  if extra < 0.0 orelse extra >= 1.0
	  then raise MidiDance ("In loop, extra out of bounds: " ^
				Real.fmt (StringCvt.FIX (SOME 3)) extra)
	  else
	  case events of
	      nil => () (* Done? *)
	    | delta :: rest =>
	      (* Too late, if this is the case. If nonzero, we could
		 maybe try to mix a fractional frame into the previous
		 or next one. The most common case is zero, like for
		 the very first event. *)
	      if delta < extra
	      then 
		  let in
		      if delta > 0.0
		      then eprint ("Delta was too small; had to skip: " ^
				   Real.fmt (StringCvt.FIX (SOME 3)) delta)
		      else eprint ("Delta 0.0\n");
		      (* XXX not clear if we should skip a waypoint. Depends
			 on what we're after: Synchronization of waypoints
			 with specific events, or smooth transitions between
			 them. curframe is the smooth choice: *)
		      loop (extra - delta) rest curframe
		  end
	      else
		let
		    val nextframe = WP.nextwaypoint waypoints curframe
                    (* Our job is to output delta frames. We can only
		       output an integer number of frames, so anything
		       left over goes into extra. Check out the diagram
		       above. *)

		    val (wholeframes, next_extra) =
			let
			    val wholeframes = Real.trunc (delta - extra)
			    val next_extra = real wholeframes + extra - delta
			in
			    if next_extra < 0.0
			    then (wholeframes + 1, next_extra + 1.0)
			    else (wholeframes, next_extra)
			end

		    val () = eprint
			("waypoints " ^ Int.toString curframe ^ "-" ^
			  Int.toString nextframe ^ " extra " ^
			  Real.fmt (StringCvt.FIX (SOME 3)) extra ^
			  " delta " ^
			  Real.fmt (StringCvt.FIX (SOME 3)) delta ^
			  " wholeframes " ^ Int.toString wholeframes ^
			  " next_extra " ^ 
			  Real.fmt (StringCvt.FIX (SOME 3)) next_extra ^ "\n")

		    val () = if next_extra < 0.0
			     then raise MidiDance ("bug: " ^ Real.toString next_extra)
			     else ()
		    val () = if next_extra >= 1.0
			     then raise MidiDance ("bug: " ^ Real.toString next_extra)
			     else ()

		    (* maps [0,1] to [0,1] for time warping. Input is
		       linear time, output is position on the interval
		       that we should see. *)
		    fun interpolate (t : real) =
			let val tp = t * Math.pi * 2.0
			in
			    (tp + Math.sin(tp - Math.pi)) / (2.0 * Math.pi)
			end

		    (* 0-based *)
		    fun outputframe (n : int) =
			let
			    (* the interal comprising wholeframes frames
			       maps to the [0,1] interval for interpolation. *)
			    val framewidth = 1.0 / real wholeframes
			    val t0 = real n * framewidth
			    val t1 = real (n + 1) * framewidth
			    val t0' = interpolate t0
			    val t1' = interpolate t1
			    val frames_in_region = real (nextframe - curframe)
			    val start_frame = real curframe + t0' * frames_in_region
			    val end_frame = real curframe + t1' * frames_in_region
			    val f = FU.sampleframerange (cache, start_frame, end_frame)
			in
			    writeframe f
			    ("waypoints ^2" ^ Int.toString curframe ^ "-" ^
			     Int.toString nextframe ^ "^< extra ^2" ^
			     Real.fmt (StringCvt.FIX (SOME 2)) extra ^ 
			     "^< delta ^2" ^ 
			     Real.fmt (StringCvt.FIX (SOME 2)) delta ^ 
			     "^< frame ^2" ^ Int.toString (n + 1) ^
			     "^< of ^2" ^ Int.toString wholeframes ^
			     "^< t0-t1: ^1" ^ 
			     Real.fmt (StringCvt.FIX (SOME 3)) t0 ^ 
			     "^<-^1" ^
			     Real.fmt (StringCvt.FIX (SOME 3)) t1 ^
			     "^< t0'-t1': ^4" ^
			     Real.fmt (StringCvt.FIX (SOME 3)) t0' ^ 
			     "^<-^4" ^
			     Real.fmt (StringCvt.FIX (SOME 3)) t1' ^
			     "^< frames ^3" ^
			     Real.fmt (StringCvt.FIX (SOME 3)) start_frame ^
			     "^<-^3" ^
			     Real.fmt (StringCvt.FIX (SOME 3)) end_frame)
			end

		    val () = Util.for 0 (wholeframes - 1) outputframe
		in
		    loop next_extra rest nextframe
		end
    in
      loop 0.0 track (WP.firstwaypoint waypoints)
    end

  val () = Params.main2 "MIDI file and waypoints." start
  handle e =>
      let in
          eprint ("unhandled exception " ^
                  exnName e ^ ": " ^
                  exnMessage e ^ ": ");
          (case e of
               FrameCache.FrameCache s => eprint ("cache: " ^ s)
             | FrameUtil.FrameUtil s => eprint ("frameutil: " ^ s)
	     | WP.Waypoints s => eprint ("waypoints: " ^ s)
	     | MidiDance s => eprint s
             | _ => eprint "unknown");
          eprint "\nhistory:\n";
          app (fn l => eprint ("  " ^ l ^ "\n")) (Port.exnhistory e);
          eprint "\n"
      end

end
