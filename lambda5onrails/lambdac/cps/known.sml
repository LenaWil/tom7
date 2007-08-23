(* Known is an optimization pass that reduces elimination
   forms where the object is a known introduction form.

   As a result this implements direct calls, since it
   reduces the idiom

   let closure = pack ...
   in
      unpack closure as f, env
      in 
      call(f, env, args)

   In order to conservatively apply this transformation,
   we need the arguments to the known introduction form
   to be small. Otherwise, we can be applying this multiple
   times and cause a blow-up in size. (This is especially
   true for the above case when f is a literal lambda.)

*)

structure CPSKnown :> CPSKNOWN =
struct

  structure V = Variable
  structure VM = V.Map
  open CPS

  infixr 9 `
  fun a ` b = a b
  fun I x = x

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

  fun small v =
    case cval v of
      Var _ => true
    | UVar _ => true
    | Int _ => true
    | Record nil => true
    | Hold (w, v) => small v
    | Sham (w, v) => small v
    | Codelab _ => true
    | _ => false

(*
  structure NA : PASSARG where type stuff = unit =
  struct
    type stuff = unit
    structure ID = IDPass(type stuff = stuff
                          fun Pass s = Known ("(name) " ^ s))
    open ID

    fun 

  end
*)

  (* things we can know about a bound variable *)
  datatype knowledge =
    Pack of { typ : ctyp, ann : ctyp, dict : cval, vals : cval list }
  | Rec of (string * cval) list

  type stuff = { v : knowledge VM.map,
                 u : knowledge VM.map }
   
  structure KA : PASSARG where type stuff = stuff =
  struct
    type stuff = stuff
    structure ID = IDPass(type stuff = stuff
                          val Pass = Known)
    open ID

    (* name the values in vl, so that if we expand this
       introduction form later, it doesn't duplicate any
       large things. 

       the continuation is called with the wrapper function
       (cexp -> cexp) that does any necessary naming, and
       the list of values, which will be the same length
       and all will be 'small' *)
    fun name nil k = k (I, nil)
      | name ((h : CPS.cval) :: rest) k =
      if small h
      then name rest (fn (f, l) => k (f, h :: l))
      else 
        let 
          val n = 
            case cval h of
              Lams [(v, _, _)] => V.tostring v
            | Lams ((v, _, _) :: _) => V.tostring v ^ "_and_friends"
            | Fsel (va, x) =>
                (case cval va of
                   Lams l => 
                     (let val (v, _, _) = List.nth (l, x)
                      in V.tostring v
                      end handle _ => raise Known "name: fsel oob")
                 | Var v => V.tostring v ^ "_fsel"
                 | UVar u => V.tostring u ^ "_fsel"
                 | _ => "fsel")
            | Dictfor _ => "d"
            | WDictfor _ => "wd"
            | _ => "name"

          val v = V.namedvar n
        in
          name rest (fn (f, l) =>
                     k (fn exp => Bind' (v, h, f exp),
                        Var' v :: l))
        end

    exception Again of cexp
    fun case_Primop z (s as ({selfe, selfv, selft}, G)) ([v], CPS.BIND, [obj], e) =
      (let
         val z' =
           case cval obj of
             Record svl =>
               if List.all (small o #2) svl
               then z ++ (v, Rec svl)
               else
                 let val (labs, vals) = ListPair.unzip svl
                 in
                   name vals
                   (fn (f, vals) =>
                    let
                      val svl = ListPair.zip (labs, vals)
                    in
                      (* wrap and try again. *)
                      raise Again (f (Primop' ([v], CPS.BIND, [Record' svl], e)))
                    end)
                 end
           | TPack (t, ann, dict, vals) =>
               if List.all small (dict :: vals)
               then z ++ (v, Pack { typ = t, ann = ann, dict = dict, vals = vals })
               else
                 name (dict :: vals)
                 (fn (f, dict' :: vals') =>
                  raise Again (f (Primop' ([v], CPS.BIND, [TPack' (t, ann, dict', vals')], e)))
               | _ => raise Known "impossible name"
                    )

           | _ => z
                 
         val (obj, tt) = selfv z G obj
       in
         Primop' ([v], BIND, [obj], selfe z' (bindvar G v tt ` worldfrom G) e)
       end handle Again ce => selfe z G ce)
      | case_Primop z s a = ID.case_Primop z s a

    fun case_Proj z (s as ({selfe, selfv, selft}, G)) (a as (lab, va)) =
      case cval va of
        (* and literal records? *)
        Var v =>
          (case z ?? v of
             SOME (Rec svl) =>
               (case ListUtil.Alist.find op= svl lab of
                  NONE => raise Known "proj of label known not to exist"
                | SOME va' =>
                    let in
                      score "PROJ" 100;
                      selfv z G va'
                    end)
           | SOME _ => raise Known "known proj non-rec"
           | NONE => ID.case_Proj z s a)
      | _ => ID.case_Proj z s a
(*
    fun case_TUnpack z (s as ({selfe, selfv, selft}, G)) 
                       (a as (tv, dv, xs, obj, bod)) =
       case cval obj of
         Var v =>
           (case z ?? v of
              SOME (Pack { typ, ann = _, dict = _, vals }) =>
                (* known. do the projections in place, then. *)
                let
                  val () = if length xs = length vals then ()
                           else raise Known "known pack mismatch"
                  val binds = ListPair.zip (vals, map #1 xs)
                  val bod = foldr (fn ((v, x), bod) =>
                                   Bind'(x, v, bod)) bod binds
                  val bod = Lift' (dv, Dictfor' typ, bod)
                  val bod = subte typ tv bod
                in
                  score "UNPACK" 100;
                  (* XXX then recurse on it! *)
                  bod
                end
            | SOME _ => raise Known "known unpack non-pack"
            | NONE => ID.case_TUnpack z s a)
          (* XXX also uvar *)
          | _ => ID.case_TUnpack z s a
*)
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