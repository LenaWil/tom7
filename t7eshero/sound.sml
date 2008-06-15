(* Low-level sound stuff for T7eshero. *)
structure Sound :> SOUND =
struct

  val initaudio_ = _import "ml_initsound" : unit -> unit ;
  val setfreq_ = _import "ml_setfreq" : int * int * int * int -> unit ;
  val () = initaudio_ ()

(* note 60 is middle C = 256hz,
   so 0th note is 8hz. *)

(* XXX no floats on mingw, urgh
  val () = Control.Print.printLength := 10000
  fun pitchof n = Real.round ( 80000.0 * Math.pow (2.0, real n / 12.0) )
  val pitches = Vector.fromList (List.tabulate(128, pitchof))
*)

  (* in ten thousandths of a hertz *)
  val PITCHFACTOR = 10000
  val pitches = Vector.fromList
  [80000,84757,89797,95137,100794,106787,113137,119865,126992,134543,142544,
   151020,160000,169514,179594,190273,201587,213574,226274,239729,253984,
   269087,285088,302040,320000,339028,359188,380546,403175,427149,452548,
   479458,507968,538174,570175,604080,640000,678056,718376,761093,806349,
   854298,905097,958917,1015937,1076347,1140350,1208159,1280000,1356113,
   1436751,1522185,1612699,1708595,1810193,1917833,2031873,2152695,2280701,
   2416318,2560000,2712226,2873503,3044370,3225398,3417190,3620387,3835666,
   4063747,4305390,4561401,4832636,5120000,5424451,5747006,6088740,6450796,
   6834380,7240773,7671332,8127493,8610779,9122803,9665273,10240000,10848902,
   11494011,12177481,12901592,13668760,14481547,15342664,16254987,17221559,
   18245606,19330546,20480000,21697804,22988023,24354962,25803183,27337520,
   28963094,30685329,32509974,34443117,36491211,38661092,40960000,43395608,
   45976045,48709923,51606366,54675040,57926188,61370658,65019947,68886234,
   72982423,77322184,81920000,86791217,91952091,97419847,103212732,109350081,
   115852375,122741316]

  val transpose = ref 0 (* XXX? *)

  fun pitchof n =
      let
          val n = n + ! transpose
          val n = if n < 0 then 0 else if n > 127 then 127 else n
      in
          Vector.sub(pitches, n)
      end

  type inst = int
  (* must agree with sound.c *)
  val INST_NONE   = 0
  val INST_SQUARE = 1
  val INST_SAW    = 2
  val INST_NOISE  = 3
  val INST_SINE   = 4

  val freqs = Array.array(16, 0)
  fun setfreq (ch, f, vol, inst) = setfreq_ (ch, f, vol, inst)
(*
      let in
(*
          print ("setfreq " ^ Int.toString ch ^ " = " ^
                 Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
*)
(*
          print("setfreq " ^ Int.toString ch ^ " = " ^
                        Int.toString f ^ " @ " ^ Int.toString vol ^ "\n");
*)
          setfreq_ (ch, f, vol, inst);
          (* "erase" old *)
          blitall (blackfade, screen, Array.sub(freqs, ch), 16 * (ch + 1));
          (* draw new *)
          (if vol > 0 then blitall (solid, screen, f, 16 * (ch + 1))
           else ());
          Array.update(freqs, ch, f);
          flip screen
      end
*)

  datatype status = 
      OFF
    | PLAYING of int
  (* for each channel, all possible midi notes *)
  val miditable = Vector.tabulate(16, fn _ => Array.array(128, OFF))
  val NMIX = 12 (* XXX get from C code *)
  val MISSCH = NMIX - 1
  (* save one for the miss noise channel *)
  val mixes = Array.array(NMIX - 1, false)

  fun debug () =
      Util.for 0 15
      (fn ch =>
       let val a = Vector.sub(miditable, ch)
       in
           print ("ch " ^ Int.toString ch ^ ": ");
           Util.for 0 127
           (fn n =>
            case Array.sub(a, n) of
                OFF => ()
              | PLAYING i => print (" " ^ Int.toString n ^ "=" ^ Int.toString i));
           print "\n"
       end)

  fun noteon (ch, n, v, inst) =
      let in
          (* print ("(noteon " ^ Int.toString ch ^ " " ^ Int.toString n ^ "@" ^
                 Int.toString v ^ ")\n"); *)
          (case Array.sub(Vector.sub(miditable, ch), n) of
               OFF => (* find channel... *)
                   (case Array.findi (fn (_, b) => not b) mixes of
                        SOME (i, _) => 
                            let in
                                Array.update(mixes, i, true);
                                setfreq(i, pitchof n, v, inst);
                                Array.update(Vector.sub(miditable, ch),
                                             n,
                                             PLAYING i);
                            (* debug () *) ()
                            end
                      | NONE => print "No more mix channels.\n")
             (* re-use mix channel... *)
             | PLAYING i => setfreq(i, pitchof n, v, inst))
      end

  fun noteoff (ch, n) =
      let in
          (* print ("(noteoff " ^ Int.toString ch ^ " " ^ Int.toString n ^ ")"); *)
          (case Array.sub(Vector.sub(miditable, ch), n) of
               OFF => (* already off *) ()
             | PLAYING i => 
                   let in
                       Array.update(mixes, i, false);
                       setfreq(i, pitchof 60, 0, INST_NONE);
                       Array.update(Vector.sub(miditable, ch),
                                    n,
                                    OFF);
                   (* debug () *) ()
                   end)
      end

  fun all_off () =
      let in
          (* turn off MIDI notes *)
          Vector.app (Array.modify (fn n => OFF)) miditable;
          (* turn off actual sound *)
          Array.appi (fn (i, _) => setfreq(i, pitchof 60, 0, INST_NONE)) freqs;
          (* mix channel in-use masks *)
          Array.modify (fn _ => false) mixes
      end
      
end
