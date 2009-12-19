
structure MakeFixedWord =
struct

    exception MakeFixedWord of string

    (* The word structure to use for the individual elements.
       32 is probably the best shot for 32-bit machines. *)
    val bestbits = 32 (* PERF *)
    val Wb = "Word" ^ Int.toString bestbits

    fun indent n s =
        StringUtil.replace "\n" ("\n" ^ StringUtil.tabulate n #" ") s

    fun to32 x = "(" ^ x ^ ")"

    fun makestruct bits num =
        let
            val () = if bits > bestbits
                     then raise MakeFixedWord "too many bits"
                     else ()

            val We = "Word" ^ Int.toString bits

            fun btoe s = "(" ^ We ^ ".fromLargeWord(" ^ Wb ^ ".toLargeWord(" ^ s ^ ")))"
            fun etob s = "(" ^ Wb ^ ".fromLargeWord(" ^ We ^ ".toLargeWord(" ^ s ^ ")))"

            (* for each element of the vector, we select one or two
               elements of our bestbits tuple and mask them together
               with shifts to retrieve that element. *)
            datatype method =
                Inword of { word : int,
                            (* bits skipped from the left *)
                            offset : int }
              | Spantwo of { left : int,
                             (* bits skipped in left word *)
                             leftoffset : int,
                             (* number of bits taken in left word *)
                             leftnum : int, 
                             (* right word is always left + 1 *)
                             right : int,
                             (* rightoffset is always 0 *)
                             rightoffset : int,
                             rightnum : int }
                             
            fun genmask x =
                let
                (* 
                   assuming we're using 5 bit words, then the tuple looks
                   like this, and we number bits from left to right:
                   
                   +++++-----+++++-----+++++-----

                   and if we're storing 3 bit elements, they are arranged
                   like this

                   +++++-----+++++-----+++++-----
                   ___===~~~___===~~~___===~~~___
                   0  1  2  3  4  5  6  7  8  9

                   first, the absolute bit numbers that start and
                   end our target element:

                   *)
                    val bitstart = x * bits
                    val bitend = x * bits + bits - 1

                    (* which words do these fall into? *)
                    val wordstart = bitstart div bestbits
                    val wordend   = bitend   div bestbits
                in
                    if wordstart = wordend
                    then Inword { word = wordstart,
                                  offset = bitstart mod bestbits }
                    else Spantwo { left = wordstart,
                                   leftoffset = bitstart mod bestbits,
                                   leftnum = bestbits - bitstart mod bestbits,
                                   right = wordend,
                                   rightoffset = 0,
                                   rightnum = bits - (bestbits - bitstart mod bestbits) }
                end

            val masks = List.tabulate(num, genmask)

            (* a word with this many 1 bits *)
            fun maskbits 0 = 0
              | maskbits n = 2 * (maskbits (n - 1)) + 1

            (* the number of words we'll need of bestbits size in order
               to represent num of bits size. *)
            val nwords = 
                List.foldr
                  (fn (Inword { word, ... }, m) => Int.max(m, word + 1)
                    | (Spantwo { right, ... }, m) => Int.max(m, right + 1)) 0 masks

            val wargsl = 
                List.tabulate (nwords, fn i => "w" ^ Int.toString i)
            val wargs =
                "(" ^ StringUtil.delimit "," wargsl ^ ")"

            val sub =
                "fun sub (" ^ wargs ^ ", n) =\n" ^ 
                "  case n of\n" ^
                let
                    fun bar 0 = " "
                      | bar _ = "|"
                    fun slice word shift mask =
                                         (* convert it *)
                                         btoe(
                                          (* mask it *)
                                          Wb ^ ".andb(" ^ Wb ^ ".fromInt " ^
                                                          Int.toString mask ^ ", " ^
                                           (* shift it *)
                                           Wb ^ ".>>(" ^ word ^ ", 0w" ^ Int.toString shift ^ ")" ^
                                          ")"
                                         )
                        
                    fun casechain n =
                        if n = num
                        then "  " ^ bar n ^ " _ => raise Subscript\n"
                        else "  " ^ bar n ^ " " ^ Int.toString n ^ " => " ^
                            (case List.nth (masks, n) of
                                 Inword { word, offset } =>
                                     let 
                                         val w = "w" ^ Int.toString word
                                         val shift = bestbits - (bits + offset)
                                         val mask = maskbits bits
                                     in
                                         (* here we have the word w 

                                                  >>> (shift)
                                            +++++++++
                                              ====
                                              ^
                                              offset
                                            *)
                                         slice w shift mask
                                     end
                               | Spantwo { left, leftoffset, leftnum,
                                           right, rightoffset, rightnum } => 
                                     let
                                         val l = "w" ^ Int.toString left
                                         val lshift = bestbits - (leftnum + leftoffset)
                                         val lmask = maskbits leftnum

                                         val r = "w" ^ Int.toString right
                                         val rshift = bestbits - (rightnum + rightoffset)
                                         val rmask = maskbits rightnum
                                     in
                                         We ^ ".orb(" ^
                                         We ^ ".<<(" ^
                                            slice l lshift lmask ^ ", 0w" ^ Int.toString rightnum ^ 
                                         "), " ^
                                         slice r rshift rmask ^ ")"
                                     end
                                 ) ^ "\n" ^ casechain (n + 1)
                in
                    casechain 0
                end

            (* assuming wargs in scope, and zero in the appropriate position,
               generate an expression of wargs updated where
               index x has the value i *)
            fun update n is =
                "let " ^ 
                (case List.nth (masks, n) of
                     Inword { word, offset } =>
                         let
                             val w = "w" ^ Int.toString word

                             val shift = bestbits - (bits + offset)
                         in
                             " val " ^ w ^ " = " ^
                             Wb ^ ".orb(" ^ w ^ ", " ^
                             Wb  ^".<<(" ^ etob is ^ ", 0w" ^ Int.toString shift ^ "))\n"
                         end
                   | Spantwo { left, leftoffset, leftnum,
                               right, rightoffset, rightnum } =>
                         let
                             val l = "w" ^ Int.toString left
                             val lshift = rightnum
                             val lmask = maskbits leftnum

                             val r = "w" ^ Int.toString right
                             val rshift = bestbits - (rightnum + rightoffset)
                             val rmask = maskbits rightnum
                         in
                             (* don't want to duplicate code... *)
                             " val x = " ^ etob is ^ "\n" ^
                             " val " ^ l ^ " = " ^
                             Wb ^ ".orb(" ^ l ^ ", " ^
                             Wb ^ ".andb(" ^ Wb ^ ".>>(x, 0w" ^ Int.toString lshift ^ "), " ^
                                         Wb ^ ".fromInt " ^ Int.toString lmask ^ "))\n" ^
                             " val " ^ r ^ " = " ^
                             Wb ^ ".orb(" ^ r ^ ", " ^
                             Wb ^ ".<<(" ^ Wb ^ ".andb(x, " ^ Wb ^ ".fromInt " ^ Int.toString rmask ^ "), " ^
                                       "0w" ^ Int.toString rshift ^ "))\n"
                         end)
                     ^ " in " ^ wargs ^ " end"

            val fromlist =
                "fun fromList [" ^ StringUtil.delimit ", " (List.tabulate(num, fn i =>
                                                                          "e" ^ 
                                                                          Int.toString i)) ^
                "] =\n" ^
                indent 2
                let
                    fun declchain n =
                        if n = num
                        then ""
                        else "  val " ^ wargs ^ " = " ^
                             update n ("e" ^ Int.toString n) ^ "\n" ^
                             declchain (n + 1)
                in
                    "let\n" ^
                    "  val " ^ wargs ^ " = (" ^ StringUtil.delimit ","
                                           (List.tabulate(nwords, fn _ => Wb ^ ".fromInt 0"))
                                           ^ ")\n" ^
                    declchain 0 ^ "\n" ^
                    "in\n" ^
                    "  " ^ wargs ^
                    "\nend\n"
                (* insists on exactly the right number of arguments *)
                end ^ " | fromList _ = raise FixedWord\n"

            val tabulate =
                "fun tabulate (len, f) = \n" ^
                indent 2
                let
                    fun declchain n =
                        if n = num
                        then ""
                        else "  val " ^ wargs ^ " = " ^
                             update n ("f " ^ Int.toString n) ^ "\n" ^
                             declchain (n + 1)
                in
                    "let\n" ^
                    "  val " ^ wargs ^ " = (" ^ StringUtil.delimit ","
                                           (List.tabulate(nwords, fn _ => Wb ^ ".fromInt 0"))
                                           ^ ")\n" ^
                    declchain 0 ^ "\n" ^
                    "in\n" ^
                    (* Insist that it is the correct size. 
                       PERF perhaps a safety argument that disables this check? *)
                    "  (if len <> " ^ Int.toString num ^ " then raise FixedWord else ());\n" ^
                    "  " ^ wargs ^
                    "\nend\n"
                end

            val hash =
                "fun hash (" ^ wargs ^ ") =\n" ^
                let
                    fun hchain nil y x = "0w123456789"
                      | hchain (n :: t) x y =
                            let val e = hchain t
                                ((((y * y) mod 31337) * 3 + 1) mod 65537)
                                ((((((x * x) mod 17117) * x) mod 17123) * 7 + 13) mod 45121)
                            in
                                "Word32.xorb(" ^ e ^ " * 0w" ^ IntInf.toString y ^ ", " ^ 
                                to32 n ^ 
                                " * 0w" ^ IntInf.toString x ^ ")"
                            end
                in
                    hchain wargsl 1173 31337
                end


            (* PERF should probably unroll the sub operations here too.
               they will be optimized well *)
            val exists =
                "fun exists f v =\n" ^
                let fun ifchain n =
                    if n = num
                    then "  false"
                    else "  f(sub(v, " ^ Int.toString n ^ ")) orelse\n" ^ ifchain (n + 1)
                in
                    ifchain 0
                end ^ "\n"

            val findi =
                "fun findi f v =\n" ^
                indent 2
                let fun fchain n =
                    if n = num
                    then " NONE"
                    else "let val t = (" ^ Int.toString n ^ ", sub(v, " ^ Int.toString n ^ "))\n" ^
                         "in if f t then SOME t else\n" ^
                         indent 2 (fchain (n + 1)) ^ "\n" ^
                         "end"
                in
                    fchain 0
                end

            val foldr =
                "fun foldr f b v =\n  " ^
                let fun appchain n =
                    if n = num
                    then " b "
                    else "f(sub(v, " ^ Int.toString n ^ "), " ^ appchain (n + 1) ^ ")"
                in
                    appchain 0
                end

            val tostring =
                "fun tostring (" ^ wargs ^ ") =\n  " ^
                let
                    fun onew w =
                        "CharVector.tabulate(" ^ Int.toString bestbits ^ 
                        ", fn b => if " ^ Wb ^ ".fromInt 0 = " ^ Wb ^ ".andb(" ^ w ^
                        ", " ^ Wb ^ ".<<(" ^ Wb ^ ".fromInt 1, Word.-(0w" ^
                        Int.toString(bestbits - 1) ^ ", Word.fromInt b))) then #\"0\" else #\"1\")"
                in
                    StringUtil.delimit (" ^\n  \"|\" ^ ") (map onew wargsl)
                end ^ "\n"

        in
             "\n" ^ 
             "(* Generated by MakeFixedWord. Do not edit! \n\n" ^
             "   This is a vector of fixed length. It contains " ^ Int.toString num ^ "\n" ^
             "   elements, each a Word" ^ Int.toString bits ^ ".word. *)\n\n" ^
             "structure FixedWordVec_" ^ Int.toString bits ^ "_" ^ Int.toString num ^
                " :> FIXEDWORDVEC where type word = " ^ We ^ ".word = \n" ^
            "struct\n" ^
            indent 2 
            ("\ntype word = " ^ We ^ ".word\n" ^
             "type vector = " ^ (case nwords of 
                                   0 => "unit" (* everything else still works *)
                                 | _ => StringUtil.delimit " * " 
                                       (List.tabulate (nwords, fn _ => Wb ^ ".word"))) ^ "\n" ^
             "exception FixedWord\n" ^
             "val LENGTH = " ^ Int.toString num ^ "\n" ^
             "fun length _ = LENGTH\n" ^
             sub ^ "\n" ^
             foldr ^ "\n" ^
             fromlist ^ "\n" ^
             tabulate ^ "\n" ^
             exists ^ "\n" ^
             hash ^ "\n" ^
             tostring ^ "\n" ^
             findi) ^
            "\nend\n"
        end
(*
    val () = StringUtil.writefile "fixedword-8-10.sml" (#2 (makestruct 8 10))
    val () = StringUtil.writefile "fixedword-4-5.sml" (#2 (makestruct 4 5))
    val () = StringUtil.writefile "fixedword-4-5.sml" (#2 (makestruct 4 5))
*)
end
