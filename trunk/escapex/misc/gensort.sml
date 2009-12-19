
exception GenSort of string

(* generates ML code that sorts variables
   y1 ... yn with comparison operator <= 
   by returning a record { yi, yj, ... }
*)

local val c = ref 0
in
    fun genprefix () = 
        let in
            c := !c + 1;
            "m" ^ Int.toString (!c) ^ "_"
        end
end

fun gensort n =
    let 

        val vars = List.tabulate (n, 
                                  fn x => "y" ^ Int.toString (x + 1))

        fun sortl nil = "{}"
          | sortl [y] = "{" ^ y ^ " = " ^ y ^ "}"
          | sortl [x, y] =
            "(if " ^ x ^ " <= " ^ y ^ "\n" ^
            " then { " ^ x ^ " = " ^ x ^ ", " ^ y ^ " = " ^ y ^ " }\n" ^
            " else { " ^ x ^ " = " ^ y ^ ", " ^ y ^ " = " ^ x ^ " })\n"
          | sortl l =
            let
                (* split and sort independently *)
                val a = List.take (l, length l div 2)
                val b = List.drop (l, length l div 2)

                val s1 = sortl a
                val s2 = sortl b

                (* now bind 'em *)
                    
                val sortdecs =
                  "val {" ^ StringUtil.delimit ", " a ^ "} = " ^ s1 ^ "\n" ^
                  "val {" ^ StringUtil.delimit ", " b ^ "} = " ^ s2 ^ "\n"

                (* here we know every variable a is in sorted order,
                   and every variable in b is in sorted order. 
                   
                   merge to produce the result.. *)

            in
                "let (* sort " ^ StringUtil.delimit "," l ^ "*)\n" 
                ^ sortdecs ^
                "in (* merge " ^ StringUtil.delimit "," l ^ "*) \n" 
                ^ genmerge l a b ^ "\n" ^
                "end\n"
            end
    in
        "fun sort {" ^ StringUtil.delimit ", " vars ^ "} =\n" ^
        sortl vars
    end

and genmerge targets a b =
    let
        (* new prefix *)
        val p = genprefix()
            
        fun mergeexp nil nil nil =
            "{" ^
            StringUtil.delimit ", " 
            (map (fn s => s ^ " = " ^ p ^ s) targets) ^
            "}" 
          (* if one list is empty, then the targets will
             be satisfied from the other, in order *)
          | mergeexp (target::rest) nil (bb::moreb) =
            "let val " ^ p ^ target ^ " = " ^ bb ^ "\n" ^
            "in " ^ mergeexp rest nil moreb ^ "\n" ^
            "end"
          | mergeexp (target::rest) (aa::morea) nil =
            "let val " ^ p ^ target ^ " = " ^ aa ^ "\n" ^
            "in " ^ mergeexp rest morea nil ^ "\n" ^
            "end"
          | mergeexp (target::rest) (aa::morea) (bb::moreb) =
            "(if " ^ aa ^ " <= " ^ bb ^ "\n" ^
            " then let val " ^ p ^ target ^ " = " ^ aa ^ "\n" ^
            "      in " ^ mergeexp rest morea (bb::moreb) ^ "\n" ^
            "      end\n" ^
            " else let val " ^ p ^ target ^ " = " ^ bb ^ "\n" ^
                    "      in " ^ mergeexp rest (aa::morea) moreb ^ "\n" ^
                    "      end)"
          | mergeexp _ _ _ = raise GenSort "internal error: list mismatch"
                    
    in
        mergeexp targets a b
    end


fun genmergesingle nothers =
    let
        val vars = List.tabulate (nothers, 
                                  fn x => "y" ^ Int.toString (x + 2))
    in
        genmerge ("y1" :: vars) ["y1"] vars
    end
