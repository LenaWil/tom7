
(* theorem prover by Tom 7 

   To solve homeworks for Constructive Logic class, Spring 2000 (?)

   Permission granted to use, reproduce, and modify this code
   for any purpose.
*)

  infixr 0 <==>
  infixr 1 ==>
  infix 1 <==
  infix 2 ||
  infix 3 &&

structure Prove =
struct

  type var = string

  exception Stuck of string 
  and Impossible
  and Unimplemented of string

  (* type of propositions (no derived forms) *)
  datatype prop =
    T
  | F
  | || of prop * prop
  | && of prop * prop
  | ==> of prop * prop
  | $ of var

  (* "constructors" for derived forms *)

  fun A <==> B = (A ==> B) && (B ==> A)
  fun ~A = A ==> F
  fun A <== B = B ==> A

  datatype proof =
      AndIntro of prop * proof * proof
    | AndElimL of prop * proof
    | AndElimR of prop * proof
    | ImpIntro of prop * var * proof
                    (*  A ==> B    A *)
    | ImpElim  of prop * proof * proof
    | OrIntroL of prop * proof
    | OrIntroR of prop * proof
    | True
    | Assume of prop * var
    | OrElim of prop * proof * var * var * proof * proof
(*      OrElim(p, pf, v1, v2, pf_L, pf_R)*)


  fun prop (AndIntro (p,_,_)) = p
    | prop (AndElimL (p,_)) = p
    | prop (AndElimR (p,_)) = p
    | prop (ImpIntro (p,_,_)) = p
    | prop (OrElim (p, _, _, _, _, _)) = p
    | prop (Assume (p,_)) = p
    | prop (ImpElim (p, _, _)) = p
    | prop (True) = raise Impossible (* T? *)

  (* print a proof (to a string) for tutch *)

  fun pn s =
    case size s of
      1 => s
    | _ => "(" ^ s ^ ")"

  fun ppp (A && B)  = pn (ppp A) ^ " & " ^ pn (ppp B)
    | ppp (A || B)  = pn (ppp A) ^ " | " ^ pn (ppp B)
    | ppp (A ==> B) = pn (ppp A) ^ " => " ^ pn (ppp B)
    | ppp T = "T"
    | ppp F = "F"
    | ppp ($A) = A

  fun ppf True = "T;\n"
    | ppf (OrIntroL (p, pf)) = (ppf pf) ^ 
                               (ppp p) ^ ";   % OrIntroL\n"
    | ppf (OrIntroR (p, pf)) = (ppf pf) ^ 
                               (ppp p) ^ ";   % OrIntroR\n"
    | ppf (AndIntro (p, l, r)) = (ppf l) ^ 
                                 (ppf r) ^ 
                                 (ppp p) ^ ";   % AndIntro\n"
    | ppf (AndElimL (p, pf)) = (ppf pf) ^ (ppp p) ^ ";   % AndElimL\n"
    | ppf (AndElimR (p, pf)) = (ppf pf) ^ (ppp p) ^ ";   % AndElimR\n"
    | ppf (ImpIntro (p as (A ==> _), v, pf)) = "[" ^ (ppp A) ^ 
                                 ";   % (assumption " ^ v ^ ")\n" ^
                                 (ppf pf) ^ "];\n" ^
                                 (ppp p) ^ ";   % ImpIntro (" ^ v ^ ")\n"
    | ppf (ImpElim (p, l, r)) = (ppf l) ^
                                (ppf r) ^
                                (ppp p) ^ ";   % ImpElim\n"

    | ppf (Assume (p, v)) = (ppp p) ^ ";   % By " ^ v ^ "\n"
    | ppf (OrElim (p, orproof, v1, v2, pf_l, pf_r)) =
                                (case prop orproof of
                                   A || B => "[" ^ (ppp A) ^ 
                                             "; % (assumption " ^ v1 ^ ")\n" ^
                                             (ppf pf_l) ^ "];\n" ^
                                             "[" ^ (ppp B) ^ 
                                             "; % (assumption " ^ v2 ^ ")\n" ^
                                             (ppf pf_r) ^ "];\n" ^
                                             (ppf orproof) ^
                                             (ppp p) ^ ";   % OrElim (" ^ v1 ^
                                             ", " ^ v2 ^ ")\n"
                                 | _ => raise Impossible)
    | ppf _ = raise Impossible
