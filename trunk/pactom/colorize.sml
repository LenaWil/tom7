structure Colorize = 
struct 

  val x = XML.parsefile "pactom.kml"
      handle (e as (XML.XML s)) => (print ("Error: " ^ s); raise e)

  datatype tree = datatype XML.tree

  fun printxml (Text s) =
      (StringUtil.replace "<" "&lt;"
       (StringUtil.replace ">" "&gt;"
        (StringUtil.replace "&" "&amp;" s)))
    | printxml (Elem ((s, attrs), tl)) =
      ("<" ^ s ^
       String.concat (map (fn (s, so) => 
                           case so of
                               SOME v => 
                                   (* XXX escape quotes in v *)
                                   (" " ^ s ^ "=\"" ^ v ^ "\"")
                             | NONE => s) attrs) ^
       ">" ^
       String.concat (map printxml tl) ^
       "</" ^ s ^ ">")

  val seed = ref (0wxDEADBEEF : Word32.word)
      
  fun rand () =
      let in
          seed := !seed + 0wx23456789;
          seed := !seed * 0w31337;
          seed := Word32.mod(!seed, 0w477218579);
          seed := Word32.xorb(!seed, 0w331171895);
          Word32.andb(!seed, 0wxFFFFFF)
      end

  (* always alpha 1.0 *)
  fun randomanycolor () = 
      "ff" ^ StringUtil.padex #"0" ~6 (Word32.toString (rand()))

  (* Same value and saturation, different hue. *)
  fun randomcolor () =
      "ff" ^ Color.tohexstring (Color.hsvtorgb 
                                (Word8.fromInt (Word32.toInt (Word32.andb(Word32.>>(rand (), 0w7), 0wxFF))),
                                 0wxFF,
                                 0wxFF))

  fun process (Elem(("color", nil), [Text _])) =
      Elem(("color", nil), [Text (randomcolor ())])
    | process (e as Text _) = e
    | process (Elem(t, tl)) = Elem(t, map process tl)

  val () = print (printxml (process x))
end