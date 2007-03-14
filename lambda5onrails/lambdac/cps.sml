structure CPS :> CPS =
struct
  
  structure V = Variable
  type var = V.var
  infixr 9 `
  fun a ` b = a b

  exception CPS of string

  datatype arminfo = datatype IL.arminfo
  datatype world = W of var

  datatype primcon = VEC | REF | DICT | INT | STRING

  datatype 'ctyp ctypfront =
      At of 'ctyp * world
    | Cont of 'ctyp list
    | AllArrow of { worlds : var list, tys : var list, vals : 'ctyp list, body : 'ctyp }
    | WExists of var * 'ctyp
    | TExists of var * 'ctyp list
    | Product of (string * 'ctyp) list
    | Addr of world
    | Mu of int * (var * 'ctyp) list
    | Sum of (string * 'ctyp IL.arminfo) list
    | Primcon of primcon * 'ctyp list
    | Conts of 'ctyp list list
    | Shamrock of 'ctyp
    | TVar of var
  (* nb. Binders must be implemented in outjection code below! *)

  datatype ctyp = T of ctyp ctypfront

  datatype primop = LOCALHOST | BIND | PRIMCALL of { sym : string, dom : ctyp list, cod : ctyp }

  datatype ('cexp, 'cval) cexpfront =
      Call of 'cval * 'cval list
    | Halt
    | Go of world * 'cval * 'cexp
    | Proj of var * string * 'cval * 'cexp
    | Primop of var list * primop * 'cval list * 'cexp
    | Put of var * ctyp * 'cval * 'cexp
    | Letsham of var * 'cval * 'cexp
    | Leta of var * 'cval * 'cexp
    (* world var, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    | TUnpack of var * (var * ctyp) list * 'cval * 'cexp
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of var * string * 'cexp
    | ExternType of var * string * (var * string) option * 'cexp
  (* nb. Binders must be implemented in outjection code below! *)

  and ('cexp, 'cval) cvalfront =
      Lams of (var * (var * ctyp) list * 'cexp) list
    | Fsel of 'cval * int
    | Int of IntConst.intconst
    | String of string
    | Record of (string * 'cval) list
    | Hold of world * 'cval
    | WPack of world * 'cval
    | TPack of ctyp * 'cval list
    | Sham of 'cval
    | Inj of string * ctyp * 'cval option
    | Roll of ctyp * 'cval
    | Unroll of 'cval
    | Var of var
    | UVar of var
    | Dictfor of ctyp
    | AllLam of { worlds : var list, tys : var list, vals : var list, body : 'cval }
    | AllApp of { f : 'cval, worlds : world list, tys : ctyp list, vals : 'cval list }
  (* nb. Binders must be implemented in outjection code below! *)
   
  (* CPS expressions *)
  datatype cexp = E of (cexp, cval) cexpfront
  and      cval = V of (cexp, cval) cvalfront

  datatype substitutend = 
      SV of cval
(*    | SE of cexp *) 
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
       | Proj (vv, s, va, ex) =>
           Proj (vv, s, vself va,
                 if V.eq (vv, v)
                 then ex
                 else eself ex)
       | Primop (vvl, po, vl, ce) =>
           let fun poself LOCALHOST = LOCALHOST
                 | poself BIND = BIND
                 | poself (PRIMCALL { sym, dom, cod }) = PRIMCALL { sym = sym,
                                                                    dom = map tself dom,
                                                                    cod = tself cod }
           in
             Primop (vvl, poself po, map vself vl,
                     if List.exists (fn vv => V.eq (vv, v)) vvl
                     then ce
                     else eself ce)
           end
       | Put (vv, ty, va, e) =>
           Put (vv, tself ty, vself va,
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
       | TUnpack (vv1, vvl, va, e) =>
           TUnpack (vv1, 
                    if V.eq(vv1, v) then vvl else ListUtil.mapsecond tself vvl, 
                    vself va,
                    if V.eq(vv1, v) orelse List.exists (fn (vv, _) => V.eq (vv, v)) vvl
                    then e
                    else eself e)
       | Case (va, vv, sel, e) =>
           Case (vself va, vv,
                 if V.eq(vv, v) then sel
                 else ListUtil.mapsecond eself sel,
                 if V.eq(vv, v) then e
                 else eself e)
       | ExternWorld (vv, s, e) =>
           ExternWorld (vv, s, if V.eq (vv, v) then e else eself e)
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
         | Hold (w, va) => Hold (wself w, vself va)

         | AllLam { worlds, tys, vals, body } => 
               if List.exists issrc worlds orelse
                  List.exists issrc tys orelse
                  List.exists issrc vals
               then value
               else AllLam { worlds = worlds, tys = tys, vals = vals, body = vself body }

         | AllApp { f, worlds, tys, vals } => AllApp { f = vself f, worlds = map wself worlds,
                                                       tys = map tself tys, vals = map vself vals }
         | WPack (w, va) => WPack (wself w, vself va)
         | TPack (t, va) => TPack (tself t, map vself va)
         | Var vv => if V.eq(v, vv) then se_getv se else Var vv
         | UVar vv => UVar (if V.eq(v, vv) then se_getu se else vv)
         | Unroll va => Unroll (vself va)
         | Roll (t, va) => Roll (tself t, vself va)
         | Dictfor t => Dictfor ` tself t
         | Sham va => Sham ` vself va
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
    

  and substw v se (W vv) = if V.eq (v, vv) then se_getw se else W vv

  (* substitute var v with type se in a type, observing scope *)
  and substt v se (T typ) =
    let 
      fun issrc vv = V.eq (v, vv)
      val self = substt v se
      val wself = substw v se
    in
      T
      (case typ of
         At (t, w) => At (self t, wself w)
       | Cont l => Cont (map self l)
       | AllArrow { worlds, tys, vals, body } => 
             if List.exists issrc worlds orelse
                List.exists issrc tys
             then typ
             else AllArrow { worlds = worlds,
                             tys = tys,
                             vals = map self vals,
                             body = self body }
       | WExists (vv, t) => if V.eq (v, vv) then typ
                            else WExists(vv, self t)
       | TExists (vv, t) => if V.eq (v, vv) then typ
                            else TExists(vv, map self t)
       | Product stl => Product ` ListUtil.mapsecond self stl
       | Addr w => Addr (wself w)
       | Mu (i, vtl) => Mu (i, map (fn (vv, t) =>
                                    if V.eq (vv, v)
                                    then (vv, t)
                                    else (vv, self t)) vtl)
       | Sum sal => Sum (map (fn (s, NonCarrier) => (s, NonCarrier)
                               | (s, Carrier { definitely_allocated, carried }) => 
                              (s, Carrier { definitely_allocated = definitely_allocated,
                                            carried = self carried })) sal)
       | Primcon (pc, l) => Primcon (pc, map self l)
       | Conts ll => Conts ` map (map self) ll
       | Shamrock t => Shamrock ` self t
       | TVar vv => if V.eq (v, vv) then se_gett se else TVar vv
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
                                 in (WExists (v', renamet v v' t))
                                 end
    | ctyp (T(TExists (v, t))) = let val v' = V.alphavary v
                                 in (TExists (v', map (renamet v v') t))
                                 end

    | ctyp (T(Mu(i, vtl))) = Mu(i, map (fn (v, t) =>
                                        let val v' = V.alphavary v
                                        in (v', renamet v v' t)
                                        end) vtl)
    | ctyp (T x) = x

  fun cexp (E(Proj(v, s, va, e))) = let val v' = V.alphavary v
                                    in Proj(v', s, va, renamee v v' e)
                                    end
    | cexp (E(Primop(vvl, po, vl, e))) = 
                                    let val vs = ListUtil.mapto V.alphavary vvl
                                    in Primop(map #2 vs, po, vl,
                                              renameeall e vs)
                                    end
    | cexp (E(Put(v, ty, va, e))) = let val v' = V.alphavary v
                                    in Put(v', ty, va, renamee v v' e)
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
    | cexp (E(TUnpack(v1, vtl, va, e))) = let val v1' = V.alphavary v1
                                              val (v2l, t2l) = ListPair.unzip vtl
                                              val t2l = map (renamet v1 v1') t2l
                                              val v2l' = ListUtil.mapto V.alphavary v2l
                                         in TUnpack(v1', ListPair.zip(map #2 v2l', t2l), 
                                                    va, 
                                                    renameeall (renamee v1 v1' e) v2l')
                                         end
    | cexp (E(Case(va, v, sel, def))) = let val v' = V.alphavary v
                                        in
                                          Case(va, v', ListUtil.mapsecond (renamee v v') sel,
                                               renamee v v' def)
                                        end

    | cexp (E(ExternVal(vv, s, t, wo, e))) = let val v' = V.alphavary vv
                                             in ExternVal(v', s, t, wo, renamee vv v' e)
                                             end

    | cexp (E(ExternType(vv, s, NONE, e))) = let val v' = V.alphavary vv
                                             in ExternType(v', s, NONE, renamee vv v' e)
                                             end
    | cexp (E(ExternType(vv, s, SOME (v2, s2), e))) = let val v' = V.alphavary vv
                                                          val v2' = V.alphavary v2
                                                      in ExternType(v', s, SOME (v2, s2), 
                                                                    renamee v2 v2' ` renamee vv v' e)
                                                      end

    | cexp (E(ExternWorld(vv, s, e))) = let val v' = V.alphavary vv
                                        in ExternWorld(v', s, renamee vv v' e)
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

    | cval (V (AllLam { worlds, tys, vals, body })) = 
                             let val worlds' = ListUtil.mapto V.alphavary worlds
                                 val tys'    = ListUtil.mapto V.alphavary tys
                                 val vals'   = ListUtil.mapto V.alphavary vals
                                 fun renv t = renamevall (renamevall (renamevall t worlds') tys') vals'
                             in 
                                 AllLam { worlds = map #2 worlds',
                                          tys    = map #2 tys',
                                          vals   = map #2 vals',
                                          body   = renv body }
                             end
    | cval (V x) = x

  infixr >>
  fun EQUAL >> f = f ()
    | c >> _ = c

  fun world_cmp (W w1, W w2) = V.compare(w1, w2)

  fun pc_cmp (VEC, VEC) = EQUAL
    | pc_cmp (VEC, _) = LESS
    | pc_cmp (_, VEC) = GREATER
    | pc_cmp (REF, REF) = EQUAL
    | pc_cmp (REF, _) = LESS
    | pc_cmp (_, REF) = GREATER
    | pc_cmp (DICT, DICT) = EQUAL
    | pc_cmp (DICT, _) = LESS
    | pc_cmp (_, DICT) = GREATER
    | pc_cmp (INT, INT) = EQUAL
    | pc_cmp (INT, _) = LESS
    | pc_cmp (_, INT) = GREATER
    | pc_cmp (STRING, STRING) = EQUAL

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

      | (Addr w1, Addr w2) => world_cmp (w1, w2)
      | (Addr _, _) => LESS
      | (_, Addr _) => GREATER

      | (Shamrock t1, Shamrock t2) => ctyp_cmp (t1, t2)
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
  val Mu' = fn x => T (Mu x)
  val Sum' = fn x => T (Sum x)
  val Primcon' = fn x => T (Primcon x)
  val Conts' = fn x => T (Conts x)
  val Shamrock' = fn x => T (Shamrock x)
  val TVar' = fn x => T (TVar x)

  val Halt' = E Halt
  val Call' = fn x => E (Call x)
  val Go' = fn x => E (Go x)
  val Proj' = fn x => E (Proj x)
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
  val Dictfor' = fn x => V (Dictfor x)
  val Unroll' = fn x => V (Unroll x)
  val Var' = fn x => V (Var x)
  val UVar' = fn x => V (UVar x)

  fun Lam' (v, vl, e) = Fsel' (Lams' [(v, vl, e)], 0)
  fun Zerocon' pc = Primcon' (pc, nil)

  (* utility code *)

  fun pointwiset f typ =
    case ctyp typ of
      At (c, w) => At' (f c, w)
    | Cont l => Cont' ` map f l
    | AllArrow {worlds, tys, vals, body} => 
        AllArrow' { worlds = worlds, tys = tys, vals = map f vals, body = f body }
    | WExists (v, t) => WExists' (v, f t)
    | TExists (v, t) => TExists' (v, map f t)
    | Product stl => Product' ` ListUtil.mapsecond f stl
    | Addr w => typ
    | Mu (i, vtl) => Mu' (i, ListUtil.mapsecond f vtl)
    | Sum sail => Sum' ` ListUtil.mapsecond (IL.arminfo_map f) sail
    | Primcon (pc, l) => Primcon' (pc, map f l)
    | Conts tll => Conts' ` map (map f) tll
    | Shamrock t => Shamrock' ` f t
    | TVar v => typ

  fun pointwisee ft fv fe exp =
    case cexp exp of
      Call (v, vl) => Call' (fv v, map fv vl)
    | Halt => exp
    | Go (w, v, e) => Go' (w, fv v, fe e)
    | Proj (vv, s, v, e) => Proj' (vv, s, fv v, fe e)
    | Primop (vvl, po, vl, e) => Primop' (vvl, 
                                          (case po of
                                             PRIMCALL { sym, dom, cod } =>
                                               PRIMCALL { sym = sym, dom = map ft dom, cod = ft cod }
                                           | BIND => BIND
                                           | LOCALHOST => LOCALHOST),
                                          map fv vl, fe e)
    | Put (vv, t, v, e) => Put' (vv, ft t, fv v, fe e)
    | Letsham (vv, v, e) => Letsham' (vv, fv v, fe e)
    | Leta (vv, v, e) => Leta' (vv, fv v, fe e)
    | WUnpack (vv1, vv2, v, e) => WUnpack' (vv1, vv2, fv v, fe e)
    | TUnpack (vv1, vv2, v, e) => TUnpack' (vv1, vv2, fv v, fe e)
    | Case (v, vv, sel, def) => Case' (fv v, vv, ListUtil.mapsecond fe sel, fe def)
    | ExternVal (v, l, t, wo, e) => ExternVal' (v, l, ft t, wo, fe e)
    | ExternWorld (v, l, e) => ExternWorld' (v, l, fe e)
    | ExternType (v, l, vso, e) => ExternType' (v, l, vso, fe e)

  fun pointwisev ft fv fe value =
    case cval value of
      Lams vael => Lams' ` map (fn (v, vtl, e) => (v,
                                                   ListUtil.mapsecond ft vtl, 
                                                   fe e)) vael
    | Fsel (v, i) => Fsel' (fv v, i) 
    | Int _ => value
    | String _ => value
    | Record svl => Record' ` ListUtil.mapsecond fv svl
    | Hold (w, v) => Hold' (w, fv v)
    | WPack (w, v) => WPack' (w, fv v)
    | TPack (t, v) => TPack' (ft t, map fv v)
    | Sham v => Sham' ` fv v
    | Inj (s, t, vo) => Inj' (s, ft t, Option.map fv vo)
    | Roll (t, v) => Roll' (ft t, fv v)
    | Unroll v => Unroll' ` fv v
    | Var _ => value
    | UVar _ => value
    | Dictfor t => Dictfor' ` ft t
    | AllLam { worlds : var list, tys : var list, vals : var list, body : cval } =>
                AllLam' { worlds = worlds, tys = tys, vals = vals, body = fv body }
    | AllApp { f : cval, worlds : world list, tys : ctyp list, vals : cval list } =>
                AllApp' { f = fv f, worlds = worlds, tys = map ft tys, vals = map fv vals }


  fun subww sw sv = substw sv (SW sw)
  fun subwt sw sv = substt sv (SW sw)
  fun subwv sw sv = substv sv (SW sw)
  fun subwe sw sv = subste sv (SW sw)

  fun subtt st sv = substt sv (ST st)
  fun subtv st sv = substv sv (ST st)
  fun subte st sv = subste sv (ST st)

  fun subvv sl sv = substv sv (SV sl)
  fun subve sl sv = subste sv (SV sl)

end
