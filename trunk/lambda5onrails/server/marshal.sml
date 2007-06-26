
structure Marshal :> MARSHAL =
struct

  infixr 9 `
  fun a ` b = a b

  open Bytecode
  structure SM = StringMap

  exception Marshal of string

  fun unmarshal (dict : exp) (bytes : string) : exp =
    let
      val G = SM.empty

      (* this code imperatively consumes b from the head *)
      val b = ref bytes
      fun tok () =
        case StringUtil.token (fn #" " => true | _ => false) ` !b of
          ("", "") => raise Marshal "um expected token; empty"
        | (t, b') => let in b := b' ; t end

      fun int () =
        case IntConst.fromstring ` tok () of
          NONE => raise Marshal "um expected int"
        | SOME i => i

      fun string () =
        case StringUtil.urldecode ` tok () of
          NONE => raise Marshal "um expected urlencoded string"
        | SOME s => s

      fun um G (Dlookup s) =
        (case SM.find (G, s) of
           NONE => raise Marshal "um dlookup not found"
         | SOME d => um G d)
        | um G (Dp Dint) = Int ` int ()
        | um G (Dp Dconts) = Int ` int ()
        | um G (Dp Dcont) = Record [("g", Int ` int ()),
                                    ("f", Int ` int ())]
        | um G (Dp Dstring) = String ` string ()
        | um G (Dp Daddr) = String ` string ()
        | um G (Dexists {d,a}) =
           let
             val () = print ("dex get dict:\n")
             val thed = um G (Dp Ddict)
             val G = SM.insert(G, d, thed)
           in
             print ("dex got dict, now " ^ Int.toString (length a) ^ "\n");
             Record (("d", thed) ::
                     (* then 'n' expressions ... *)
                     ListUtil.mapi (fn (ad, i) =>
                                    ("v" ^ Int.toString i,
                                     um G ad)) a)
           end
        | um G (Dp Dvoid) = raise Marshal "can't unmarshal at void"
        | um G (Dp Ddict) =
          (case tok () of
             "DP" => Dp (case tok () of
                           "c" => Dcont
                         | "C" => Dconts
                         | "a" => Daddr
                         | "d" => Ddict
                         | "i" => Dint
                         | "s" => Dstring
                         | "v" => Dvoid
                         | _ => raise Marshal "um bad primdict?")
           | "DL" => Dlookup (tok ())
           | "DR" =>
               let val n = IntConst.toInt ` int ()
               in
                 print ("um dr: " ^ Int.toString n ^ "\n");
                 (* then n, then n lab/dict pairs *)
                 Drec ` List.tabulate(n,
                                      fn i =>
                                      (tok (), um G (Dp Ddict)))
               end
           | "DE" =>
               let
                 val d = tok ()
                 val n = IntConst.toInt ` int ()
               in
                 Dexists { d = d, a = List.tabulate(n, fn i => um G ` Dp Ddict) }
               end
           | s => raise Marshal ("um unimplemented " ^ s))

        | um G (Drec sel) =
             Record ` map (fn (s, d) =>
                           let
                             val s' = tok ()
                           in
                             (* the format is redundant *)
                             print ("unmarshal label " ^ s ^ "\n");
                             if s' = s
                             then (s', um G d)
                             else raise Marshal "unmarshal drec label mismatch"
                           end) sel

        | um G (Dsum _) = raise Marshal "unmarshal dsum unimplemented"

        | um _ (Record _) = raise Marshal "um: not dict"
        | um _ (Project _) = raise Marshal "um: not dict"
        | um _ (Primcall _) = raise Marshal "um: not dict"
        | um _ (Var _) = raise Marshal "um: dict not closed"
        | um _ (Int _) = raise Marshal "um: not dict"
        | um _ (String _) = raise Marshal "um: not dict"
        | um _ (Inj _) = raise Marshal "um: not dict"
        | um _ (Bytecode.Marshal _) = raise Marshal "um: not dict"
        
    in
      um G dict
    end

  fun marshal (dict : exp) (value : exp) : string = 
    let
      (* always start with an empty dict context *)
      val G = SM.empty

      fun mar G (Dlookup s) v =
        (case SM.find (G, s) of
           NONE => raise Marshal "dlookup not bound"
             (* hmm, the dicts in the context could be closures,
                holding the context we saw at the point we
                inserted them? But this is only an issue if
                we have shadowing... *)
         | SOME d => mar G d v)
        | mar G (Dp Dint) (Int i) = IntConst.toString i
        | mar G (Dp Dint) _ = raise Marshal "dint"
        | mar G (Dp Dconts) (Int i) = IntConst.toString i
        | mar G (Dp Dconts) _ = raise Marshal "dconts"
        | mar G (Dp Dcont) (Record [("g", Int g), ("f", Int f)]) =
                IntConst.toString g ^ " " ^ IntConst.toString f
        | mar G (Dp Dcont) _ = raise Marshal "dcont"
        | mar G (Dp Dstring) (String s) = StringUtil.urlencode s
        | mar G (Dp Dstring) _ = raise Marshal "dstring"
        | mar G (Dp Daddr) (String s) = StringUtil.urlencode s
        | mar G (Dp Daddr) _ = raise Marshal "daddr"
        | mar G (Dsum seol) (Inj (s, eo)) =
        (case (ListUtil.Alist.find op= seol s, eo) of
           (NONE, _) => raise Marshal "dsum/inj mismatch : missing label"
         | (SOME NONE, NONE) => s ^ " -"
         | (SOME (SOME d), SOME v) => s ^ " + " ^ mar G d v
         | _ => raise Marshal "dsum/inj arity mismatch")
        | mar G (Dsum _) _ = raise Marshal "dsum"
        | mar G (Drec sel) (Record lel) =
        StringUtil.delimit " "
                      (map (fn (s, d) =>
                            case ListUtil.Alist.find op= lel ("l" ^ s) of
                              NONE => raise Marshal 
                                       ("drec/rec mismatch : missing label l" ^ s ^ 
                                        " among: " ^ StringUtil.delimit ", "
                                        (map #1 lel))
                                        
                            | SOME v => s ^ " " ^ mar G d v) sel)
        | mar G (Drec _) _ = raise Marshal "drec"
        | mar G (Dexists {d, a}) (Record lel) =
        (case ListUtil.Alist.extract op= lel "d" of
           NONE => raise Marshal "no dict in supposed e-package"
         | SOME (thed, lel) =>
             let
             (* need to bind d; it might appear in a! *)
               val G' = SM.insert (G, d, thed)
             in
               mar G (Dp Ddict) thed ^ " " ^
               (StringUtil.delimit " " `
                ListUtil.mapi (fn (ad, i) =>
                               (case ListUtil.Alist.find op= lel 
                                          ("v" ^ Int.toString i) of
                                  NONE => raise Marshal 
                                    "missing val in supposed e-package"
                                | SOME v => mar G' ad v)) a)
             end)
        | mar G (Dexists _) _ = raise Marshal "dexists"
        | mar G (Dp Dvoid) _ = raise Marshal "can't actually marshal at dvoid"
        | mar G (Dp Ddict) d = 
           (case d of
              Dp pd => "DP " ^ (case pd of
                                  Dcont => "c"
                                | Dconts => "C"
                                | Daddr => "a"
                                | Ddict => "d"
                                | Dint => "i"
                                | Dstring => "s"
                                | Dvoid => "v")
            | Dlookup s => "DL " ^ s
            | Dexists {d, a} => "DE " ^ d ^ " " ^ Int.toString (length a) ^ " " ^
                   StringUtil.delimit " " (map (mar G (Dp Ddict)) a)
            | Drec sdl => "DR " ^ Int.toString (length sdl) ^
                   StringUtil.delimit " " (map (fn (s,d) => s ^ " " ^ mar G (Dp Ddict) d) sdl)
            | Dsum sdl => "DS " ^ Int.toString (length sdl) ^
                   StringUtil.delimit " " (map (fn (s,NONE) => s ^ " -"
                                                 | (s,SOME d) => s ^ " + " ^ mar G (Dp Ddict) d) sdl)
            | _ => raise Marshal "ddict")

          (* for completeness. we require the first argument to be a
             dictionary, of course! *)
        | mar _ (Record _) _ = raise Marshal "not dict"
        | mar _ (Project _) _ = raise Marshal "not dict"
        | mar _ (Primcall _) _ = raise Marshal "not dict"
        | mar _ (Var _) _ = raise Marshal "dict not closed"
        | mar _ (Int _) _ = raise Marshal "not dict"
        | mar _ (String _) _ = raise Marshal "not dict"
        | mar _ (Inj _) _ = raise Marshal "not dict"
        | mar _ (Bytecode.Marshal _) _ = raise Marshal "not dict"
    in
      mar G dict value
    end

end
