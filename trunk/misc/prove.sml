
  infixr 0 <==>
  infixr 1 ==>
  infix 1 <==
  infix 2 ||
  infix 3 &&

structure Prove =
struct

  type var = string

  exception Stuck of string and Impossible

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
    | ImpIntro of prop * var * proof
    | True
    | Assume of prop * var

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
      
  infix ++ ?? ==

  (* this function takes 
     a context of proofs
     a (bound) variable justifying our root assumption
     a root assumption.
     
     It returns a new context containing each "neutral" proof which
     can be derived from the new assumption (possibly using what's in
     the context already.) *)

  fun down (G', (v, p)) = raise Impossible

  fun G ++ x = down (G, x)
  val op ?? = M.find

  val empty = M.empty

  (* utility function conjures up new variable names *)
  local
    val ctr = ref 0
    fun inc i = (i := (!i + 1); !i)
  in
    fun newvar () = "v" ^ Int.toString (inc ctr)
  end

  (* up: takes a statement to be proved and a context of assumptions,
     and returns a proof of it (or raises Stuck) *)

  fun up (G, p as (A && B)) : proof =
    let
      val ll = up (G, A)
      val rr = up (G, B)
    in
      AndIntro (p, ll, rr)
    end
    | up (G, p as (A ==> B)) =
    let
      val v = newvar ()
      val rr = up (G ++ (v, A), B)
    in
      ImpIntro (p, v, rr)
    end
    | up (_, T) = True
    | up (_, F) = raise Stuck "can't prove F"
    | up (G, p as ($A)) =
      (case G ?? p of
         NONE => raise Stuck "proof of proposition not available in context"
       | SOME pf => pf)

  fun prove A = up (empty, A) 
    handle Stuck s => (print ("Can't prove it: " ^ s ^ "\n");
                       raise Stuck s)

  val A = $"A"
  val B = $"B"
  val C = $"C"
  val D = $"D"

end

open Prove