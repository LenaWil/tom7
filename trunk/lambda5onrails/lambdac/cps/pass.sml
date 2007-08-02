(* Many passes in the CPS phase require type information,
   but only really care about changing a few constructs in
   CPS. PassFn is a functor that builds CPS transformation
   passes.

   To build a pass, provide a PASSARG. The passarg says how
   to transform each 
*)

(* identity pass that sends along any 'stuff' untouched. *)
functor IDPass(type stuff) : PASSARG where type stuff = stuff =
struct
  
  type stuff = stuff
  type var = Variable.var
  type cval = CPS.cval
  type world = CPS.world
  type cexp = CPS.cexp
  type ctyp = CPS.ctyp

  type exp_result = cexp
  type val_result = cval * ctyp
  type typ_result = ctyp
  type context = CPSTypeCheck.context

  type selves = { selfv : stuff -> context -> CPS.cval -> CPS.cval * CPS.ctyp,
                  selfe : stuff -> context -> CPS.cexp -> CPS.cexp,
                  selft : stuff -> context -> CPS.ctyp -> CPS.ctyp }

  structure V = Variable
  structure VS = Variable.Set
  open CPS

  infixr 9 `
  fun a ` b = a b

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindu0var = T.bindu0var
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  exception Pass of string

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)

  (* Expressions *)

  fun case_Call z (s as {selfv, selfe, selft}, G) (f, args) =
       let
         val (f, _) = selfv z G f
         val (args, _) = ListPair.unzip ` map (selfv z G) args
       in
         Call' (f, args)
       end
         
  fun case_Halt _ _ = Halt'

  fun case_ExternVal z (s as {selfv, selfe, selft}, G) (v, l, t, wo, e) =
    let val t = selft z G t
    in
      ExternVal'
      (v, l, t, wo, 
       selfe z (case wo of
                  NONE => bindu0var G v t
                | SOME w => bindvar G v t w) e)
    end

  fun case_ExternType z (s as {selfv, selfe, selft}, G) (v, l, dict, e) =
    let
      val G = bindtype G v false
      val G = 
        case dict of
          SOME(dv, dl) => bindu0var G dv ` Dictionary' ` TVar' v
        | NONE => G
    in
      ExternType' (v, l, dict, selfe z G e)
    end

  fun case_ExternWorld z (s as {selfe, selfv, selft}, G) (l, k, e) = ExternWorld' (l, k, selfe z (T.bindworldlab G l k) e)

  fun case_Case z ({selfe, selfv, selft}, G) (va, v, arms, def) =
        let val (va, t) = selfv z G va
        in
          case ctyp t of
           Sum stl =>
             let
               fun carm (s, e) =
                 case ListUtil.Alist.find op= stl s of
                   NONE => raise Pass ("arm " ^ s ^ " not found in case sum type")
                 | SOME NonCarrier => (s, selfe z G e) (* var not bound *)
                 | SOME (Carrier { carried = t, ... }) => 
                       (s, selfe z (bindvar G v t ` worldfrom G) e)
             in
               Case' (va, v, map carm arms, selfe z G def)
             end
         | _ => raise Pass "case on non-sum"
        end

  fun case_Primop z ({selfe, selfv, selft}, G) ([v], SAY, [k], e) =
         let
           val (k, t) = selfv z G k
           val G = bindvar G v (Zerocon' STRING) ` worldfrom G
         in
           Primop' ([v], SAY_CC, [k], selfe z G e)
         end

     | case_Primop z ({selfe, selfv, selft}, G) ([v], NATIVE { po, tys }, l, e) =
        let
          val tys = map (selft z G) tys
        in
          case Podata.potype po of
            { worlds = nil, tys = tvs, dom, cod } =>
              let
                val (argvs, _) = ListPair.unzip ` map (selfv z G) l

                val s = ListUtil.wed tvs tys
                fun dosub tt = foldr (fn ((tv, t), tt) => subtt t tv tt) tt s 

                (* val dom = map (dosub o ptoct) dom *)
                val cod = dosub ` ptoct cod

                (* no need to check args; typecheck does it *)

                val G = bindvar G v cod ` worldfrom G
              in
                Primop'([v], NATIVE { po = po, tys = tys }, argvs,
                        selfe z G e)
              end
          | _ => raise Pass "unimplemented: primops with world args"
        end

     | case_Primop z ({selfe, selfv, selft}, G) ([v], SAY_CC, [k], e) = raise Pass "unimplemented say_cc"

     | case_Primop z ({selfe, selfv, selft}, G) ([v], LOCALHOST, [], e) =
           Primop' ([v], LOCALHOST, [], 
                    selfe z (bindu0var G v ` Addr' ` worldfrom G) e)

     | case_Primop z ({selfe, selfv, selft}, G) ([v], BIND, [va], e) =
         let
           val (va, t) = selfv z G va
           val G = bindvar G v t ` worldfrom G
         in
           Primop' ([v], BIND, [va], selfe z G e)
         end

     (* not a closure call *)
     | case_Primop z ({selfe, selfv, selft}, G)  ([v], PRIMCALL { sym, dom, cod }, vas, e) =
         let
           val vas = map (fn v => #1 ` selfv z G v) vas
           val cod = (selft z G) cod
         in
           Primop'([v], PRIMCALL { sym = sym, dom = map (selft z G) dom, cod = cod }, vas,
                   selfe z (bindvar G v cod ` worldfrom G) e)
         end

          
  fun case_Leta z ({selfe, selfv, selft}, G) (v, va, e) =
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             At (t, w) => 
               Leta' (v, va, selfe z (bindvar G v t w) e)
           | _ => raise Pass "leta on non-at"
         end

(*
  fun case_Letsham z ({selfe, selfv, selft}, G) (v, va, e) =
    let val (va, t) = selfv z G va
    in
      case ctyp t of
        Shamrock t => Letsham' (v, va, selfe z (binduvar G v t) e)
      | _ => raise Closure "letsham on non-shamrock"
    end
*)

  fun case_Put z ({selfe, selfv, selft}, G) (v, va, e) =
         let
           val (va, t) = selfv z G va
           val G = bindu0var G v t
         in
           Put' (v, va, selfe z G e)
         end

  fun case_Go z ({selfe, selfv, selft}, G) (w, va, e) =
    let val (va, t) = selfv z G va
    in
      case ctyp t of
        Addr w' => Go' (w, va, selfe z (T.setworld G w) e)
      | _ => raise Pass "go to non-world"
    end

  fun case_Int z ({selfe, selfv, selft}, G) i = (Int' i, Zerocon' INT)
  fun case_String z ({selfe, selfv, selft}, G) i = (String' i, Zerocon' STRING)

  fun case_Record z ({selfe, selfv, selft}, G) lvl =
         let 
           val (l, v) = ListPair.unzip lvl
           val (v, t) = ListPair.unzip ` map (selfv z G) v
         in
           (Record' ` ListPair.zip (l, v),
            Product' ` ListPair.zip (l, t))
         end

  fun case_Var z ({selfe, selfv, selft}, G) v =
           (Var' v, #1 ` T.getvar G v)

  fun case_UVar z ({selfe, selfv, selft}, G) u =
    let val (w, t) = T.getuvar G u
    in
      (UVar' u, subwt (worldfrom G) w t)
    end

  fun case_Inj z ({selfe, selfv, selft}, G) (s, t, vo) =
    let val t = selft z G t
    in (Inj' (s, selft z G t, Option.map (fn va => let val (va, _) = selfv z G va
                                                   in va end) vo), t)
    end

  fun case_Hold z ({selfe, selfv, selft}, G) (w, va) =
         let
           val G = T.setworld G w
           val (va, t) = selfv z G va
         in
           (Hold' (w, va),
            At' (t, w))
         end


  fun case_Unroll z ({selfe, selfv, selft}, G) va =
         let
           val (va, t) = selfv z G va
         in
           case ctyp t of
            Mu (n, vtl) => (Unroll' va, CPSTypeCheck.unroll (n, vtl))
          | _ => raise Pass "unroll non-mu"
         end

  fun case_Roll z ({selfe, selfv, selft}, G) (t, va) =
         let
           val t = (selft z G) t
           val (va, _) = selfv z G va
         in
           (Roll' (t, va), t)
         end


  fun case_Proj z ({selfe, selfv, selft}, G) (l, va) =
         let val (va, t) = selfv z G va
         in
           case ctyp t of
              Product stl => (case ListUtil.Alist.find op= stl l of
                                NONE => raise Pass ("proj label " ^ l ^ " not in type")
                              | SOME t => (Proj' (l, va), t))
            | _ => raise Pass "proj on non-product"
         end

  fun case_VLeta z ({selfe, selfv, selft}, G)  (v, va, ve) =
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             At (tt, w) => let val G = bindvar G v tt w
                               val (ve, te) = selfv z G ve
                           in (VLeta' (v, va, ve), te)
                           end
           | _ => raise Pass "vleta on non-at"
         end

  fun case_Lams z ({selfe, selfv, selft}, G)  vael =
         let

           (* convert types *)
           val vael = map (fn (f, args, e) => (f, ListUtil.mapsecond (selft z G) args, e)) vael

           (* bind recursive vars *)
           val G = foldl (fn ((v, args, _), G) =>
                          bindvar G v (Cont' ` map #2 args) ` worldfrom G) G vael

           val vael = 
               map (fn (f, args, e) =>
                    let val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G args
                    in
                      (f, args, selfe z G e)
                    end) vael

         in
           (Lams' vael, 
            Conts' ` map (fn (_, args, _) => map #2 args) vael)
         end

  fun case_Fsel z ({selfe, selfv, selft}, G)  ( va, i ) =
        let val (va, t) = selfv z G va
        in
          case ctyp t of
            Conts tll => (Fsel' (va, i), Cont' ` List.nth (tll, i))
          | _ => raise Pass "fsel on non-conts"
        end


  fun case_AllLam z ({selfe, selfv, selft}, G)  { worlds, tys, vals, body } =
         let
           val G = bindworlds G worlds
           val G = bindtypes G tys
           val vals = ListUtil.mapsecond (selft z G) vals
           val G = foldl (fn ((v, t), G) => bindvar G v t (worldfrom G)) G vals
           val (body, tb) = selfv z G body
         in
           (AllLam' { worlds = worlds, tys = tys, vals = vals,
                      body = body },
            AllArrow' { worlds = worlds, tys = tys, vals = map #2 vals, 
                        body = tb })
         end

  fun case_AllApp z ({selfe, selfv, selft}, G)  { f, worlds, tys, vals } =
         let
           val (f, t) = selfv z G f
         in
           case ctyp t of
            AllArrow { worlds = ww, tys = tt, vals = vv, body = bb } =>
              let
                (* discard types; we'll use the annotations *)
                val vals = map #1 ` map (selfv z G) vals
                val tys = map (selft z G) tys
                val () = if length ww = length worlds andalso length tt = length tys
                         then () 
                         else raise Pass "allapp to wrong number of worlds/tys"
                val wl = ListPair.zip (ww, worlds)
                val tl = ListPair.zip (tt, tys)
                fun subt t =
                  let val t = foldr (fn ((wv, w), t) => subwt w wv t) t wl
                  in foldr (fn ((tv, ta), t) => subtt ta tv t) t tl
                  end

              in
                (AllApp' { f = f, worlds = worlds, tys = tys, vals = vals },
                 subt bb)
              end
          | _ => raise Pass "allapp to non-allarrow"
         end


  fun case_Dictfor z ({selfe, selfv, selft}, G) t =
         let val t = selft z G t
         in (Dictfor' t, Dictionary' t)
         end

(*

     | VLetsham (v, va, ve) =>
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             Shamrock tt => let val G = binduvar G v tt
                                val (ve, te) = selfv z G ve
                            in (VLetsham' (v, va, ve), te)
                            end
           | _ => raise Pass "vletsham on non-shamrock"
         end


     | Sham (w, va) =>
         let
           val G' = bindworld G w
           val G' = T.setworld G' (W w)

           val (va, t) = selfv z G' va
         in
           (Sham' (w, va),
            Shamrock' t)
         end

     | VTUnpack _ => raise Pass "wasn't expecting to see vtunpack before closure conversion"

     | _ => 
         let in
           print "CLOSURE: unimplemented val\n";
           Layout.print (CPSPrint.vtol value, print);
           raise Pass "unimplemented VAL"
         end

         )
           
*)

end

(* All this does is perform the case analysis and tie the knot. *)
functor PassFn(P : PASSARG) :> PASS =
struct
  open CPS
  open P
    
  fun convertv z G va =
    let val s = { selfv = convertv, selfe = converte, selft = convertt }
    in
      case cval va of
        Lams a => case_Lams z (s, G) a
      | Fsel a => case_Fsel z (s, G) a
      | Int a => case_Int z (s, G) a
      | String a => case_String z (s, G) a
      | Proj a => case_Proj z (s, G) a
      | Record a => case_Record z (s, G) a
      | Hold a => case_Hold z (s, G) a
      | WPack a => case_WPack z (s, G) a
      | TPack a => case_TPack z (s, G) a
      | Sham a => case_Sham z (s, G) a
      | Inj a => case_Inj z (s, G) a
      | Roll a => case_Roll z (s, G) a
      | Unroll a => case_Unroll z (s, G) a
      | Codelab a => case_Codelab z (s, G) a
      | Var a => case_Var z (s, G) a
      | UVar a => case_UVar z (s, G) a
      | WDictfor a => case_WDictfor z (s, G) a
      | WDict a => case_WDict z (s, G) a
      | Dictfor a => case_Dictfor z (s, G) a
      | Dict a => case_Dict z (s, G) a
      | AllLam a => case_AllLam z (s, G) a
      | AllApp a => case_AllApp z (s, G) a
      | VLeta a => case_VLeta z (s, G) a
      | VLetsham a => case_VLetsham z (s, G) a
      | VTUnpack a => case_VTUnpack z (s, G) a
    end

  and converte z G ex = 
    let
      val s = { selfv = convertv, selfe = converte, selft = convertt }
    in
      case cexp ex of
        Call a => case_Call z (s, G) a
      | Halt => case_Halt z (s, G)
      | Go a => case_Go z (s, G) a
      | Go_cc a => case_Go_cc z (s, G) a
      | Go_mar a => case_Go_mar z (s, G) a
      | Primop a => case_Primop z (s, G) a
      | Put a => case_Put z (s, G) a
      | Letsham a => case_Letsham z (s, G) a
      | Leta a => case_Leta z (s, G) a
      | WUnpack a => case_WUnpack z (s, G) a
      | TUnpack a => case_TUnpack z (s, G) a
      | Case a => case_Case z (s, G) a
      | ExternVal a => case_ExternVal z (s, G) a
      | ExternWorld a => case_ExternWorld z (s, G) a
      | ExternType a => case_ExternType z (s, G) a
    end

  and convertt z G ty =
    let
      val s = { selfv = convertv, selfe = converte, selft = convertt }
    in
      case ctyp ty of
        At a => case_At z (s, G) a
      | Cont a => case_Cont z (s, G) a
      | Conts a => case_Conts z (s, G) a
      | AllArrow a => case_AllArrow z (s, G) a
      | WExists a => case_WExists z (s, G) a
      | TExists a => case_TExists z (s, G) a
      | Product a => case_Product z (s, G) a
      | TWdict a => case_TWdict z (s, G) a
      | Addr a => case_Addr z (s, G) a
      | Mu a => case_Mu z (s, G) a
      | Sum a => case_Sum z (s, G) a
      | Primcon a => case_Primcon z (s, G) a
      | Shamrock a => case_Shamrock z (s, G) a
      | TVar a => case_TVar z (s, G) a
    end

end
