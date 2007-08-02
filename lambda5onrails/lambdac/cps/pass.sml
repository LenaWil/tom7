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

  fun case_Primop z ({selfe, selfv, selft}, G) ([v], SAY, [k], e) =>
         let
           val (k, t) = selfe z G k
           val G = bindvar G v (Zerocon' STRING) ` worldfrom G
         in
           Primop' ([v], SAY_CC, [k], selfe z G e)
         end

     | Primop ([v], SAY_CC, [k], e) => raise Closure "unexpected SAY_CC before closure conversion"

     | Primop ([v], NATIVE { po, tys }, l, e) =>
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
          | _ => raise Closure "unimplemented: primops with world args"
        end
(*      
     | Primop ([v], LOCALHOST, [], e) =>
           Primop' ([v], LOCALHOST, [], 
                    selfe z (binduvar G v ` Addr' ` worldfrom G) e)
           
     | Primop ([v], BIND, [va], e) =>
         let
           val (va, t) = selfv z G va
           val G = bindvar G v t ` worldfrom G
         in
           Primop' ([v], BIND, [va], selfe z G e)
         end
     (* not a closure call *)
     | Primop ([v], PRIMCALL { sym, dom, cod }, vas, e) =>
         let
           val vas = map (fn v => #1 ` selfv z G v) vas
           val cod = (selft z G) cod
         in
           Primop'([v], PRIMCALL { sym = sym, dom = map (selft z G) dom, cod = cod }, vas,
                   selfe z (bindvar G v cod ` worldfrom G) e)
         end
     | Leta (v, va, e) =>
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             At (t, w) => 
               Leta' (v, va, selfe z (bindvar G v t w) e)
           | _ => raise Closure "leta on non-at"
         end

     | Letsham (v, va, e) =>
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             Shamrock t => 
               Letsham' (v, va, selfe z (binduvar G v t) e)
           | _ => raise Closure "letsham on non-shamrock"
         end

     | Put (v, va, e) => 
         let
           val (va, t) = selfv z G va
           val G = binduvar G v t
         in
           Put' (v, va, selfe z G e)
         end

       (* go [w; a] e

           ==>

          go_cc [w; [[a]]; env; < envt cont >]
          *)
     | Go (w, addr, body) =>
         let
           val (addr, _) = selfv z G addr
           val body = selfe z (T.setworld G w) body

           val (fv, fuv) = freevarse body
           (* See case for Lams *)
           val fuv = augmentfreevars G (freesvarse body) fv fuv

           val { env, envt, wrape, wrapv } = mkenv G (fv, fuv)

           val envv = V.namedvar "go_env"

         in
           Go_cc' { w = w, 
                    addr = addr,
                    env = env,
                    f = Lam' (V.namedvar "go_unused",
                              [(envv, envt)],
                              wrape (Var' envv, body)) }
         end

     | _ =>
         let in
           print "CLOSURE: unimplemented exp:\n";
           Layout.print (CPSPrint.etol exp, print);
           raise Closure "unimplemented EXP"
         end
         )
       
  (* Convert the value v; 
     return the converted value paired with the converted type. *)
  and cv G value =
    (case cval value of
       Int _ => (value, Zerocon' INT)
     | String _ => (value, Zerocon' STRING)

     | Record lvl =>
         let 
           val (l, v) = ListPair.unzip lvl
           val (v, t) = ListPair.unzip ` map (selfv z G) v
         in
           (Record' ` ListPair.zip (l, v),
            Product' ` ListPair.zip (l, t))
         end

     | Var v => 
         let in
           (* print ("Lookup " ^ V.tostring v ^ "\n"); *)
           (value, #1 ` T.getvar G v)
         end
     | UVar v => 
         let in
           (* print ("Lookup " ^ V.tostring v ^ "\n"); *)
           (value, T.getuvar G v)
         end
     | Inj (s, t, vo) => let val t = (selft z G) t 
                         in (Inj' (s, (selft z G) t, Option.map (#1 o selfv z G) vo), t)
                         end
     | Hold (w, va) => 
         let
           val G = T.setworld G w
           val (va, t) = selfv z G va
         in
           (Hold' (w, va),
            At' (t, w))
         end

     | Unroll va =>
         let
           val (va, t) = selfv z G va
         in
           case ctyp t of
            Mu (n, vtl) => (Unroll' va, CPSTypeCheck.unroll (n, vtl))
          | _ => raise Closure "unroll non-mu"
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

     | Roll (t, va) => 
         let
           val t = (selft z G) t
           val (va, _) = selfv z G va
         in
           (Roll' (t, va), t)
         end

     | Proj (l, va) =>
         let val (va, t) = selfv z G va
         in
           case ctyp t of
              Product stl => (case ListUtil.Alist.find op= stl l of
                                NONE => raise Closure ("proj label " ^ l ^ " not in type")
                              | SOME t => (Proj' (l, va), t))
            | _ => raise Closure "proj on non-product"
         end

     | VLeta (v, va, ve) =>
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             At (tt, w) => let val G = bindvar G v tt w
                               val (ve, te) = selfv z G ve
                           in (VLeta' (v, va, ve), te)
                           end
           | _ => raise Closure "vleta on non-at"
         end

     | VLetsham (v, va, ve) =>
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             Shamrock tt => let val G = binduvar G v tt
                                val (ve, te) = selfv z G ve
                            in (VLetsham' (v, va, ve), te)
                            end
           | _ => raise Closure "vletsham on non-shamrock"
         end

     | Lams vael => 

     | Fsel (v, i) => 

     | VTUnpack _ => raise Closure "wasn't expecting to see vtunpack before closure conversion"

     (* must have at least one value argument or it's purely static and
        therefore not closure converted *)
     | AllLam { worlds, tys, vals = vals as _ :: _, body } => 

     (* ditto on the elim *)
     (* needs to remain a value... *)
     | AllApp { f, worlds, tys, vals = vals as _ :: _ } =>

     | Dictfor t => 
         let val t = (selft z G) t
         in (Dictfor' ` (selft z G) t, Dictionary' t)
         end

     | _ => 
         let in
           print "CLOSURE: unimplemented val\n";
           Layout.print (CPSPrint.vtol value, print);
           raise Closure "unimplemented VAL"
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
