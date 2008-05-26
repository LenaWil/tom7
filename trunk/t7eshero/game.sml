structure Game =
struct

  val itos = Int.toString

  exception Game of string

  type rawmidi = int * MIDI.track list
  fun fromfile f =
      let
          val r = (Reader.fromfile f) handle _ => 
              raise Game ("couldn't read " ^ f)
          val m as (ty, divi, thetracks) = MIDI.readmidi r
          val _ = ty = 1
              orelse raise Game ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
          val () = print ("MIDI division is " ^ itos divi ^ "\n")
          val _ = divi > 0
              orelse raise Game ("Division must be in PPQN form!\n")
      in
          (divi, thetracks)
      end




end