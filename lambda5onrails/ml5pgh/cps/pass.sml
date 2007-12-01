(* Many passes in the CPS phase require type information,
   but only really care about changing a few constructs in
   CPS. PassFn is a functor that builds CPS transformation
   passes.

   To build a pass, provide a PASSARG. The passarg says how
   to transform each construct, given the typing context and
   open-recursive "selves" for values, types, and expressions.
   The typical way to do this is to start with IDPass (below)
   and reimplement only the cases that are relevant to the pass
   in question.
*)

(* note: we could avoid passing the stuff type by just making
   it polymorphic in the code below and declaring a stuff type
   of unit (or whatever). But then we would not be able to seal
   it against the PASSARG sig, because that would make the
   type monomorphic. *)
(* identity pass that sends along any 'stuff' untouched. *)
functor IDPass(type stuff
               val Pass : string -> exn) : PASSARG where type stuff = stuff =
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
  open CPS CPSUtil

  infixr 9 `
  fun a ` b = a b

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindu0var = T.bindu0var
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)


  (*    expressions    *)

  fun case_Call z (s as {selfv, selfe, selft}, G) (f, args) =
       let
         val (f, _) = selfv z G f
         val (args, _) = ListPair.unzip ` map (selfv z G) args
       in
         Call' (f, args)
       end
     
  fun case_Halt _ _ = Halt'

  fun case_ExternVal z (s as {selfv, selfe, selft}, G) (v, l, t, w, e) =
    let val t = selft z G t
    in ExternVal' (v, l, t, w, selfe z (bindvar G v t w) e)
    end

  fun case_ExternValid z (s as {selfv, selfe, selft}, G) (v, l, (wv, t), e) =
    let val t = selft z (bindworld G wv) t
    in ExternValid' (v, l, (wv, t), selfe z (binduvar G v (wv, t)) e)
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

  fun case_Intcase z ({selfe, selfv, selft}, G) (va, arms, def) =
    let
      val (va, t) = selfv z G va
    in
      case ctyp t of
        Primcon (CPS.INT, []) => Intcase' (va, ListUtil.mapsecond (selfe z G) arms, selfe z G def)
        | _ => raise Pass "intcase on non-int"
    end

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


  fun case_Native z ({selfe, selfv, selft}, G) { var = v, po, tys, args = l, bod = e } =
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
                Native' { var = v, po = po, tys = tys, args = argvs, bod = selfe z G e }
              end
          | _ => raise Pass "unimplemented: primops with world args"
        end

  fun Says F z ({selfe, selfv, selft}, G) (v, stl, k, e) =
         let
           val (k, t) = selfv z G k
           val G = bindvar G v (Zerocon' STRING) ` worldfrom G
         in
           F (v, stl, k, selfe z G e)
         end

  fun case_Say s = Says Say' s
  fun case_Say_cc s = Says Say_cc' s

  fun case_Primop z ({selfe, selfv, selft}, G) ([v], MARSHAL, [vd, va], e) =
         let
           val (vd, _) = selfv z G vd
           val (va, _) = selfv z G va
           (* don't bother checking the types; we always get
              the same result *)
           val G = bindvar G v (Zerocon' BYTES) ` worldfrom G
         in
           Primop' ([v], MARSHAL, [vd, va], selfe z G e)
         end
    | case_Primop z ({selfe, selfv, selft}, G) (_, MARSHAL, _, e) = raise Pass "bad marshal"

    | case_Primop z ({selfe, selfv, selft}, G) ([v], LOCALHOST, [], e) =
         Primop' ([v], LOCALHOST, [], 
                  selfe z (bindvar G v (Addr' ` worldfrom G) ` worldfrom G) e)

    | case_Primop z ({selfe, selfv, selft}, G) (_, LOCALHOST, _, e) = raise Pass "bad localhost"

    | case_Primop z ({selfe, selfv, selft}, G) ([v], BIND, [va], e) =
         let
           val (va, t) = selfv z G va
           val G = bindvar G v t ` worldfrom G
         in
           Primop' ([v], BIND, [va], selfe z G e)
         end
       
    | case_Primop z ({selfe, selfv, selft}, G) (_, BIND, _, _) = raise Pass "bad bind"
         

  fun case_Primcall z ({selfe, selfv, selft}, G)  { var = v, sym, dom, cod, args = vas, bod = e } =
    let
      val vas = map (fn v => let val (v, _) = selfv z G v
                             in v end) vas
    in
      Primcall' { var = v, sym = sym, 
                  dom = map (selft z G) dom, 
                  cod = selft z G cod, args = vas,
                  bod = selfe z (bindvar G v cod ` worldfrom G) e }
    end

          
  fun case_Leta z ({selfe, selfv, selft}, G) (v, va, e) =
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             At (t, w) => 
               Leta' (v, va, selfe z (bindvar G v t w) e)
           | _ => raise Pass "leta on non-at"
         end

  fun case_Letsham z ({selfe, selfv, selft}, G) (v, va, e) =
    let val (va, t) = selfv z G va
    in
      case ctyp t of
        Shamrock (w, t) => Letsham' (v, va, selfe z (binduvar G v (w,t)) e)
      | _ => raise Pass "letsham on non-shamrock"
    end

  fun case_Put z ({selfe, selfv, selft}, G) (v, va, e) =
         let
           val (va, t) = selfv z G va
           val G = bindu0var G v t
         in
           Put' (v, va, selfe z G e)
         end

  fun case_Newtag z ({selfe, selfv, selft}, G) (v, t, e) =
    let
      val t = selft z G t
      val G = bindvar G v (Primcon'(TAG, [t])) ` worldfrom G
    in
      Newtag'(v, t, selfe z G e)
    end

  fun case_Untag z ({selfe, selfv, selft}, G) { typ : ctyp, obj : cval, target : cval, bound : var, yes : cexp, no : cexp } =
    let
      val (obj, _) = selfv z G obj
      val (target, _) = selfv z G target
        
      val typ = selft z G typ
    in
      Untag' { typ = typ, 
               obj = obj,
               target = target,
               bound = bound,
               yes = selfe z (bindvar G bound typ ` worldfrom G) yes,
               no  = selfe z G no }
    end

  fun case_Go z ({selfe, selfv, selft}, G) (w, va, e) =
    let val (va, t) = selfv z G va
    in
      case ctyp t of
        Addr w' => Go' (w, va, selfe z (T.setworld G w) e)
      | _ => raise Pass "go to non-world"
    end

  fun case_Go_mar z ({selfe, selfv, selft}, G) { w, addr, bytes } =
    let
      val (addr, _) = selfv z G addr
      val (bytes, _) = selfv z G bytes
    in
      Go_mar' { w = w, addr = addr, bytes = bytes }
    end

  fun case_Go_cc z ({selfe, selfv, selft}, G) { w, addr = va, env, f = bod } =
    let
      val (va, tv) = selfv z G va
      val (env, envt) = selfv z (T.setworld G w) env
      val (bod, bodt) = selfv z (T.setworld G w) bod
    in
      Go_cc' { w = w, addr = va, env = env, f = bod }
    end

  fun case_TUnpack z ({selfe, selfv, selft}, G) (tv, td, vvs, va, ve) =
    let
      val (va, t) = selfv z G va
    in
      case ctyp t of
        TExists (vr, tl) =>
          let
            val tl = map (subtt (TVar' tv) vr) tl
              
            (* new type, can't be mobile *)
            val G = bindtype G tv false
            val vvs = ListUtil.mapsecond (selft z G) vvs
              
            val vs = map #2 vvs
            (* the dict *)
            val G = bindu0var G td ` Dictionary' ` TVar' tv
            (* some values now *)
            val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vvs
          in
            TUnpack' (tv, td, vvs, va, selfe z G ve)
          end
      | _ => raise Pass "tunpack non-exists"
    end

  fun case_TPack z ({selfe, selfv, selft}, G) (t, tas, vd, vs) =
    let
      val tas = selft z G tas
      val (vd, _) = selfv z G vd
      val (vs, _) = ListPair.unzip ` map (selfv z G) vs
    in
      (TPack' (t, tas, vd, vs),
       (* assume annoation is correct *)
       tas)
    end

  fun case_WUnpack _ _ _ = raise Pass "unimplemented wunpack"
  fun case_Codelab _ _ _ = raise Pass "unimplemented Codelab (need to implement transformprogram)"




  (*     values    *)

  fun case_WPack _ _ _ = raise Pass "unimplemented wpack"

  fun case_Int z ({selfe, selfv, selft}, G) i = (Int' i, Zerocon' INT)
  fun case_String z ({selfe, selfv, selft}, G) s = (String' s, Zerocon' STRING)


  fun case_Tagged z ({selfe, selfv, selft}, G) (va, vt) =
    let
      val (va, tt) = selfv z G va
      val (vat, ttt) = selfv z G vt
    in
      (Tagged' (va, vat), Zerocon' EXN)
    end

  fun case_Inline z ({selfe, selfv, selft}, G) va =
    let
      val (va, tt) = selfv z G va
    in
      (Inline' va, tt)
    end

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
                  let val t = foldr (fn ((tv, ta), t) => subtt ta tv t) t tl
                  in foldr (fn ((wv, w), t) => subwt w wv t) t wl
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

  fun case_WDictfor z ({selfe, selfv, selft}, G) w = (WDictfor' w, TWdict' w)
  fun case_WDict z ({selfe, selfv, selft}, G) w = (WDict' w, TWdict' ` WC' w)

  (* yowza. *)

  (* bound dictionaries (uvars) should not use the bound world variable
     in the validity hypothesis. *)
  fun case_Dict z ({selfe, selfv, selft}, G) tf =
     let
       fun edict' s (Primcon(DICTIONARY, [t])) = t
         | edict' s _ = raise Pass (s ^ " dict with non-dicts inside")
       fun ewdict' s (TWdict w) = w
         | ewdict' s _ = raise Pass (s ^ " wdict with non-dicts inside")

       fun edict s t = edict' s ` ctyp t
       fun ewdict s t = ewdict' s ` ctyp t
     in
       case tf of
          Primcon(pc, dl) =>
            let
              val (dl, tl) = ListPair.unzip ` map (selfv z G) dl
              val ts = map (edict "primcon") tl
            in
              (Dict' ` Primcon (pc, dl), Dictionary' ` Primcon'(pc, tl))
            end
        | Product sdl =>
            let
              val (ss, ds) = ListPair.unzip sdl
              val (ds, ts) = ListPair.unzip ` map (selfv z G) ds
              val stl = ListPair.zip (ss, ts)
              val sdl = ListPair.zip (ss, ds)
            in
              (Dict' ` Product sdl, Dictionary' ` Product' stl)
            end

        | Sum sdl =>
            let
              val (ss, ds) = ListPair.unzip sdl
              val (ds, ts) = ListPair.unzip ` map (fn NonCarrier => (NonCarrier, NonCarrier)
                                                    | Carrier { carried, definitely_allocated } => 
                                                   let val (cd, ct) = selfv z G carried
                                                   in
                                                     (Carrier 
                                                      { carried = cd, 
                                                        definitely_allocated = definitely_allocated },
                                                      Carrier
                                                      { carried = ct,
                                                        definitely_allocated = definitely_allocated })
                                                   end) ds
              val stl = ListPair.zip (ss, ts)
              val sdl = ListPair.zip (ss, ds)
            in
              (Dict' ` Sum sdl, Dictionary' ` Sum' stl)
            end

        | TWdict w =>
            let
              val (w, t) = selfv z G w
            in
              (Dict' ` TWdict w,
               Dictionary' ` TWdict' ` ewdict "twdict" t)
            end
            

        | Shamrock ((w, dw), d) => 
            let
              val G = bindworld G w
              val G = bindu0var G dw (TWdict' ` W' w)
              val (d, t) = selfv z G d
            in
              (Dict' ` Shamrock ((w, dw), d),
               Dictionary' ` Shamrock' (w, edict "sham" t))
            end

        | Cont dl => 
            let
              val (dl, tl) = ListPair.unzip ` map (selfv z G) dl
            in
              (Dict' ` Cont dl,
               Dictionary' ` Cont' ` map (edict "cont") tl)
            end

        | Conts dll => 
            let
              fun one dl =
                let
                  val (dl, tl) = ListPair.unzip ` map (selfv z G) dl
                in
                  (dl, map (edict "conts") tl)
                end
              val (dll, tll) = ListPair.unzip ` map one dll
            in
              (Dict' ` Conts dll,
               Dictionary' ` Conts' tll)
            end

        | Addr w => 
            let val (w, t) = selfv z G w
            in
              (Dict' ` Addr w, Dictionary' ` Addr' (ewdict "addr" t))
            end
        | At (d, w) => 
            let
              val (d, t) = selfv z G d
              val (w, tw) = selfv z G w
            in
              (Dict' ` At (d, w),
               Dictionary' ` At' (edict "at" t, ewdict "at" tw))
            end

        | TExists((v1, v2), vl) =>
            let
              val G = bindtype G v1 false
              val G = bindu0var G v2 (Dictionary' ` TVar' v1)

              val (dl, tl) = ListPair.unzip ` map (selfv z G) vl
            in
              (Dict' ` TExists((v1, v2), dl),
               Dictionary' ` TExists' (v1, map (edict "texists") tl))
            end

        | Mu (n, arms) =>
            let
              val G = foldr (fn (((vt, vd), _), G) =>
                             let
                               val G = bindtype G vt false
                               val G = bindu0var G vd ` Dictionary' ` TVar' vt
                             in
                               G
                             end) G arms
              fun one ((vt, v), x) =
                let val (x, t) = selfv z G x
                in
                  ((vt, edict "mu" t), ((vt, v), x))
                end

              val (tarms, darms) = ListPair.unzip ` map one arms
            in
              (Dict' ` Mu(n, darms),
               Dictionary' ` Mu' (n, tarms))
            end

        | AllArrow { worlds, tys, vals, body } =>
            let
              val G = bindworlds G (map #1 worlds)
              val G = foldr (fn ((v1, v2), G) => bindu0var G v2 (TWdict' ` W' v1)) G worlds
              val G = foldr (fn ((v1, _), G) => bindtype G v1 false) G tys
              val G = foldr (fn ((v1, v2), G) => bindu0var G v2 (Dictionary' ` TVar' v1)) G tys

              val (vals, valts) = ListPair.unzip ` map (selfv z G) vals
              val (body, bodyt) = selfv z G body
            in
              (Dict' ` AllArrow { worlds = worlds, tys = tys, vals = vals, body = body },
               Dictionary' ` AllArrow' { worlds = map #1 worlds, tys = map #1 tys,
                                         vals = map (edict "allarrow") valts,
                                         body = edict "allarrow-body" bodyt })
            end

        | _ => 
            let in
              print "\n\nunimplemented:\n";
              Layout.print(CPSPrint.vtol (Dict' tf), print);
              print "\n\n";
              raise Pass "unimplemented dict typefront"
            end
     end

   fun case_VTUnpack z ({selfe, selfv, selft}, G)  (tv, td, vvs, va, ve) =
     let
       val (va, t) = selfv z G va
     in
       case ctyp t of
         TExists (vr, tl) =>
           let
             val tl = map (subtt (TVar' tv) vr) tl
               
             (* new type, can't be mobile *)
             val G = bindtype G tv false
             val vvs = ListUtil.mapsecond (selft z G) vvs

             val vs = map #2 vvs
             (* the dict *)
             val G = bindu0var G td ` Dictionary' ` TVar' tv
             (* some values now *)
             val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vvs
               
             val (ve, et) = selfv z G ve
           in
             (VTUnpack' (tv, td, vvs, va, ve),
              (* better not use tv *)
              et)
           end
       | _ => raise Pass "vtunpack non-exists"
     end


   fun case_Sham z ({selfe, selfv, selft}, G)  (w, va) =
     let
       val G = bindworld G w
       val G = T.setworld G (W' w)
         
       val (va, t) = selfv z G va
     in
       (Sham' (w, va), Shamrock' (w, t))
     end


   fun case_VLetsham z ({selfe, selfv, selft}, G)  (v, va, ve) =
         let val (va, t) = selfv z G va
         in
           case ctyp t of
             Shamrock (w, tt) => let val G = binduvar G v (w, tt)
                                     val (ve, te) = selfv z G ve
                                 in (VLetsham' (v, va, ve), te)
                                 end
           | _ => raise Pass "vletsham on non-shamrock"
         end

   (*     types     *)

   fun case_At z ({selfe, selfv, selft}, G) (c, w) = At'(selft z G c, w)
   fun case_Cont z ({selfe, selfv, selft}, G) l = Cont' ` map (selft z G) l
   fun case_Conts z ({selfe, selfv, selft}, G) l = Conts' ` map (map (selft z G)) l
   fun case_AllArrow z ({selfe, selfv, selft}, G)  {worlds, tys, vals, body} =
        let 
          val G = bindworlds G worlds
          val G = bindtypes G tys
        in 
          AllArrow' { worlds = worlds, tys = tys,
                      vals = map (selft z G) vals,
                      body = selft z G body }
        end

   fun case_WExists z ({selfe, selfv, selft}, G) (v, t) = WExists' (v, selft z (bindworld G v) t)
   fun case_TExists z ({selfe, selfv, selft}, G) (v, t) = 
     let val G = bindtype G v false
     in TExists' (v, map (selft z G) t)
     end

   fun case_Product z ({selfe, selfv, selft}, G) stl = Product' ` ListUtil.mapsecond (selft z G) stl
   fun case_TVar z ({selfe, selfv, selft}, G) v = TVar' v
   fun case_TWdict z _ w = TWdict' w
   fun case_Addr z _ w = Addr' w
   fun case_Mu z ({selfe, selfv, selft}, G) (i, vtl) =
        let val n = length vtl
        in Mu'(i, map (fn (v, t) => (v, selft z (bindtype G v false) t)) vtl)
        end

   fun case_Primcon z ({selfe, selfv, selft}, G) (BYTES, []) = Zerocon' BYTES
     | case_Primcon z ({selfe, selfv, selft}, G) (VEC, [t]) = Primcon' (VEC, [selft z G t])
     | case_Primcon z ({selfe, selfv, selft}, G) (REF, [t]) = Primcon' (REF, [selft z G t])
     | case_Primcon z ({selfe, selfv, selft}, G) (DICTIONARY, [t]) = Primcon' (DICTIONARY, [selft z G t])
     | case_Primcon z ({selfe, selfv, selft}, G) (INT, []) = Zerocon' INT
     | case_Primcon z ({selfe, selfv, selft}, G) (STRING, []) = Zerocon' STRING
     | case_Primcon z ({selfe, selfv, selft}, G) (EXN, []) = Zerocon' EXN
     | case_Primcon z ({selfe, selfv, selft}, G) (TAG, [t]) = Primcon' (TAG, [selft z G t])
     | case_Primcon _ _ (BYTES, _)      = raise Pass "bad primcon"
     | case_Primcon _ _ (VEC, _)        = raise Pass "bad primcon"
     | case_Primcon _ _ (REF, _)        = raise Pass "bad primcon"
     | case_Primcon _ _ (DICTIONARY, _) = raise Pass "bad primcon"
     | case_Primcon _ _ (INT, _)        = raise Pass "bad primcon"
     | case_Primcon _ _ (STRING, _)     = raise Pass "bad primcon"
     | case_Primcon _ _ (EXN, _)        = raise Pass "bad primcon"
     | case_Primcon _ _ (TAG, _)        = raise Pass "bad primcon"


   fun case_Shamrock z ({selfe, selfv, selft}, G) (w, t) = Shamrock' (w, selft z (bindworld G w) t)

   fun case_Sum z ({selfe, selfv, selft}, G) sail =
     Sum' ` ListUtil.mapsecond (IL.arminfo_map ` selft z G) sail


end

(* All this does is perform the case analysis and tie the knot. *)
functor PassFn(P : PASSARG) :> PASS where type stuff = P.stuff =
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
      | Inline a => case_Inline z (s, G) a
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
      | Tagged a => case_Tagged z (s, G) a
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
      | Native a => case_Native z (s, G) a
      | Primcall a => case_Primcall z (s, G) a
      | Intcase a => case_Intcase z (s, G) a
      | Case a => case_Case z (s, G) a
      | ExternVal a => case_ExternVal z (s, G) a
      | ExternValid a => case_ExternValid z (s, G) a
      | ExternWorld a => case_ExternWorld z (s, G) a
      | ExternType a => case_ExternType z (s, G) a
      | Say a => case_Say z (s, G) a
      | Say_cc a => case_Say_cc z (s, G) a
      | Newtag a => case_Newtag z (s, G) a
      | Untag a => case_Untag z (s, G) a
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
