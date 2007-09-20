(* This is a simple optimization that
   replaces
   
      leta x = hold(w) v

   with

      bind x = v

   whenever w is the world we're currently at.

   Since non-valid function declarations use
   this arrangement, it is important for
   enabling some other optimizations (e.g. 
   direct calls).

   PERF: we could probably also monomorphize
   letshams that are only used once, or at one
   world?

*)

structure CPSHere :> CPSHERE =
struct

  structure V = Variable
  structure VM = V.Map
  open CPS

  infixr 9 `
  fun a ` b = a b
  fun I x = x

  exception Here of string

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindu0var = T.bindu0var
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  val total = ref 0
  fun reset () = total := 0
  fun score n =
    let in
      total := !total + n
    end

  structure HA : PASSARG where type stuff = unit =
  struct
    type stuff = unit
    structure ID = IDPass(type stuff = unit
                          val Pass = Here)
    open ID


    fun case_Leta (z : stuff) (s as ({selfe, selfv, selft}, G)) (a as (x, va, ebod)) =
      let fun don't () = ID.case_Leta z s a
      in
        case cval va of
          Hold (w, va) =>
            if world_eq (w, worldfrom G)
            then 
              let in
                score 50;
                selfe z G (Bind'(x, va, ebod))
              end
            else don't ()
        | _ => don't ()
      end

    fun case_VLeta (z : stuff) (s as ({selfe, selfv, selft}, G)) (a as (x, va, vbod)) =
      let fun don't () = ID.case_VLeta z s a
      in
        case cval va of
          Hold (w, va) =>
            if world_eq (w, worldfrom G)
            then 
              let in
                score 50;
                (* XXX conservativity requires a VBind construct,
                   but we only generate vleta for small/once, currently *)
                selfv z G (subvv va x vbod)
              end
            else don't ()
        | _ => don't ()
      end
      

  end
    
  structure K = PassFn(HA)

  fun inline G e = K.converte () G e

  fun optimize G e =
    let 
      fun go e =
        let val e = inline G e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of LETA_HERE optimization.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end

end