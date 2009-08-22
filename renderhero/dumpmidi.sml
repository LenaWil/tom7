(* Dumpmidi generates a text-file version of a MIDI file, which
   can be used as data for programs (i.e. a microcontroller-based
   MIDI player. *)

structure DumpMIDI =
struct

  fun messagebox s = print (s ^ "\n")

  exception Nope
  exception Hero of string

  (* This uses lots of top-level evaluation, making exception handling awkward *)
  fun report e =
      case e of 
          Hero s => (messagebox ("exn test: " ^ s); raise e)
        | e => 
              let in
                  app (fn s => print (s ^ "\n")) (MLton.Exn.history e);
                  messagebox ("Uncaught exception: " ^ exnName e ^ " / " ^ exnMessage e);
                  raise e
              end

  fun printerr s = TextIO.output(TextIO.stdErr, s ^ "\n")

  (* Dummy event, used for bars and stuff *)
  val DUMMY = MIDI.META (MIDI.PROP "dummy")

  datatype bar =
      Measure
    | Beat
    | Timesig of int * int

  (* XXX these should describe what kind of track it is *)
  datatype label =
      Music of int
    | Control
    | Bar of bar

  (* note 60 is middle C = 256hz,
     so 0th note is 8hz.
     *)
(* XXX no floats on mingw, urgh
  val () = Control.Print.printLength := 10000
  fun pitchof n = Real.round ( 80000.0 * Math.pow (2.0, real n / 12.0) )
  val pitches = Vector.fromList (List.tabulate(128, pitchof))
*)

  (* in ten thousandths of a hertz *)
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

  (* must agree with sound.c *)
  val INST_NONE   = 0
  val INST_SQUARE = 1
  val INST_SAW    = 2
  val INST_NOISE  = 3
  val INST_SINE   = 4

  val freqs = Array.array(16, 0)

  datatype status = 
      OFF
    | PLAYING of int
  (* for each channel, all possible midi notes *)
  val miditable = Array.array(16, Array.array(127, OFF))
  val NMIX = 6 (* get from param *)
  val mixes = Array.array(NMIX, false)

  (* FIXME totally ad hoc!! *)
  val itos = Int.toString
  val f = (case CommandLine.arguments() of 
               st :: _ => st
             | _ => "totally-membrane.mid")
  val r = (Reader.fromfile f) handle _ => 
      raise Hero ("couldn't read " ^ f)
  val m as (ty, divi, thetracks) = MIDI.readmidi r
  val _ = ty = 1
      orelse raise Hero ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
  val () = print ("MIDI division is " ^ itos divi ^ "\n")
  val _ = divi > 0
      orelse raise Hero ("Division must be in PPQN form!\n")

  fun div_exact (m : IntInf.int, n) =
      let
          val q = m div n
      in
          if n * q <> m
          then raise Hero (IntInf.toString m ^ " div " ^ 
                           IntInf.toString n ^ " cannot be represented exactly")
          else q
      end
      
  fun div_exacti (m, n) = IntInf.toInt (div_exact (IntInf.fromInt m, IntInf.fromInt n))

  infix div_exact div_exacti

  (* How to complete pre-delay? *)
  fun delay t = (2 * divi, (Control, DUMMY)) :: t

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  val () = print ("Divi is " ^ Int.toString divi ^ "\n")

  val DIVI_DIVISION = 120 (* I care about 32nd notes *)
  val FRAMES_PER_TICK = 1 (* report in frames *)
  (* For ActionScript geometric renderers *)
  fun print_track t =
      let 
          (* number of ticks per sixteenth note *)
          val divisor = divi div_exacti DIVI_DIVISION

          fun noteson extra ((delta, e) :: l) =
              let val delta = delta + extra
                  val extra = 
                      case e of
                          MIDI.NOTEON(_, note, 0) => delta
                        | MIDI.NOTEON(_, note, v) => 
                           let in
                              print
                              ("{ d:" ^ Int.toString ((delta * FRAMES_PER_TICK) 
                                                      div_exacti divisor) ^
                               ", n:" ^ Int.toString note ^ "}, ");
                              0
                            end
                        | _ => delta
              in
                  noteson extra l
              end
            | noteson _ nil = ()
      in
          noteson 0 t
      end

  (* For microchip *)
  fun print_track_pic t =
      let 
          (* XXX args *)
          val DIVI_DIVISION = 120
          val FRAMES_PER_TICK = 1 (* report in frames *)
          val NMIX = 6

          val songlength = ref 0
              
          (* Need to keep track of what channels are active. 
             Notes tells us which mix channel the note is
             currently assigned to.
             
             Status tells us whether the mix channel is
             currently active. *)
          val notes = Array.array (128, NONE)
          val status = Array.array (NMIX, false)

          (* number of ticks per sixteenth note *)
          val divisor = divi div_exacti DIVI_DIVISION

          fun loop extra ((delta, e) :: l) =
              let val delta = delta + extra

                  (* XXX PERF:
                     If we have a note off and a note on in the same frame,
                     then we should not bother turning it off and then on;
                     we should allocate the new note to overwrite the old in
                     one step. *)
                  fun donote (MIDI.NOTEON(c, note, 0)) = donote (MIDI.NOTEOFF(c, note, 0))
                    | donote (MIDI.NOTEON(_, note, v)) =
                      (* is it already on? ignore. *)
                      if Option.isSome (Array.sub(notes, note))
                      then
                          let in
                              printerr "The note was already on.";
                              delta
                          end
                      else
                        (* find a channel to use *)
                        (case Array.findi (fn (_, b) => not b) status of
                             NONE =>
                                 let in
                                     printerr "There was no channel available.";
                                     delta
                                 end
                           | SOME (ch, _) =>
                                 let in
                                     Array.update(status, ch, true);
                                     Array.update(notes, note, SOME ch);
                                     songlength := !songlength + 1;
                                     print (" { " ^ Int.toString ((delta * FRAMES_PER_TICK) 
                                                                  div_exacti divisor) ^ ", " ^
                                            Int.toString ch ^ ", " ^
                                            Int.toString (pitchof note div 10000) ^ " },\n");
                                     0
                                 end)
                    | donote (MIDI.NOTEOFF(_, note, _)) =
                        (case Array.sub(notes, note) of
                             NONE =>
                                 let in
                                     printerr "Note off when not on.";
                                     delta
                                 end
                           | SOME ch =>
                                 if Array.sub(status, ch)
                                 then 
                                     let in
                                         Array.update(notes, note, NONE);
                                         Array.update(status, ch, false);

                                         songlength := !songlength + 1;                                         
                                         print (" { " ^ Int.toString ((delta * FRAMES_PER_TICK) 
                                                                      div_exacti divisor) ^ ", " ^
                                                Int.toString ch ^ ", " ^
                                                "0" ^ " },\n");
                                         0
                                     end
                                 else raise Hero "inconsistent status")
                        | donote _ = delta

                  val extra = donote e
              in
                  loop extra l
              end
            | loop _ nil = ()
      in
          loop 0 t;
          print ("};\n\n#define SONGLENGTH " ^ Int.toString (!songlength) ^ "\n")
      end

  (* Label all of the tracks
     This uses the track's name to determine its label. *)
  fun label tracks =
      let
          fun onetrack tr =
              case findname tr of
                  NONE => SOME (Control, tr) (* (print "Discarded track with no name.\n"; NONE) *)
                | SOME "" => SOME (Control, tr) (* (print "Discarded track with empty name.\n"; NONE) *)
                | SOME name => 
                      (case CharVector.sub(name, 0) of
                           #"+" =>
                           SOME (case CharVector.sub (name, 1) of
                                     #"Q" => 
                                     let in 
                                         (* XXX hack attack, should be command line or sth? *)
                                         print_track_pic tr;
                                         Music INST_SQUARE 
                                     end
                                   | #"W" => 
                                     let in
                                         (* XXX hack attack *)
                                         (* print_track tr; *)
                                         Music INST_SAW 
                                     end
                                   | #"N" => Music INST_NOISE
                                   | #"S" => Music INST_SINE
                                   | _ => (print "?? expected Q or W or N\n"; raise Hero ""),
                                 tr)
                         | _ => (print ("confused by named track '" ^ name ^ "'?? expected + or ...\n"); 
                                 SOME (Control, tr))
                           )
      in
          List.mapPartial onetrack tracks
      end handle e => report e
      
  val tracks = label thetracks

end
