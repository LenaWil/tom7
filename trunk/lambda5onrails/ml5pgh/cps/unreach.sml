(* Removes unreachable code. Right now the only
   kind of unreachable code is in the default of
   an exhaustive sumcase.

   We could also reduce the number of friends in
   a mutually recursive bundle, but this analysis
   is more complicated and its not clear it ever
   comes up.

   (Well, it surely does if the programmer writes
    it, but we have no obligation to clean up for
    bad programs.)

*)

structure CPSUnreach :> CPSUNREACH =
struct

  structure V = Variable
  structure VM = V.Map
  open CPS

  infixr 9 `
  fun a ` b = a b
  fun I x = x

  exception Unreach of string

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindu0var = T.bindu0var
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  val total = ref 0
  fun reset () = total := 0
  fun score s n =
    let in
      (* print (s ^ ", "); *)
      total := !total + n
    end
   
  structure IA : PASSARG where type stuff = unit =
  struct
    type stuff = unit
    structure ID = IDPass(type stuff = unit
                          val Pass = Unreach)
    open ID

    fun case_Case z ({selfe, selfv, selft}, G) (va, v, arms, def) =
      let val (va, t) = selfv z G va
      in
        case ctyp t of
          Sum stl =>
            let
              val () = if ListUtil.alladjacent op<> (map #1 ` ListUtil.sort (ListUtil.byfirst String.compare) arms)
                       then ()
                       else raise Unreach "duplicate label in sumcase"
              
              fun carm (s, e) =
                case ListUtil.Alist.find op= stl s of
                  NONE => raise Unreach ("arm " ^ s ^ " not found in case sum type")
                | SOME NonCarrier => (s, selfe z G e) (* var not bound *)
                | SOME (Carrier { carried = t, ... }) => 
                    (s, selfe z (bindvar G v t ` worldfrom G) e)
            in
              Case' (va, v, map carm arms, 
                     if length arms = length stl
                     then
                       let in
                         score "EXHAUSTIVE" 50;
                         Halt'
                       end
                     else selfe z G def)
            end
        | _ => raise Unreach "case on non-sum"
      end

  end
    
  structure K = PassFn(IA)

  fun unreach G e = K.converte () G e

  fun optimize G e =
    let 
      fun go e =
        let val e = unreach G e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of UNREACH optimization.\n");
                (* this always gets everything the first time. *)
                (*
                reset ();
                go e
                 *)
                e
                )
          else e
        end
    in
      go e
    end

end