(* Low-level sound stuff for T7eshero. *)
structure Sound :> SOUND =
struct

  exception Sound of string

  val initaudio_ = _import "ml_initsound" private : unit -> unit ;
  val setfreq_ = _import "ml_setfreq" private : int * int * int * int -> unit ;
  val () = initaudio_ ()

  local
    val sampleroffset_ =
      _import "ml_sampleroffset" private : unit -> int ;
    val total_mix_channels_ =
      _import "ml_total_mix_channels" private : unit -> int ;
  in
    val NMIX = total_mix_channels_ ()
    val SAMPLER_OFFSET = sampleroffset_ ()
  end

  (* note 60 is middle C = 256hz,
     so 0th note is 8hz. *)

  (* XXX no floats on mingw, urgh
     val () = Control.Print.printLength := 10000
     fun pitchof n = Real.round ( 80000.0 * Math.pow (2.0, real n / 12.0) )
     val pitches = Vector.fromList (List.tabulate(128, pitchof))
   *)

  type volume = int
  fun midivel m = m * 90

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
  type waveform = int

  (* must agree with sound.c *)
  val INST_NONE   = 0
  val INST_SQUARE = 1
  val INST_SAW    = 2
  val INST_NOISE  = 3
  val INST_SINE   = 4
  val INST_RHODES = 5
  fun INST_SAMPLER s = SAMPLER_OFFSET + s

  val WAVE_NONE   = INST_NONE
  val WAVE_SQUARE = INST_SQUARE
  val WAVE_SAW    = INST_SAW
  val WAVE_NOISE  = INST_NOISE
  val WAVE_SINE   = INST_SINE
  val WAVE_RHODES = INST_RHODES
  val WAVE_SAMPLER = INST_SAMPLER

  (* FIXME implement! (appears to be implmented?? -tom7) *)
  type sample = int
  type sampleset = int
  local
    val register_sample_ =
      _import "ml_register_sample" private : int vector * int -> int ;
    val register_sampleset_ =
      _import "ml_register_sampleset" private : int vector * int -> int ;
    fun save r e = (r := e; e)
  in
    val last_sample = ref 0
    val last_sampleset = ref 0
    (* XXX should check whether there is space or not. C code aborts if
         these get too high, but better to raise an exception. *)
    fun register_sample v =
      save last_sample (register_sample_ (v, Vector.length v))
    fun register_sampleset v =
      save last_sampleset (register_sampleset_ (v, Vector.length v))
    val silence : sample = 0 (* C registers this for us. *)
  end

  val freqs = Array.array(16, 0)
  fun setfreq (ch, f, vol, inst) =
    let in
      if inst >= SAMPLER_OFFSET
      then if f >= 128 orelse f < 0
           then raise Sound "Sampler should get sample index, not hz, as freq"
           else ()
      else ();
        setfreq_ (ch, f, vol, inst)
    end
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

  val NFREECH = NMIX - 1 - 5
  fun DRUMCH n = if n < 0 orelse n > 4
                 then raise Sound "there are only drum channels 0-5."
                 else NMIX - 1 - (n + 1)
  val MISSCH = NMIX - 1
  (* save one for the miss noise channel *)
  val mixes = Array.array(NFREECH, false)

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
            | PLAYING i => print (" " ^ Int.toString n ^ "=" ^
                                  Int.toString i));
         print "\n"
     end)

  fun noteon (ch, n, v, inst) =
    let in
        (*
        print ("(noteon " ^ Int.toString ch ^ " " ^ Int.toString n ^ "@" ^
               Int.toString v ^ ")\n");
        *)
        (case Array.sub(Vector.sub(miditable, ch), n) of
             OFF => (* find channel... *)
                 (case Array.findi (fn (_, b) => not b) mixes of
                      SOME (i, _) =>
                          let in
                              Array.update(mixes, i, true);
                              (* If a waveform, use hz. If a sample,
                                 use sample index. *)
                              if (inst >= SAMPLER_OFFSET)
                              then
                                  if n < 0 orelse n >= 128
                                  then raise Sound "sampler index out of range"
                                  else setfreq(i, n, v, inst)
                              else setfreq(i, pitchof n, v, inst);
                              Array.update(Vector.sub(miditable, ch),
                                           n,
                                           PLAYING i);
                          (* debug () *) ()
                          end
                    | NONE => print "No more mix channels.\n")
           (* re-use mix channel... *)
           | PLAYING i =>
                  if inst >= SAMPLER_OFFSET
                  then setfreq(i, n, v, inst)
                  else setfreq(i, pitchof n, v, inst))
    end

  fun noteoff (ch, n) =
    let in
        (* print ("(noteoff " ^ Int.toString ch ^ " " ^
                  Int.toString n ^ ")"); *)
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

  local
    val seteffect_ = _import "ml_seteffect" private : real -> unit ;
  in
    val seteffect = seteffect_
  end

  fun all_off () =
    let in
      (* turn off MIDI notes *)
      Vector.app (Array.modify (fn n => OFF)) miditable;
      (* turn off actual sound. don't use the arrays here because we
         want to shut off drums and effects channels too. *)
      Util.for 0 (NMIX - 1) (fn i => setfreq(i, pitchof 60, 0, INST_NONE));
      (* mix channel in-use masks *)
      Array.modify (fn _ => false) mixes;
      seteffect 0.0
    end

end
