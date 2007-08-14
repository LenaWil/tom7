structure CPS :> CPS =
struct
  
  structure V = Variable
  type var = V.var
  infixr 9 `
  fun a ` b = a b

  exception CPS of string

  datatype arminfo = datatype IL.arminfo
  datatype world = W of var | WC of string

  datatype worldkind = datatype IL.worldkind

  datatype primcon = VEC | REF | DICTIONARY | INT | STRING | EXN | BYTES

  datatype ('tbind, 'ctyp, 'wbind, 'world) ctypfront =
      At of 'ctyp * 'world
    | Cont of 'ctyp list
    | Conts of 'ctyp list list
    | AllArrow of { worlds : 'wbind list, tys : 'tbind list, vals : 'ctyp list, body : 'ctyp }
    | WExists of 'wbind * 'ctyp
    | TExists of 'tbind * 'ctyp list
    | Product of (string * 'ctyp) list
    (* the type of a representation of this world *)
    | TWdict of 'world
    | Addr of 'world
    (* all variables bound in all arms *)
    | Mu of int * ('tbind * 'ctyp) list
    | Sum of (string * 'ctyp IL.arminfo) list
    | Primcon of primcon * 'ctyp list
    | Shamrock of 'wbind * 'ctyp
    | TVar of var
  (* nb. Binders must be implemented in outjection code below! *)

  datatype ctyp = T of (var, ctyp, var, world) ctypfront

  datatype primop = 
      LOCALHOST 
    | BIND 
    | PRIMCALL of { sym : string, dom : ctyp list, cod : ctyp }
    | NATIVE of { po : Primop.primop, tys : ctyp list }
    | MARSHAL 
    | SAY | SAY_CC

  datatype ('cexp, 'cval) cexpfront =
      Call of 'cval * 'cval list
    | Halt
    | Go of world * 'cval * 'cexp
    | Go_cc of { w : world, addr : 'cval, env : 'cval, f : 'cval }
    | Go_mar of { w : world, addr : 'cval, bytes : 'cval }
    | Primop of var list * primop * 'cval list * 'cexp
    | Put of var * 'cval * 'cexp
    | Letsham of var * 'cval * 'cexp
    | Leta of var * 'cval * 'cexp
    (* world var, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    | TUnpack of var * var * (var * ctyp) list * 'cval * 'cexp
    (* contents var only bound in arms, not default *)
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of string * worldkind * 'cexp
    | ExternType of var * string * (var * string) option * 'cexp
  (* nb. Binders must be implemented in outjection code below! *)

  and ('cexp, 'cval) cvalfront =
      Lams of (var * (var * ctyp) list * 'cexp) list
    | Fsel of 'cval * int
    | Int of IntConst.intconst
    | String of string
    | Record of (string * 'cval) list
    | Proj of string * 'cval
    | Hold of world * 'cval
    | WPack of world * 'cval
    | TPack of ctyp * ctyp * 'cval * 'cval list
    | Sham of var * 'cval
    | Inj of string * ctyp * 'cval option
    | Roll of ctyp * 'cval
    | Unroll of 'cval
    | Codelab of string
    | Var of var
    | UVar of var
    | WDictfor of world
    | WDict of string
    | Dictfor of ctyp
    | Dict of (var * var, 'cval, var * var, 'cval) ctypfront
    | AllLam of { worlds : var list, tys : var list, vals : (var * ctyp) list, body : 'cval }
    | AllApp of { f : 'cval, worlds : world list, tys : ctyp list, vals : 'cval list }
    | VLeta of var * 'cval * 'cval
    | VLetsham of var * 'cval * 'cval
    | VTUnpack of var * var * (var * ctyp) list * 'cval * 'cval
  (* nb. Binders must be implemented in outjection code below! *)

  datatype ('cexp, 'cval) cglofront =
      PolyCode of var * 'cval * ctyp (* @ var *)
    | Code of 'cval * ctyp * string
    
  (* CPS expressions *)
  datatype cexp = E of (cexp, cval) cexpfront
  and      cval = V of (cexp, cval) cvalfront
   
  type     cglo =      (cexp, cval) cglofront

  type program  = { 
                    (* The world constants. *)
                    worlds : (string * worldkind) list,
                    (* The globals (hoisted code). Before hoisting,
                       there is usually only the main *)
                    globals : (string * cglo) list,
                    (* The entry point for the program. *)
                    main : string

                    }

  datatype substitutend = 
      SV of cval
    | ST of ctyp
    | SW of world
    | SU of var
    (* occurrence-driven; if we ask for a value, we get Var v
       if we ask for a type, we get TVar v. *)
    | S_RENAME of var

  fun se_getv (SV (V v)) = v 
    | se_getv (S_RENAME v) = Var v
    | se_getv _ = raise CPS "scope violated: wanted val"
  fun se_getu (SU u) = u 
    | se_getu (S_RENAME u) = u
    | se_getu _ = raise CPS "scope violated: wanted uvar"
  fun se_gett (ST (T t)) = t
    | se_gett (S_RENAME v) = TVar v
    | se_gett _ = raise CPS "scope violated: wanted type"
  fun se_getw (SW w) = w 
    | se_getw (S_RENAME v) = W v
    | se_getw _ = raise CPS "scope violated: wanted world"


  fun substw v se (W vv) = if V.eq (v, vv) then se_getw se else W vv
    | substw _ _  (w as WC l) = w

  (* substitute through a type front.
     v is the variable to substitute for, se is the
                                          substitutend. 
     typ is the type front to substitute through.

     upon seeing a variable, calls var_action (which should
     return the replacement if it's the right variable).
     
     recurses on component types by calling the argument 'self'

     tbinds : var -> 'tbind -> bool indicates whether the 'tbind
              binds the variable in question.

     the function substt below has a much nicer interface;
     however, we need this more abstract version so that we
     can implement substitution for dictionary values, which
     use the same datatype.

     XXX use record for these crazy args
     *)
  and substtfront v se typ var_action tbinds self wbinds wself =
    let 
      fun veq v1 v2 = V.eq(v1, v2)
    in
      case typ of
         At (t, w) => At (self t, wself w)
       | Cont l => Cont (map self l)
       | AllArrow { worlds, tys, vals, body } => 
             if List.exists (wbinds v) worlds orelse
                List.exists (tbinds v) tys
             then typ
             else AllArrow { worlds = worlds,
                             tys = tys,
                             vals = map self vals,
                             body = self body }
       | WExists (vv, t) => if wbinds v vv then typ
                            else WExists(vv, self t)
       | TExists (tb, t) => if tbinds v tb then typ
                            else TExists(tb, map self t)
       | Product stl => Product ` ListUtil.mapsecond self stl
       | TWdict w => TWdict (wself w)
       | Addr w => Addr (wself w)
       | Mu (i, vtl) => if List.exists (fn (tb, _) => tbinds v tb) vtl
                        then typ
                        else Mu (i, ListUtil.mapsecond self vtl)
       | Sum sal => Sum (map (fn (s, NonCarrier) => (s, NonCarrier)
                               | (s, Carrier { definitely_allocated, carried }) => 
                              (s, Carrier { definitely_allocated = definitely_allocated,
                                            carried = self carried })) sal)
       | Primcon (pc, l) => Primcon (pc, map self l)
       | Conts ll => Conts ` map (map self) ll
       | Shamrock (vv, t) => if wbinds v vv
                             then typ
                             else Shamrock (vv, self t)
       | TVar vv => var_action vv
    end

  (* PERF if substitutend is exp or val, stop early *)
  (* substitute var v with type se in a type, observing scope *)
  fun substt v se (T typ) = 
    T (substtfront v se typ (fn vv => if V.eq (v, vv) then se_gett se else TVar vv)
       (* how to handle type binders (vars), types, world binders (vars), worlds: *)
       (Util.curry V.eq)
       (substt v se)
       (Util.curry V.eq)
       (substw v se)
       )

  (* substitute se for v throughout the expression exp *)
  fun subste v se (E exp) =
    let val eself = subste v se
        val vself = substv v se
        val wself = substw v se
        val tself = substt v se
    in
      E
      (case exp of
         Call (v, vl) => Call (vself v, map vself vl)
       | Halt => exp
       | Go (w, va, e) => Go (wself w, vself va, eself e)
       | Go_cc { w, addr, env, f } => Go_cc { w = wself w, 
                                              addr = vself addr, 
                                              env = vself env,
                                              f = vself f }
       | Go_mar { w, addr, bytes } => Go_mar { w = wself w, 
                                               addr = vself addr, 
                                               bytes = vself bytes }
       | Primop (vvl, po, vl, ce) =>
           let fun poself LOCALHOST = LOCALHOST
                 | poself BIND = BIND
                 | poself MARSHAL = MARSHAL
                 | poself SAY = SAY
                 | poself SAY_CC = SAY_CC
                 | poself (NATIVE { po, tys }) = NATIVE { po = po, tys = map tself tys }
                 | poself (PRIMCALL { sym, dom, cod }) = PRIMCALL { sym = sym,
                                                                    dom = map tself dom,
                                                                    cod = tself cod }
           in
             Primop (vvl, poself po, map vself vl,
                     if List.exists (fn vv => V.eq (vv, v)) vvl
                     then ce
                     else eself ce)
           end
       | Put (vv, va, e) =>
           Put (vv, vself va,
                if V.eq(vv, v)
                then e
                else eself e)
       | Letsham (vv, va, e) =>
           Letsham (vv, vself va,
                    if V.eq(vv, v)
                    then e
                    else eself e)
       | Leta (vv, va, e) =>
           Leta (vv, vself va,
                 if V.eq(vv, v)
                 then e
                 else eself e)
       | WUnpack (vv1, vv2, va, e) =>
           WUnpack (vv1, vv2, vself va,
                    if V.eq(vv1, v) orelse V.eq (vv2, v)
                    then e
                    else eself e)
       | TUnpack (vv1, vd, vvl, va, e) =>
           TUnpack (vv1, 
                    vd,
                    if V.eq(vv1, v) then vvl else ListUtil.mapsecond tself vvl, 
                    vself va,
                    if V.eq(vv1, v) 
                       orelse V.eq (vd, v) 
                       orelse List.exists (fn (vv, _) => V.eq (vv, v)) vvl
                    then e
                    else eself e)
       | Case (va, vv, sel, e) =>
           Case (vself va, vv,
                 if V.eq(vv, v) then sel
                 else ListUtil.mapsecond eself sel,
                 eself e)
       | ExternWorld (s, k, e) => ExternWorld (s, k, eself e)
       | ExternType (vv, s, vso, e) =>
           ExternType (vv, s, vso, if V.eq (vv, v) 
                                     orelse (case vso of SOME (vvv, _) => V.eq (vvv, v)
                                                                   | _ => false)
                                   then e else eself e)

       | ExternVal (vv, s, t, wo, e) =>
           ExternVal (vv, s, tself t, Option.map wself wo,
                      if V.eq (vv, v) then e else eself e)
           )
    end

  and substv v se (V value) =
    let val eself = subste v se
        val vself = substv v se
        val wself = substw v se
        val tself = substt v se
        fun issrc vv = V.eq (v, vv)
    in
      V (case value of
           Int i => value
         | String s => value
         | Record svl => Record ` ListUtil.mapsecond vself svl
         | Proj (s, va) => Proj (s, vself va)
         | Hold (w, va) => Hold (wself w, vself va)

         | AllLam { worlds, tys, vals, body } => 
               if List.exists issrc worlds orelse
                  List.exists issrc tys 
               then value 
               else 
                 (* if bound as a value var, then we'll still substitute
                    through those types but not the body *)
                 if List.exists (issrc o #1) vals
                 then AllLam { worlds = worlds, tys = tys, 
                               vals = 
                               ListUtil.mapsecond tself vals, body = body }
                 else AllLam { worlds = worlds, tys = tys, 
                               vals = ListUtil.mapsecond tself vals, 
                               body = vself body }

         | VLetsham (vv, va, ve) =>
                   VLetsham (vv, vself va,
                             if V.eq(vv, v)
                             then ve
                             else vself ve)

         | VLeta (vv, va, ve) =>
                   VLeta (vv, vself va,
                          if V.eq(vv, v)
                          then ve
                          else vself ve)
         | AllApp { f, worlds, tys, vals } => AllApp { f = vself f, worlds = map wself worlds,
                                                       tys = map tself tys, vals = map vself vals }
         | WPack (w, va) => WPack (wself w, vself va)
         | TPack (t, t2, v, va) => TPack (tself t, tself t2, vself v, map vself va)
         | Var vv => if V.eq(v, vv) then se_getv se else Var vv
         | UVar vv => UVar (if V.eq(v, vv) then se_getu se else vv)
         | Unroll va => Unroll (vself va)
         | Codelab s => Codelab s
         | Roll (t, va) => Roll (tself t, vself va)
         | WDictfor w => WDictfor ` wself w
         | WDict s => WDict s
         | Dictfor t => Dictfor ` tself t

         | Dict tf => Dict (substtfront v se tf (fn _ =>
                                                 raise CPS "dictionaries should not have tvars!")
                             (* tbinds are just two variables here, typs are vals *)
                             (fn v1 => fn (v2, v3) => V.eq (v1, v2) orelse V.eq (v1, v3)) vself
                             (* ditto wbinds, worlds *)
                             (fn v1 => fn (v2, v3) => V.eq (v1, v2) orelse V.eq (v1, v3)) vself
                             )

         | VTUnpack (vv1, vd, vvl, va, ve) =>
                  VTUnpack (vv1, 
                            vd,
                            if V.eq(vv1, v) then vvl else ListUtil.mapsecond tself vvl, 
                            vself va,
                            if V.eq(vv1, v) 
                               orelse V.eq(vd, v)
                               orelse List.exists (fn (vv, _) => V.eq (vv, v)) vvl
                            then ve
                            else vself ve)

         | Sham (w, va) => if V.eq(v, w) 
                           then value
                           else Sham (w, vself va)
         | Fsel (va, i) => Fsel (vself va, i)
         | Inj (s, t, va) => Inj (s, tself t, Option.map vself va)
         | Lams vvel => Lams ` map (fn (vv, vvl, ce) => 
                                    (vv, 
                                     ListUtil.mapsecond tself vvl,
                                     if List.exists (fn (vv, _) => V.eq (vv, v)) vvl
                                        orelse
                                        List.exists (fn (vv, _, _) => V.eq (vv, v)) vvel
                                     then ce
                                     else eself ce)) vvel
           )
    end

  fun renamet v v' t = substt v (S_RENAME v') t
  fun renamee v v' e = subste v (S_RENAME v') e
  fun renamew v v' w = substw v (S_RENAME v') w
  fun renamev v v' l = substv v (S_RENAME v') l

  val renameeall = foldl (fn ((v,v'), e) => renamee v v' e)
  val renametall = foldl (fn ((v,v'), e) => renamet v v' e)

  (* when exposing a binder, we alpha-vary. *)
  fun ctyp (T(AllArrow {worlds, tys, vals, body})) = let val worlds' = ListUtil.mapto V.alphavary worlds
                                                         val tys'    = ListUtil.mapto V.alphavary tys
                                                         fun rent t = renametall (renametall t worlds') tys'
                                                     in 
                                                         AllArrow { worlds = map #2 worlds',
                                                                    tys    = map #2 tys',
                                                                    vals   = map rent vals,
                                                                    body   = rent body }
                                                     end

    | ctyp (T(WExists (v, t))) = let val v' = V.alphavary v
                                 in WExists (v', renamet v v' t)
                                 end
    | ctyp (T(TExists (v, t))) = let val v' = V.alphavary v
                                 in TExists (v', map (renamet v v') t)
                                 end

    | ctyp (T(Shamrock (v, t))) = let val v' = V.alphavary v
                                  in Shamrock (v', renamet v v' t)
                                  end

    | ctyp (T(Mu(i, vtl))) = let val (vs, ts) = ListPair.unzip vtl
                                 val tys = ListUtil.mapto V.alphavary vs
                                 fun rent t = renametall t tys
                                 val vtl = ListPair.zip (map #2 tys, map rent ts)
                             in
                                 Mu(i, vtl)
                             end
     (* 
        
        *** NOTE: ***
        
        Also have to implement type front binders in their value representations;
        see V(Dict(...)) below!


        *)
    | ctyp (T x) = x

  fun cexp (E(Primop(vvl, po, vl, e))) = 
                                    let val vs = ListUtil.mapto V.alphavary vvl
                                    in Primop(map #2 vs, po, vl,
                                              renameeall e vs)
                                    end
    | cexp (E(Put(v, va, e))) = let val v' = V.alphavary v
                                in Put(v', va, renamee v v' e)
                                end
    | cexp (E(Letsham(v, va, e))) = let val v' = V.alphavary v
                                    in Letsham(v', va, renamee v v' e)
                                    end
    | cexp (E(Leta(v, va, e))) = let val v' = V.alphavary v
                                 in Leta(v', va, renamee v v' e)
                                 end

    | cexp (E(WUnpack(v1, v2, va, e))) = let val v1' = V.alphavary v1
                                             val v2' = V.alphavary v2
                                         in WUnpack(v1', v2', va, renamee v2 v2' ` renamee v1 v1' e)
                                         end
    | cexp (E(TUnpack(v1, vd, vtl, va, e))) = 
                                         let 
                                           val v1' = V.alphavary v1
                                           val vd' = V.alphavary vd
                                           val (v2l, t2l) = ListPair.unzip vtl
                                           val t2l = map (renamet v1 v1') t2l
                                           val v2l' = ListUtil.mapto V.alphavary v2l
                                         in TUnpack(v1', vd', ListPair.zip(map #2 v2l', t2l), 
                                                    va, 
                                                    renamee vd vd' ` renameeall (renamee v1 v1' e) v2l')
                                         end
    | cexp (E(Case(va, v, sel, def))) = let val v' = V.alphavary v
                                        in
                                          Case(va, v', ListUtil.mapsecond (renamee v v') sel,
                                               def)
                                        end

    | cexp (E(ExternVal(vv, s, t, wo, e))) = let val v' = V.alphavary vv
                                             in ExternVal(v', s, t, wo, renamee vv v' e)
                                             end

    | cexp (E(ExternType(vv, s, NONE, e))) = let val v' = V.alphavary vv
                                             in ExternType(v', s, NONE, renamee vv v' e)
                                             end
    | cexp (E(ExternType(vv, s, SOME (v2, s2), e))) = let val v' = V.alphavary vv
                                                          val v2' = V.alphavary v2
                                                      in ExternType(v', s, SOME (v2', s2), 
                                                                    renamee v2 v2' ` renamee vv v' e)
                                                      end

    | cexp (E x) = x


  val renamevall = foldl (fn ((v,v'), e) => renamev v v' e)

  fun cval (V (Lams vael)) = let val fs = map (fn (v, a, e) => 
                                               (v, V.alphavary v, a, e)) vael
                             in
                               Lams (map (fn (v, v', at, e) =>
                                          let 
                                            val (a, t) = ListPair.unzip at
                                            val a' = ListUtil.mapto V.alphavary a
                                          in
                                            (v', 
                                             ListPair.zip(map #2 a', t),
                                             foldl (fn ((v, v'), e) => renamee v v' e) e
                                             (* function names @ these args *)
                                             ((map (fn (v, v', _, _) => (v, v')) fs) @ a')
                                             )
                                          end) fs)
                             end
    | cval (V(VTUnpack(v1, vd, vtl, va, ve))) = 
                             let 
                               val v1' = V.alphavary v1
                               val vd' = V.alphavary vd
                               val (v2l, t2l) = ListPair.unzip vtl
                               val t2l = map (renamet v1 v1') t2l
                               val v2l' = ListUtil.mapto V.alphavary v2l
                             in VTUnpack(v1', vd', 
                                         ListPair.zip(map #2 v2l', t2l), 
                                         va, 
                                         renamev vd vd' ` renamevall (renamev v1 v1' ve) v2l')
                             end
    | cval (V (VLetsham (v, va, va2))) =
                             let val v' = V.alphavary v
                             in VLetsham(v', va, renamev v v' va2)
                             end
    | cval (V (VLeta (v, va, va2))) =
                             let val v' = V.alphavary v
                             in VLeta(v', va, renamev v v' va2)
                             end

    (* dictionaries use these type binders, so we have to repeat the
       renamings here. Would it be possible to reuse (a suitably abstracted) 
       ctyp for this?? 

       (don't be confused that the following few use variable names like t
        to stand for values, as they are copied from above)
       *)
    | cval (V (Dict(AllArrow { worlds, tys, vals, body }))) =
                             let
                               (* the world vars are world vars, but
                                  the (former) type vars are now val vars. *)
                               val (ws1, ws2) = ListPair.unzip worlds
                               (* the static and dynamic world vars *)
                               val ws1' = ListUtil.mapto V.alphavary ws1
                               val ws2' = ListUtil.mapto V.alphavary ws2

                               val (tys1, tys2) = ListPair.unzip tys

                               (* The type vars *)
                               val tys1' = ListUtil.mapto V.alphavary tys1
                               (* the dict vars *)
                               val tys2' = ListUtil.mapto V.alphavary tys2

                               fun renw v = renamevall (renamevall v ws1') ws2'
                               fun rent v = renamevall (renw v) tys1'
                               fun renv v = renamevall (rent v) tys2'
                             in 
                               Dict `
                               AllArrow { worlds = ListPair.zip(map #2 ws1',
                                                                map #2 ws2'),
                                          tys    = ListPair.zip(map #2 tys1',
                                                                map #2 tys2'),
                                          vals   = map renv vals,
                                          body   = renv body }
                             end
    | cval (V(Dict(WExists ((v, vd), t)))) = 
                             let 
                               val v' = V.alphavary v
                               val vd' = V.alphavary vd
                             in Dict ` WExists ((v', vd'), renamev vd vd' ` renamev v v' t)
                             end

    | cval (V(Dict(Shamrock ((v, vd), t)))) = 
                             let 
                               val v' = V.alphavary v
                               val vd' = V.alphavary vd
                             in Dict ` Shamrock ((v', vd'), renamev vd vd' ` renamev v v' t)
                             end
                                     
    | cval (V(Dict(TExists ((v1, v2), t)))) = 
                             let val v1' = V.alphavary v1
                                 val v2' = V.alphavary v2
                             in Dict ` TExists ((v1', v2'), map (renamev v2 v2' o renamev v1 v1') t)
                             end

    | cval (V(Dict(Mu(i, vvtl)))) = 
                             let 
                                 val (vvs, ts) = ListPair.unzip vvtl
                                 val (tys1, tys2) = ListPair.unzip vvs
                                 val tys1' = ListUtil.mapto V.alphavary tys1
                                 val tys2' = ListUtil.mapto V.alphavary tys2

                                 fun rent t = renamevall (renamevall t tys1') tys2'
                                 val vvtl = ListPair.zip (ListPair.zip(map #2 tys1',
                                                                       map #2 tys2'),
                                                          map rent ts)
                             in
                                 Dict ` 
                                 Mu(i, vvtl)
                             end

    (* other type fronts don't bind variables; easy *)
    | cval (V (d as Dict _)) = d

    | cval (V (Sham (w, va))) = let val w' = V.alphavary w
                                in Sham (w', renamev w w' va)
                                end

    | cval (V (AllLam { worlds, tys, vals = valstyps, body })) = 
                             let val worlds' = ListUtil.mapto V.alphavary worlds
                                 val tys'    = ListUtil.mapto V.alphavary tys
                                 val (vals, typs) = ListPair.unzip valstyps
                                 val vals'   = ListUtil.mapto V.alphavary vals
                                 fun renv t = renamevall (renamevall (renamevall t worlds') tys') vals'
                                 fun rent t = renametall (renametall (renametall t worlds') tys') vals'
                             in 
                                 AllLam { worlds = map #2 worlds',
                                          tys    = map #2 tys',
                                          vals   = ListPair.zip(map #2 vals',
                                                                map rent typs),
                                          body   = renv body }
                             end
    | cval (V x) = x

  (* need to handle the schematic world variable for PolyCode. *)
  fun cglo glo =
    (case glo of
       Code _ => glo
     | PolyCode (w, va, t) => let val w' = V.alphavary w
                              in 
                                (* print ("cglo " ^ V.tostring w ^ " ---> " ^ V.tostring w' ^ "\n"); *)
                                PolyCode (w', renamev w w' va, renamet w w' t)
                              end)

  infixr >>
  fun EQUAL >> f = f ()
    | c >> _ = c

  fun world_cmp (W w1, W w2) = V.compare(w1, w2)
    | world_cmp (W _, WC _) = LESS
    | world_cmp (WC _, W _) = GREATER
    | world_cmp (WC w1, WC w2) = String.compare (w1, w2)

  fun world_eq ws = EQUAL = world_cmp ws

  fun pc_cmp (VEC, VEC) = EQUAL
    | pc_cmp (VEC, _) = LESS
    | pc_cmp (_, VEC) = GREATER
    | pc_cmp (REF, REF) = EQUAL
    | pc_cmp (REF, _) = LESS
    | pc_cmp (_, REF) = GREATER
    | pc_cmp (DICTIONARY, DICTIONARY) = EQUAL
    | pc_cmp (DICTIONARY, _) = LESS
    | pc_cmp (_, DICTIONARY) = GREATER
    | pc_cmp (INT, INT) = EQUAL
    | pc_cmp (INT, _) = LESS
    | pc_cmp (_, INT) = GREATER
    | pc_cmp (STRING, STRING) = EQUAL
    | pc_cmp (STRING, _) = LESS
    | pc_cmp (_, STRING) = GREATER
    | pc_cmp (BYTES, BYTES) = EQUAL
    | pc_cmp (BYTES, _) = LESS
    | pc_cmp (_, BYTES) = GREATER
    | pc_cmp (EXN, EXN) = EQUAL

  fun arminfo_cmp ac (NonCarrier, NonCarrier) = EQUAL
    | arminfo_cmp ac (NonCarrier, _) = LESS
    | arminfo_cmp ac (_, NonCarrier) = GREATER
    | arminfo_cmp ac (Carrier {definitely_allocated = da1, carried = t1},
                      Carrier {definitely_allocated = da2, carried = t2}) =
    Util.bool_compare (da1, da2) >> (fn () => ac (t1, t2))

  (* maintains that Ex.A(x) = Ey.A(y) by always choosing the same
     names for vars when unbinding *)
  fun ctyp_cmp (T t1, T t2) =
    (case (t1, t2) of
       (AllArrow {worlds = worlds1, tys = tys1, vals = vals1, body = body1},
        AllArrow {worlds = worlds2, tys = tys2, vals = vals2, body = body2}) =>
       (case (Int.compare (length worlds1, length worlds2),
              Int.compare (length tys1, length tys2),
              Int.compare (length vals2, length vals2)) of
          (EQUAL, EQUAL, EQUAL) =>
            let
              (* choose the same rename targets for both sides *)
              val worlds1' = ListUtil.mapto V.alphavary worlds1
              val worlds2' = ListPair.zip (worlds2, map #2 worlds1')
              val tys1'    = ListUtil.mapto V.alphavary tys1
              val tys2'    = ListPair.zip (tys2, map #2 tys1')
              fun rent1 t = renametall (renametall t worlds1') tys1'
              fun rent2 t = renametall (renametall t worlds2') tys2'
            in 
              case Util.lex_list_order ctyp_cmp (map rent1 vals1, map rent2 vals2) of
                (* same vals... *)
                  EQUAL => ctyp_cmp (rent1 body1, rent2 body2)
                | c => c
            end       

        | (EQUAL, EQUAL, c) => c
        | (EQUAL, c, _) => c
        | (c, _, _) => c)

      | (AllArrow _, _) => LESS
      | (_, AllArrow _) => GREATER

      | (WExists (v1, t1), WExists (v2, t2)) =>
          let val v' = V.namedvar "x"
          in
            ctyp_cmp (renamet v1 v' t1,
                      renamet v2 v' t2)
          end
      | (WExists _, _) => LESS
      | (_, WExists _) => GREATER

      | (TExists (v1, t1), TExists (v2, t2)) =>
          let val v' = V.namedvar "x"
          in
            Util.lex_list_order
            ctyp_cmp (map (renamet v1 v') t1,
                      map (renamet v2 v') t2)
          end
      | (TExists _, _) => LESS
      | (_, TExists _) => GREATER

      (* XXX excludes all structural properties other than
         alpha equivalence *)
      | (Mu (i1, vtl1), Mu(i2, vtl2)) =>
          (case (Int.compare (length vtl1, length vtl2),
                 Int.compare (i1, i2)) of
             (EQUAL, EQUAL) =>
               let
                 val vars = map (V.alphavary o #1) vtl1
                 val vtlv1 = ListPair.zip (vtl1, vars)
                 val vtlv2 = ListPair.zip (vtl2, vars)
               in
                 Util.lex_list_order
                 (fn (((v1, t1), v1'),
                      ((v2, t2), v2')) =>
                  ctyp_cmp (renamet v1 v1' t1,
                            renamet v2 v2' t2)) (vtlv1, vtlv2)
               end
           | (EQUAL, c) => c
           | (c, _) => c)
      | (Mu _, _) => LESS
      | (_, Mu _) => GREATER

      | (At (t1, w1), At (t2, w2)) =>
             ctyp_cmp (t1, t2) >> (fn () => world_cmp (w1, w2))
      | (At _, _) => LESS
      | (_, At _) => GREATER

      | (TVar v1, TVar v2) => V.compare (v1, v2)
      | (TVar _, _) => LESS
      | (_, TVar _) => GREATER

      | (Cont l1, Cont l2) => Util.lex_list_order ctyp_cmp (l1, l2)
      | (Cont _, _) => LESS
      | (_, Cont _) => GREATER

      | (TWdict w1, TWdict w2) => world_cmp (w1, w2)
      | (TWdict _, _) => LESS
      | (_, TWdict _) => GREATER

      | (Addr w1, Addr w2) => world_cmp (w1, w2)
      | (Addr _, _) => LESS
      | (_, Addr _) => GREATER

      | (Shamrock (v1, t1), Shamrock (v2, t2)) => 
          let val v' = V.namedvar "x"
          in
            ctyp_cmp (renamet v1 v' t1,
                      renamet v2 v' t2)
          end

      | (Shamrock _, _) => LESS
      | (_, Shamrock _) => GREATER

      | (Conts ll1, Conts ll2) => 
             Util.lex_list_order (Util.lex_list_order ctyp_cmp) (ll1, ll2)
      | (Conts _, _) => LESS
      | (_, Conts _) => GREATER

      | (Product stl1, Product stl2) =>
         let
           (* PERF could guarantee this as a rep inv *)
           val stl1 = ListUtil.sort (ListUtil.byfirst String.compare) stl1
           val stl2 = ListUtil.sort (ListUtil.byfirst String.compare) stl2
         in
           Util.lex_list_order
           (fn ((s1, t1),
                (s2, t2)) =>
            String.compare (s1, s2) >>
            (fn () => ctyp_cmp (t1, t2)))
           (stl1, stl2)
         end
      | (Product _, _) => LESS
      | (_, Product _) => GREATER

      | (Sum stl1, Sum stl2) =>
         let
           (* PERF could guarantee this as a rep inv *)
           val stl1 = ListUtil.sort (ListUtil.byfirst String.compare) stl1
           val stl2 = ListUtil.sort (ListUtil.byfirst String.compare) stl2
         in
           Util.lex_list_order
           (fn ((s1, at1),
                (s2, at2)) =>
            String.compare (s1, s2) >>
            (fn () => arminfo_cmp ctyp_cmp (at1, at2)))
           (stl1, stl2)
         end
      | (Sum _, _) => LESS
      | (_, Sum _) => GREATER

      | (Primcon (pc1, l1), Primcon (pc2, l2)) =>
         pc_cmp (pc1, pc2) >>
         (fn () => Util.lex_list_order ctyp_cmp (l1, l2))
(*
      | (Primcon _, _) => LESS
      | (_, Primcon _) => GREATER
*)

          )

  fun ctyp_eq (t1, t2) = ctyp_cmp (t1, t2) = EQUAL
                             

  (* injections / ctyp *)

  val ctyp' = T
  val cval' = V
  val cexp' = E
  fun cglo' x = x

  fun WAll (v, t) = AllArrow { worlds = [v], tys = nil, vals = nil, body = t }
  fun TAll (v, t) = AllArrow { worlds = nil, tys = [v], vals = nil, body = t }
  fun WLam (v, c) = AllLam { worlds = [v], tys = nil, vals = nil, body = c }
  fun TLam (v, c) = AllLam { worlds = nil, tys = [v], vals = nil, body = c }

  fun WApp (c, w) = AllApp { f = c, worlds = [w], tys = nil, vals = nil }
  fun TApp (c, t) = AllApp { f = c, worlds = nil, tys = [t], vals = nil }

  val At' = fn x => T (At x)
  val Cont' = fn x => T (Cont x)
  val WAll' = fn x => T (WAll x)
  val TAll' = fn x => T (TAll x)
  val AllArrow' = fn x => T (AllArrow x)
  val WExists' = fn x => T (WExists x)
  val TExists' = fn x => T (TExists x)
  val Product' = fn x => T (Product x)
  val Addr' = fn x => T (Addr x)
  val TWdict' = fn x => T (TWdict x)
  val Mu' = fn x => T (Mu x)
  val Sum' = fn x => T (Sum x)
  val Primcon' = fn x => T (Primcon x)
  val Conts' = fn x => T (Conts x)
  val Shamrock' = fn x => T (Shamrock x)
  val Shamrock0' = fn x => T (Shamrock (V.namedvar "unuseds0", x))
  val TVar' = fn x => T (TVar x)

  val Halt' = E Halt
  val Call' = fn x => E (Call x)
  val Go' = fn x => E (Go x)
  val Go_cc' = fn x => E (Go_cc x)
  val Go_mar' = fn x => E (Go_mar x)
  val Primop' = fn x => E (Primop x)
  val Put' = fn x => E (Put x)
  val Letsham' = fn x => E (Letsham x)
  val Leta' = fn x => E (Leta x)
  val WUnpack' = fn x => E (WUnpack x)
  val TUnpack' = fn x => E (TUnpack x)
  val Case' = fn x => E (Case x)
  val ExternWorld' = fn x => E (ExternWorld x)
  val ExternType' = fn x => E (ExternType x)
  val ExternVal' = fn x => E (ExternVal x)

  val Dict' = fn x => V (Dict x)
  val AllLam' = fn x => V (AllLam x)
  val AllApp' = fn x => V (AllApp x)
  val Lams' = fn x => V (Lams x)
  val Fsel' = fn x => V (Fsel x)
  val Int' = fn x => V (Int x)
  val String' = fn x => V (String x)
  val Record' = fn x => V (Record x)
  val Hold' = fn x => V (Hold x)
  val WLam' = fn x => V (WLam x)
  val TLam' = fn x => V (TLam x)
  val WPack' = fn x => V (WPack x)
  val TPack' = fn x => V (TPack x)
  val WApp' = fn x => V (WApp x)
  val TApp' = fn x => V (TApp x)
  val Sham' = fn x => V (Sham x)
  val Inj' = fn x => V (Inj x)
  val Roll' = fn x => V (Roll x)
  val WDict' = fn x => V (WDict x)
  val WDictfor' = fn x => V (WDictfor x)
  val Dictfor' = fn x => V (Dictfor x)
  val Codelab' = fn x => V (Codelab x)
  val Unroll' = fn x => V (Unroll x)
  val Var' = fn x => V (Var x)
  val UVar' = fn x => V (UVar x)
  val VLetsham' = fn x => V (VLetsham x)
  val VLeta' = fn x => V (VLeta x)
  val Proj' = fn x => V (Proj x)
  val VTUnpack' = fn x => V (VTUnpack x)

  val Code' = Code
  val PolyCode' = PolyCode


  fun Lam' (v, vl, e) = Fsel' (Lams' [(v, vl, e)], 0)
  fun Zerocon' pc = Primcon' (pc, nil)
  fun Lift' (v, cv, e) = Letsham'(v, Sham' (V.namedvar "lift_unused", cv), e)
  fun Bind' (v, cv, e) = Primop' ([v], BIND, [cv], e)
  fun Bindat' (v, w, cv, e) = Leta' (v, Hold' (w, cv), e)
  fun Marshal' (v, vd, va, e) = Primop' ([v], MARSHAL, [vd, va], e)
  fun Say' (v, vf, e) = Primop' ([v], SAY, [vf], e)
  fun Say_cc' (v, vf, e) = Primop' ([v], SAY_CC, [vf], e)
  fun Dictionary' t = Primcon' (DICTIONARY, [t])
  fun EProj' (v, s, va, e) = Bind' (v, Proj'(s, va), e)

  fun Sham0' v = Sham' (V.namedvar "sham0_unused", v)


  (* utility code *)

  fun ('tbind, 'ctyp, 'wbind, 'world) ontypefront fw f (typ : ('tbind, 'ctyp, 'wbind, 'world) ctypfront) =
    case typ of
      At (c, w) => At (f c, fw w)
    | Cont l => Cont ` map f l
    | AllArrow {worlds, tys, vals, body} => 
        AllArrow { worlds = worlds, tys = tys, vals = map f vals, body = f body }
    | WExists (v, t) => WExists (v, f t)
    | TExists (v, t) => TExists (v, map f t)
    | Product stl => Product ` ListUtil.mapsecond f stl
    | Addr w => Addr ` fw w
    | TWdict w => TWdict ` fw w
    | Mu (i, vtl) => Mu (i, ListUtil.mapsecond f vtl)
    | Sum sail => Sum ` ListUtil.mapsecond (IL.arminfo_map f) sail
    | Primcon (pc, l) => Primcon (pc, map f l)
    | Conts tll => Conts ` map (map f) tll
    | Shamrock (v, t) => Shamrock (v, f t)
    | TVar v => typ

  fun pointwisetw fw f typ = ctyp' ` ontypefront fw f (ctyp typ)

  fun pointwiseew fw ft fv fe exp =
    case cexp exp of
      Call (v, vl) => Call' (fv v, map fv vl)
    | Halt => exp
    | Go (w, v, e) => Go' (fw w, fv v, fe e)
    | Go_cc { w, addr, env, f } => Go_cc' { w = fw w, addr = fv addr,
                                            env = fv env, f = fv f }
    | Go_mar { w, addr, bytes } => Go_mar' { w = fw w, addr = fv addr, bytes = fv bytes }
    | Primop (vvl, po, vl, e) => Primop' (vvl, 
                                          (case po of
                                             PRIMCALL { sym, dom, cod } =>
                                               PRIMCALL { sym = sym, dom = map ft dom, cod = ft cod }
                                           | NATIVE { po, tys } => NATIVE { po = po, tys = map ft tys }
                                           | SAY => SAY
                                           | SAY_CC => SAY_CC
                                           | BIND => BIND
                                           | MARSHAL => MARSHAL
                                           | LOCALHOST => LOCALHOST),
                                          map fv vl, fe e)
    | Put (vv, v, e) => Put' (vv, fv v, fe e)
    | Letsham (vv, v, e) => Letsham' (vv, fv v, fe e)
    | Leta (vv, v, e) => Leta' (vv, fv v, fe e)
    | WUnpack (vv1, vv2, v, e) => WUnpack' (vv1, vv2, fv v, fe e)
    | TUnpack (vv1, vd, vv2, v, e) => TUnpack' (vv1, vd, vv2, fv v, fe e)
    | Case (v, vv, sel, def) => Case' (fv v, vv, ListUtil.mapsecond fe sel, fe def)
    | ExternVal (v, l, t, wo, e) => ExternVal' (v, l, ft t, Option.map fw wo, fe e)
    | ExternWorld (l, k, e) => ExternWorld' (l, k, fe e)
    | ExternType (v, l, vso, e) => ExternType' (v, l, vso, fe e)

  fun pointwisevw fw ft fv fe value =
    case cval value of
      Lams vael => Lams' ` map (fn (v, vtl, e) => (v,
                                                   ListUtil.mapsecond ft vtl, 
                                                   fe e)) vael
    | Fsel (v, i) => Fsel' (fv v, i) 
    | Int _ => value
    | String _ => value
    | Record svl => Record' ` ListUtil.mapsecond fv svl
    | VLetsham (vv, v, e) => VLetsham' (vv, fv v, fv e)
    | VLeta (vv, v, e) => VLeta' (vv, fv v, fv e)
    | VTUnpack (vv1, vd, vv2, v, e) => VTUnpack' (vv1, vd, vv2, fv v, fv e)
    | Hold (w, v) => Hold' (fw w, fv v)
    | WPack (w, v) => WPack' (fw w, fv v)
    | TPack (t, t2, v, vs) => TPack' (ft t, ft t2, fv v, map fv vs)
    | Sham (w, v) => Sham' (w, fv v)
    | Inj (s, t, vo) => Inj' (s, ft t, Option.map fv vo)
    | Roll (t, v) => Roll' (ft t, fv v)
    | Unroll v => Unroll' ` fv v
    | Codelab _ => value
    | Var _ => value
    | UVar _ => value
    | Proj (s, v) => Proj' (s, fv v)
    | WDict s => value
    | WDictfor w => WDictfor' ` fw w
    | Dictfor t => Dictfor' ` ft t
    | Dict tf => Dict' ` ontypefront fv fv tf
    | AllLam { worlds : var list, tys : var list, vals : (var * ctyp) list, body : cval } =>
                AllLam' { worlds = worlds, tys = tys, 
                          vals = ListUtil.mapsecond ft vals, body = fv body }
    | AllApp { f : cval, worlds : world list, tys : ctyp list, vals : cval list } =>
                AllApp' { f = fv f, worlds = map fw worlds, tys = map ft tys, vals = map fv vals }


  fun subww sw sv = substw sv (SW sw)
  fun subwt sw sv = substt sv (SW sw)
  fun subwv sw sv = substv sv (SW sw)
  fun subwe sw sv = subste sv (SW sw)

  fun subtt st sv = substt sv (ST st)
  fun subtv st sv = substv sv (ST st)
  fun subte st sv = subste sv (ST st)

  fun subvv sl sv = substv sv (SV sl)
  fun subve sl sv = subste sv (SV sl)

  local open Primop
        open Podata
        val bv = V.namedvar "pbool"
  in
    fun ptoct PT_INT = Zerocon' INT
      | ptoct PT_CHAR = Zerocon' INT
      | ptoct PT_STRING = Zerocon' STRING
      | ptoct PT_BOOL = 
      Mu' (0, [(bv, Sum' [(Initial.truename, IL.NonCarrier),
                          (Initial.falsename, IL.NonCarrier)])])
      | ptoct (PT_VAR v) = TVar' v
      | ptoct PT_UNIT = Product' nil
      | ptoct (PT_REF p) = Primcon' (REF, [ptoct p])
      | ptoct _ = raise CPS "unimplemented ptoct"
  end

  exception Occurs

  fun occursw var (w as W var') = if V.eq (var, var') then raise Occurs else w
    | occursw _   (w as WC _)   = w

  fun occursv var (value : cval) =
    (case cval value of
       Var v => if V.eq(var, v) then raise Occurs else value
     | UVar u => if V.eq(var, u) then raise Occurs else value
     | _ => pointwisevw (occursw var) (occurst var) (occursv var) (occurse var) value)

  and occurse var (exp : cexp) =
    pointwiseew (occursw var) (occurst var) (occursv var) (occurse var) exp

  and occurst var (typ : ctyp) =
    (case ctyp typ of
       TVar v => if V.eq (var, v) then raise Occurs else typ
     | _ => pointwisetw (occursw var) (occurst var) typ)

  fun freev v va = (occursv v va; false) handle Occurs => true
  fun freee v va = (occurse v va; false) handle Occurs => true
  fun freet v va = (occurst v va; false) handle Occurs => true

    
  fun pointwiset ft typ = pointwisetw (fn w => w) ft typ
  fun pointwisee ft fv fe exp = pointwiseew (fn w => w) ft fv fe exp
  fun pointwisev ft fv fe value = pointwisevw (fn w => w) ft fv fe value

  (* Free variable set stuff *)
  structure VS = Variable.Set
  local 
    fun accvarsv (us, s) (value : cval) : cval =
      (case cval value of
         Var v => (s := VS.add (!s, v); value)
       | UVar u => (us := VS.add (!us, u); value)
       | _ => pointwisev (fn t => t) (accvarsv (us, s)) (accvarse (us, s)) value)
    and accvarse (us, s) exp = 
      (pointwisee (fn t => t) (accvarsv (us, s)) (accvarse (us, s)) exp; exp)

    (* give the set of all variable occurrences in a value or expression.
       the only sensible use for this is below: *)
    fun allvarse exp = 
           let val us = ref VS.empty
               val s  = ref VS.empty
           in
             accvarse (us, s) exp;
             (!us, !s)
           end
    fun allvarsv value =
           let val us = ref VS.empty
               val s  = ref VS.empty
           in
             accvarsv (us, s) value;
             (!us, !s)
           end

  in
    
    (* Sick or slick? You make the call! *)
    fun freevarsv value =
      (* compute allvars twice; intersection is free vars *)
      let val (us1, s1) = allvarsv value
          val (us2, s2) = allvarsv value
      in
        (VS.intersection (s1, s2), VS.intersection (us1, us2))
      end
    fun freevarse exp = 
      let val (us1, s1) = allvarse exp
          val (us2, s2) = allvarse exp
      in
        (VS.intersection (s1, s2), VS.intersection (us1, us2))
      end

  end

  local
    fun aw (ws, _) (w as W v) = (ws := VS.add (!ws, v); w)
      | aw _       (w as WC _) = w

    and at (ws, ts) typ =
      case ctyp typ of
        TVar v => (ts := VS.add (!ts, v); typ)
      | _ => pointwisetw (aw (ws, ts)) (at (ws, ts)) typ
    
    and av r value = pointwisevw (aw r) (at r) (av r) (ae r) value
    and ae r exp = pointwiseew (aw r) (at r) (av r) (ae r) exp

    fun with2e f x =
      let 
        val ww = ref VS.empty
        val tt = ref VS.empty
      in
        ignore (f (ww, tt) x);
        (!ww, !tt)
      end

    val allt = with2e at
    val allv = with2e av
    val alle = with2e ae

    fun twicei f x =
      let
        val (w1, t1) = f x
        val (w2, t2) = f x
      in
        { w = VS.intersection (w1, w2), t = VS.intersection (t1, t2) }
      end
  in
    val freesvarst = twicei allt
    val freesvarsv = twicei allv
    val freesvarse = twicei alle
    fun freesvarsw (W w)  = { t = VS.empty, w = VS.add(VS.empty, w) }
      | freesvarsw (WC _) = { t = VS.empty, w = VS.empty }
  end

end
