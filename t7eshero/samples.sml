
structure Samples :> SAMPLES =
struct

    (* Load a sample or use its already registered version.
       Empty string means built-in silence. *)
    val registered = ref [("", Sound.silence)]
    fun registerfromfilename f =
        case ListUtil.Alist.find op= (!registered) f of
            NONE =>
                (let
                     val { samplespersec, frames } = Wave.read (Reader.fromfile f)
                     val v =
                         case frames of
                             Wave.Bit16 fr =>
                                 (if Vector.length fr <> 1
                                  then print ("Warning: More than 1 channel in " ^ f ^ "; using first")
                                  else ();
                                  Vector.sub(fr, 0))
                           | _ => Hero.fail ("Sorry, I only support 16-bit waves now (" ^ f ^ ")")
                     val () =
                         if samplespersec <> 0w44100
                         then print ("Warning: Sample rate for " ^ f ^ " is not 44100khz!")
                         else ()
                     val w = Sound.register_sample v
                 in
                     registered := (f, w) :: !registered;
                     w
                 end handle Reader.Reader s => Hero.fail ("Couldn't read sample " ^ f)
                          | Wave.Wave s => Hero.fail ("Couldn't parse sample wave " ^ f))
          | SOME s => s

    (* Commodore 64 SID *)
    val sid =
        Sound.register_sampleset
        (Vector.fromList (map (fn "" => Sound.silence
                                 | s => registerfromfilename ("samples/sid/c64sid-" ^ s ^ ".wav"))
      [
     (* 0=[88] Standard1 Kick1     *) "sou001",
     (* 1=[88] Standard1 Kick2     *) "kick10",
     (* 2=[88] Standard2 Kick1     *) "kick1",
     (* 3=[88] Standard2 Kick2     *) "kick2",
     (* 4=[55] Kick Drum1          *) "kick4",
     (* 5=[55] Kick Drum2          *) "kick8",
     (* 6=[88] Jazz Kick1          *) "tom4",
     (* 7=[88] Jazz Kick2          *) "tom3",
     (* 8=[88] Room Kick1          *) "tom2",
     (* 9=[88] Room Kick2          *) "tom",
     (* 10=[88] Power Kick1        *) "gabkick",
     (* 11=[88] Power Kick2        *) "gabkick2",
     (* 12=[88] Electric Kick2     *) "tom6",
     (* 13=[88] Electric Kick1     *) "tom5",
     (* 14=[88] TR-808 Kick        *) "gabkick",
     (* 15=[88] TR-909 Kick        *) "gabkick2",
     (* 16=[88] Dance Kick         *) "gabkick3",
     (* 17=Voice One               *) "noize5",
     (* 18=Voice Two               *) "noize11",
     (* 19=Voice Three             *) "noize14",
     (* 20=??                      *) "",
     (* 21=??                      *) "",
     (* 22=MC-505 Beep1            *) "fooh",
     (* 23=MC-505 Beep2            *) "foch",
     (* 24=Concert SD              *) "sou002",
     (* 25=Snare Roll              *) "ran02",
     (* 26=Finger Snap2            *) "ch5",
     (* 27=High Q                  *) "noize6",
     (* 28=Slap                    *) "noize8",
     (* 29=Scratch Push            *) "noize15",
     (* 30=Scratch Pull            *) "noize17",
     (* 31=Sticks                  *) "that3",
     (* 32=Square Click            *) "ch3",
     (* 33=Metronome Click         *) "ch4",
     (* 34=Metronome Bell          *) "ch5",
     (* 35=Acoustic Bass Drum      *) "gabkick",
     (* 36=Bass Drum 1             *) "kick5",
     (* 37=Side Kick               *) "kick6",
     (* 38=Acoustic Snare          *) "snare12",
     (* 39=Hand Clap               *) "sou013", (* good *)
     (* 40=Electric Snare          *) "snare10",
     (* 41=Low Floor Tom           *) "sou017",
     (* 42=Closed High-Hat         *) "ch1",
     (* 43=High Floor Tom          *) "tom",
     (* 44=Pedal High Hat          *) "ch5",
     (* 45=Low Tom                 *) "tom7",
     (* 46=Open High Hat           *) "oh1",
     (* 47=Low-Mid Tom             *) "that2",
     (* 48=High-Mid Tom            *) "that3",
     (* 49=Crash Cymbal 1          *) "sou012", (* good *)
     (* 50=High Tom                *) "that1",
     (* 51=Ride Cymbal 1           *) "sou011", (* good *)
     (* 52=Chinese Cymbal          *) "sou012",
     (* 53=Ride Bell               *) "noize18",
     (* 54=Tambourine              *) "oh4",
     (* 55=Splash Cymbal           *) "sou012",
     (* 56=Cowbell                 *) "oh3",
     (* 57=Crash Cymbal 2          *) "sou012",
     (* 58=Vibrastrap              *) "noize3",
     (* 59=Ride Cymbal 2           *) "sou011",
     (* 60=High Bongo              *) "that3",
     (* 61=Low Bongo               *) "that2",
     (* 62=Mute High Conga         *) "cometom1",
     (* 63=Open High Conga         *) "cometom2",
     (* 64=Low Conga               *) "noize11",
     (* 65=High Timbale            *) "gabkick2",
     (* 66=Low Timbale             *) "gabkick",
     (* 67=High Agogo              *) "tom5",
     (* 68=Low Agogo               *) "tom4",
     (* 69=Cabasa                  *) "oh1",
     (* 70=Maracas                 *) "ch1",
     (* 71=Short Whistle           *) "noize14",
     (* 72=Long Whistle            *) "ran07",
     (* 73=Short Guiro             *) "noize1", (* good *)
     (* 74=??                      *) "sou007",
     (* 75=Claves                  *) "noize15",
     (* 76=High Wood Block         *) "sou014", (* good *)
     (* 77=Low Wood Block          *) "sou015", (* good *)
     (* 78=Mute Cuica              *) "that2",
     (* 79=Open Cuica              *) "that1",
     (* 80=Mute Triangle           *) "noize17",
     (* 81=Open Triangle           *) "ran02",
     (* 82=Shaker                  *) "noize3",
     (* 83=Jingle Bell             *) "noize8",
     (* 84=Bell Tree               *) "noize16",
     (* 85=Castanets               *) "ch4",
     (* 86=Mute Surdo              *) "lkick",
     (* 87=Open Surdo              *) "lsnare",
     (* 88=Applaus2                *) "noize16",
     (* 89=??                      *) "",
     (* 90=??                      *) "",
     (* 91=??                      *) "",
     (* 92=??                      *) "",
     (* 93=??                      *) "",
     (* 94=??                      *) "",
     (* 95=??                      *) "",
     (* 96=??                      *) "",
     (* 97=[88] Standard1 Snare1   *) "snare01", (* Despite the names, the next few are orc hits *)
     (* 98=[88] Standard1 Snare2   *) "snare02",
     (* 99=[88] Standard2 Snare1   *) "snare03",
     (* 100=[88] Standard2 Snare2  *) "snare04",
     (* 101=[55] Snare Drum2       *) "snare05",
     (* 102=Standard1 Snare1       *) "snare06",
     (* 103=Standard1 Snare2       *) "snare07",
     (* 104=Standard1 Snare3       *) "snare08", (* This is like record surface noise *)
     (* 105=[88] Jazz Snare1       *) "snare09", (* then just cycle snares... *)
     (* 106=[88] Jazz Snare2       *) "snare10",
     (* 107=[88] Room Snare1       *) "snare11",
     (* 108=[88] Room Snare2       *) "snare12",
     (* 109=[88] Power Snare1      *) "snare13",
     (* 110=[88] Power Snare2      *) "snare14",
     (* 111=[55] Gated Snare       *) "snare15",
     (* 112=[88] Dance Snare1      *) "snare16",
     (* 113=[88] Dance Snare2      *) "snare17",
     (* 114=[88] Disco Snare       *) "sou006",
     (* 115=[88] Electric Snare2   *) "fosn",
     (* 116=[55] Electric Snare    *) "lsnare",
     (* 117=[88] Electric Snare 3  *) "snare01",
     (* 118=TR-707 Snare           *) "snare02",
     (* 119=[88] TR-808 Snare1     *) "snare03",
     (* 120=[88] TR-808 Snare2     *) "snare04",
     (* 121=[88] TR-909 Snare1     *) "snare05",
     (* 122=[88] TR-909 Snare2     *) "snare06",
     (* 123=Rap Snare              *) "snare07",
     (* 124=Jungle Snare1          *) "snare08",
     (* 125=House Snare1           *) "snare09",
     (* 126=[88] House Snare       *) "snare10",
     (* 127=House Snare2           *) "snare11"
      ]))

        (* These are safe to delete:
            ch2
            clptom
            fokick
            hat
            kick11
            kick12
            kick3
            kick7
            kick9
            kickhat1
            oh2
            sou003
            sou004
            sou005
            sou008
            sou009
            sou010
            sou016
            sou018
            sou019
            sou020
            *)

    (* these are good, but pretty intense
       snare comes in kinda late too
       *)
    val default_drumbank = Vector.fromList [38, 42, 45, 49, 14]
    (* better. basically realistic. like the melodic tom.
       but too loud...
       *)
    val default_drumbank = Vector.fromList [40, 42, 45, 49, 2]

    (* bad TOM *)
    val default_drumbank = Vector.fromList [40, 42, 110, 46, 2]

    val default_drumbank = Vector.fromList [40, 42, 44, 46, 2]
end