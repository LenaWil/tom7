(* Known is an optimization pass that reduces elimination
   forms where the object is a known introduction form.

   As a result this implements direct calls, since it
   reduces the idiom

   let closure = pack ...
   in
      unpack closure as f, env
      in 
      call(f, env, args)
*)

structure CPSKnown :> CPSKNOWN =
struct

  structure V = Variable
  structure VM = V.Map
  open CPS

  infixr 9 `
  fun a ` b = a b

  exception Known of string

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
      print (s ^ ".\n");
      total := !total + n
    end

  infix ?? ??? ++ +++
  fun { v, u } ??  x = VM.find (v, x)
  fun { v, u } ??? x = VM.find (u, x)
  fun { v, u } ++  (x, k) = { v = VM.insert(v, x, k), u = u }
  fun { v, u } +++ (x, k) = { u = VM.insert(u, x, k), v = v }

  (* things we can know about a bound variable *)
  datatype knowledge =
    Pack of { typ : ctyp, ann : ctyp, dict : cval, vals : cval list }

  type stuff = { v : knowledge VM.map,
                 u : knowledge VM.map }
    
  structure KA : PASSARG where type stuff = stuff =
  struct
    type stuff = stuff
    structure ID = IDPass(type stuff = stuff
                          val Pass = Known)
    open ID

    fun case_Primop z ({selfe, selfv, selft}, G) ([v], CPS.BIND, [obj], e) =
      let
        val (obj, t) = selfv z G obj
        val G = bindvar G v t ` worldfrom G

        val z' =
          case cval obj of
            TPack (t, ann, dict, vals) => z ++ (v, Pack { typ = t, ann = ann, 
                                                          dict = dict, vals = vals })
          | _ => z
      in
        Primop' ([v], BIND, [obj], selfe z' G e)
      end
      | case_Primop z s a = ID.case_Primop z s a

  (* XXX use knowledge, obviously... *)

  end
    
  structure K = PassFn(KA)

  fun known G e = K.converte { v = VM.empty, u = VM.empty } G e

  fun optimize G e =
    let 
      fun go e =
        let val e = known G e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of KNOWN optimization.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end
end