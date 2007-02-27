
structure CPS :> CPS =
struct
  
  structure V = Variable
  type var = V.var
  infixr 9 `
  fun a ` b = a b

  exception CPS of string

  datatype arminfo = datatype IL.arminfo
  datatype world = W of var

  datatype primcon = VEC | REF

  type intconst = IL.intconst

  datatype 'ctyp ctypfront =
      At of 'ctyp * world
    | Cont of 'ctyp list
    | WAll of var * 'ctyp
    | TAll of var * 'ctyp
    | WExists of var * 'ctyp
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
    | Put of var * 'cval * 'cexp
    | Letsham of var * 'cval * 'cexp
    | Leta of var * 'cval * 'cexp
    (* world var, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of var * string * 'cexp
    (* always kind 0 *)
    | ExternType of var * string * 'cexp
  (* nb. Binders must be implemented in outjection code below! *)

  and ('cexp, 'cval) cvalfront =
      Lams of (var * var list * 'cexp) list
    | Fsel of 'cval * int
    | Int of intconst
    | String of string
    | Record of (string * 'cval) list
    | Hold of world * 'cval
    | WLam of var * 'cval
    | TLam of var * 'cval
    | WPack of world * 'cval
    | WApp of 'cval * world
    | TApp of 'cval * ctyp
    | Sham of 'cval
    | Inj of string * ctyp * 'cval option
    | Roll of ctyp * 'cval
    | Unroll of 'cval
    | Var of var
    | UVar of var
  (* nb. Binders must be implemented in outjection code below! *)
   
  (* CPS expressions *)
  datatype cexp = E of (cexp, cval) cexpfront
  and      cval = V of (cexp, cval) cvalfront

  fun renamee v v' (E exp) =
    let val eself = renamee v v'
        val vself = renamev v v'
        val wself = renamew v v'
        val tself = renamet v v'
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
       | Case (va, vv, sel, e) =>
           Case (vself va, vv,
                 if V.eq(vv, v) then sel
                 else ListUtil.mapsecond eself sel,
                 if V.eq(vv, v) then e
                 else eself e)
       | ExternWorld (vv, s, e) =>
           ExternWorld (vv, s, if V.eq (vv, v) then e else eself e)
       | ExternType (vv, s, e) =>
           ExternType (vv, s, if V.eq (vv, v) then e else eself e)
       | ExternVal (vv, s, t, wo, e) =>
           ExternVal (vv, s, tself t, Option.map wself wo,
                      if V.eq (vv, v) then e else eself e)
           )
    end

  and renamev v v' (V value) =
    let val eself = renamee v v'
        val vself = renamev v v'
        val wself = renamew v v'
        val tself = renamet v v'
    in
      V (case value of
           Int i => value
         | String s => value
         | Record svl => Record ` ListUtil.mapsecond vself svl
         | Hold (w, va) => Hold (wself w, vself va)
         | WLam (vv, va) => WLam (vv, if V.eq(v, vv) then va else vself va)
         | TLam (vv, va) => TLam (vv, if V.eq(v, vv) then va else vself va)
         | WPack (w, va) => WPack (wself w, vself va)
         | WApp (va, w) => WApp (vself va, wself w)
         | TApp (va, t) => TApp (vself va, tself t)
         | Var vv => Var (if V.eq(v, vv) then v' else vv)
         | UVar vv => UVar (if V.eq(v, vv) then v' else vv)
         | Unroll va => Unroll (vself va)
         | Roll (t, va) => Roll (tself t, vself va)
         | Sham va => Sham ` vself va
         | Fsel (va, i) => Fsel (vself va, i)
         | Inj (s, t, va) => Inj (s, tself t, Option.map vself va)
         | Lams vvel => Lams ` map (fn (vv, vvl, ce) => (vv, vvl,
                                                         if List.exists (fn vv => V.eq (vv, v)) vvl
                                                            orelse
                                                            List.exists (fn (vv, _, _) => V.eq (vv, v)) vvel
                                                         then ce
                                                         else eself ce)) vvel
           )
    end
    

  and renamew v v' (W vv) = if V.eq (v, vv) then W v' else W vv

  (* rename v to v' in a type, assuming that v' is totally fresh *)
  and renamet v v' (T typ) =
    let 
      val self = renamet v v'
      val wself = renamew v v'
    in
      T
      (case typ of
         At (t, w) => At (self t, wself w)
       | Cont l => Cont (map self l)
       | WAll (vv, t) => if V.eq(v, vv) then typ
                         else WAll(vv, self t)
       | TAll (vv, t) => if V.eq(v, vv) then typ
                         else TAll(vv, self t)
       | WExists (vv, t) => if V.eq (v, vv) then typ
                            else WExists(vv, self t)
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
       | TVar vv => TVar (if V.eq (v, vv) then v' else vv)
                              )
    end

  (* when exposing a binder, we alpha-vary. *)
  fun ctyp (T(WAll (v, t))) = let val v' = V.alphavary v
                              in (WAll (v', renamet v v' t))
                              end
    | ctyp (T(TAll (v, t))) = let val v' = V.alphavary v
                              in (TAll (v', renamet v v' t))
                              end
    | ctyp (T(WExists (v, t))) = let val v' = V.alphavary v
                                 in (WExists (v', renamet v v' t))
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
                                              foldl (fn ((v,v'), e) => renamee v v' e) e vs)
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
    | cexp (E(Case(va, v, sel, def))) = let val v' = V.alphavary v
                                        in
                                          Case(va, v', ListUtil.mapsecond (renamee v v') sel,
                                               renamee v v' def)
                                        end

    | cexp (E(ExternVal(vv, s, t, wo, e))) = let val v' = V.alphavary vv
                                             in ExternVal(v', s, t, wo, renamee vv v' e)
                                             end

    | cexp (E(ExternType(vv, s, e))) = let val v' = V.alphavary vv
                                       in ExternType(v', s, renamee vv v' e)
                                       end

    | cexp (E(ExternWorld(vv, s, e))) = let val v' = V.alphavary vv
                                        in ExternWorld(v', s, renamee vv v' e)
                                        end

    | cexp (E x) = x

  fun cval (V (Lams vael)) = let val fs = map (fn (v, a, e) => (v, V.alphavary v, a, e)) vael
                             in
                               Lams (map (fn (v, v', a, e) =>
                                          let val a' = ListUtil.mapto V.alphavary a
                                          in
                                            (v', map #2 a', 
                                             foldl (fn ((v, v'), e) => renamee v v' e) e
                                             (* function names @ these args *)
                                             ((map (fn (v, v', _, _) => (v, v')) fs) @ a')
                                             )
                                          end) fs)
                             end
    | cval (V (WLam (v, va))) = let val v' = V.alphavary v
                                in WLam(v', renamev v v' va)
                                end
    | cval (V (TLam (v, va))) = let val v' = V.alphavary v
                                in TLam(v', renamev v v' va)
                                end

    | cval (V x) = x


  (* injections / ctyp *)

  val At' = fn x => T (At x)
  val Cont' = fn x => T (Cont x)
  val WAll' = fn x => T (WAll x)
  val TAll' = fn x => T (TAll x)
  val WExists' = fn x => T (WExists x)
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
  val Case' = fn x => E (Case x)
  val ExternWorld' = fn x => E (ExternWorld x)
  val ExternType' = fn x => E (ExternType x)
  val ExternVal' = fn x => E (ExternVal x)

  val Lams' = fn x => V (Lams x)
  val Fsel' = fn x => V (Fsel x)
  val Int' = fn x => V (Int x)
  val String' = fn x => V (String x)
  val Record' = fn x => V (Record x)
  val Hold' = fn x => V (Hold x)
  val WLam' = fn x => V (WLam x)
  val TLam' = fn x => V (TLam x)
  val WPack' = fn x => V (WPack x)
  val WApp' = fn x => V (WApp x)
  val TApp' = fn x => V (TApp x)
  val Sham' = fn x => V (Sham x)
  val Inj' = fn x => V (Inj x)
  val Roll' = fn x => V (Roll x)
  val Unroll' = fn x => V (Unroll x)
  val Var' = fn x => V (Var x)
  val UVar' = fn x => V (UVar x)

  fun Lam' (v, vl, e) = Fsel' (Lams' [(v, vl, e)], 0)

end