(*      OrElim(p, pf, v1, v2, pf_L, pf_R)*)

  (* SML/NJ stdlib *)

  structure C = 
    struct
      type ord_key = prop
        
      fun compare ($A, $B) = String.compare (A, B)
        | compare ($_, _) = GREATER
        | compare (_, $_) = LESS
        
        | compare (T, T) = EQUAL
        | compare (T, _) = GREATER
        | compare (_, T) = LESS
        
        | compare (F, F) = EQUAL
        | compare (F, _) = GREATER
        | compare (_, F) = LESS
        
        | compare (A || B, C || D) =
           (case compare (A, C) of
              EQUAL => compare (B, D)
            | v => v)
        | compare (_ || _, _) = GREATER
        | compare (_, _ || _) = LESS
           
        | compare (A && B, C && D) =
           (case compare (A, C) of
              EQUAL => compare (B, D)
            | v => v)
        | compare (_ && _, _) = GREATER
        | compare (_, _ && _) = LESS
              
        | compare (A ==> B, C ==> D) =
           (case compare (A, C) of
              EQUAL => compare (B, D)
            | v => v)
    end
  
  structure M = SplayMapFn (C)

  type context = proof M.map
      
  infix ++ ?? ==

  fun A == B = C.compare (A, B) = EQUAL
  val op ?? = M.find

  val empty = M.empty

  (* utility function conjures up new variable names *)
  local
    val ctr = ref 0
    fun inc i = (i := (!i + 1); !i)
  in
    fun newvar () = "v" ^ Int.toString (inc ctr)
  end

  fun elide s = if size s > 32 then String.substring (s, 0, 13) ^ "..." else s

  (* this function takes 
     a context of proofs
     a (bound) variable justifying our root assumption
     a root assumption.
     
     It returns a new context containing each "neutral" proof which
     can be derived from the new assumption (possibly using what's in
     the context already.) *)

  (* close a context with respect to a new proved thing. *)

  fun closewrt (G : context, pf : proof) : context * bool =
      (case prop pf of
         T => (G, false)
       | A =>
           (* check if we already have a proof of this prop *)
           (case M.find (G, A) of
              SOME _ => (G, false)
            | NONE =>
                let
                  val G' = M.insert (G, A, pf)

                  (* we just added a new proposition, which might
                     allow us to use implication elimination because
                     we now have the premise we need. *)

                  fun tryone (GG, nil) = GG
                    | tryone (GG, (imp as (C ==> D), poof)::t) = 
                      tryone (if A == C then
                                #1 (closewrt (GG, ImpElim (D, poof, pf)))
                              else 
                                (let
                                   val pf_C = up (GG, C)
                                 in
                                   #1 (closewrt (GG, ImpElim (D, poof, pf_C)))
                                 end) handle Stuck _ => GG
                                ,t)
                    | tryone (GG, _::t) = tryone (GG, t)

                  val G' = tryone (G', M.listItemsi G')

                (* XXX does this also take care of OrElim?
                   That's handled in down ()... *)

                in
                  (case A of
                     $C => G'
                   | F => raise Unimplemented "F"
                   | C && D => 
                     let val (ll, llb) = 
                       closewrt (G', AndElimL (C, pf))
                         val (rr, rrb) = 
                           closewrt (ll, AndElimR (D, pf))
                     in
                       if llb orelse rrb then rr else G'
                     end
                   | C ==> D =>
                     (let
                        val pf_C = up (G', C)
                      in
                        #1 (closewrt (G', ImpElim (D, pf, pf_C)))
                      end handle Stuck _ => G')
                   | C || D => G'
                   | _ => raise Impossible, 
                       true)
                end))

  and G ++ (v, P) = #1 (closewrt (G, Assume(P,v)))

  (* up: takes a statement to be proved and a context of assumptions,
     and returns a proof of it (or raises Stuck) *)

  and up (G, p) =
    let
    in
      (case p of
        (A && B) => AndIntro (p, up (G,A), up (G, B))
      | (A || B) =>
          (* some cleverness in which branch to try first
             might be in order here. *)
          
      (((OrIntroL(p, up (G, A)))
        handle Stuck s1 =>
          (OrIntroR(p, up (G, B)))
       handle Stuck s2 => raise Stuck ("can't get " ^
                                       ppp A ^ " || " ^ ppp B ^ ": " ^
                                       elide s1 ^ " AND " ^ 
                                       elide s2 ^ "!")))
      | (A ==> B) =>
      let
        val v = newvar ()
        val rr = up (G ++ (v, A), B)
      in
        ImpIntro (p, v, rr)
      end
      | T => True
      | F => raise Stuck "can't prove F"
      | $A =>
      (case G ?? p of
         NONE => raise Stuck ("can't get " ^ A ^ 
                              " downward")
       | SOME pf => pf))

         (* if all else fails, try Or Elim *)
         handle Stuck s =>
           let
             fun tryone nil = raise Stuck (s ^ "(not even OR-elim!)")
               | tryone ((dis as (C||D), pf)::t) = 
               (let
                  val _ = print ("- Trying to prove " ^ (ppp p) ^ " with " ^ 
                                 (ppp (C||D)) ^ "\n")
                  val v1 = newvar ()
                  val v2 = newvar ()
                  (* to avoid infinite loops, remove C||D from the
                     context! *)
                  val (G',_) = M.remove (G, dis)
                  val pf_L = up (G' ++ (v1, C), p)
                  val pf_R = up (G' ++ (v2, D), p)
                in
                  OrElim(p, pf, v1, v2, pf_L, pf_R)
                end handle Stuck _ => (print "eh\n"; tryone t))
               | tryone (_::t) = (print "roo\n"; tryone t)
           in
             tryone (M.listItemsi G)
           end
    end 

  fun prove A = up (empty, A) 
    handle Stuck s => (print ("Can't prove it: " ^ s ^ "\n");
                       raise Stuck s)

  (* solve a tutch homework problem *)
  fun solve name prop =
    let
      val pf = prove prop
      val str = ppf pf
    in
      print ("\nproof " ^ name ^ " : " ^ ppp prop ^ " =\nbegin\n" ^ str
             ^ "end;\n\n")
    end

  val A = $"A"
  val B = $"B"
  val C = $"C"
  val D = $"D"
  val E = $"E"

end

open Prove;
Compiler.Control.Print.printDepth := 15;
Compiler.Control.Print.printLength := 80;
