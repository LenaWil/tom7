structure Game =
struct

  infixr 9 `
  fun a ` b = a b

  val messagebox = Hero.messagebox

  val itos = Int.toString

  exception Game of string

  type rawmidi = int * MIDI.track list
  fun fromfile f =
      let
          val r = (Reader.fromfile f) handle _ => 
              raise Game ("couldn't read " ^ f)
          val m as (ty, divi, thetracks) = MIDI.readmidi r handle MIDI.MIDI s =>
              let in
                  print (s ^ "\n");
                  raise Game ("MIDI error: " ^ s)
              end
              
          val _ = ty = 1
              orelse raise Game ("MIDI file must be type 1 (got type " ^ itos ty ^ ")")
          val () = print ("MIDI division is " ^ itos divi ^ "\n")
          val _ = divi > 0
              orelse raise Game ("Division must be in PPQN form!\n")
      in
          (divi, thetracks)
      end

  (* get the name of a track *)
  fun findname nil = NONE
    | findname ((_, MIDI.META (MIDI.NAME s)) :: _) = SOME s
    | findname (_ :: rest) = findname rest

  (* Label all of the tracks
     This uses the track's name to determine its label. *)
  fun label PREDELAY SLOWFACTOR tracks =
      let
          fun foldin (data, tr) : (int * (Match.label * MIDI.event)) list = 
              map (fn (d, e) => (d, (data, e))) tr

          fun onetrack (tr, i) =
            case findname tr of
                NONE => SOME ` foldin (Match.Control, tr)
              | SOME "" => SOME ` foldin (Match.Control, tr)
              | SOME name => 
                  (case CharVector.sub(name, 0) of
                       #"+" =>
                       SOME `
                       foldin
                       (case CharVector.sub (name, 1) of
                            #"Q" => Match.Music (Sound.INST_SQUARE, i)
                          | #"W" => Match.Music (Sound.INST_SAW, i)
                          | #"N" => Match.Music (Sound.INST_NOISE, i)
                          | #"S" => Match.Music (Sound.INST_SINE, i)
                          | #"R" => Match.Music (Sound.INST_RHODES, i)
                          | #"D" => Match.Music (Sound.INST_SAMPLER Samples.sid, i)
                          | _ => (messagebox "?? expected R or S or Q or W or N\n"; raise Hero.Hero ""),
                            tr)

                     | #"!" =>
                       (case CharVector.sub (name, 1) of
                            #"R" =>
                              (* XXX only if this is the score we desire.
                                 (Right now we expect there's just one.) *)
                              SOME `
                              Match.initialize
                              (PREDELAY, SLOWFACTOR, (* XXX *)
                               map (fn i => 
                                    case Int.fromString i of
                                        NONE => raise Hero.Hero "bad tracknum in Score name"
                                      | SOME i => i) ` 
                               String.tokens (StringUtil.ischar #",")
                               ` String.substring(name, 2, size name - 2),
                               tr)
                          | _ => (print "I only support REAL score!"; raise Hero.Hero "real"))

                     | _ => (print ("confused by named track '" ^ 
                                    name ^ "'?? expected + or ! ...\n"); 
                             SOME ` foldin (Match.Control, tr))
                       )
      in
          List.mapPartial (fn x => x) (ListUtil.mapi onetrack tracks)
      end

end