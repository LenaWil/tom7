
structure CPSUtil =
struct

  structure V = Variable
  type var = V.var
  infixr 9 `
  fun a ` b = a b

  open CPS

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

  local 
    exception Yes
    
    fun at t = t
    and av v' v =
      (case cval v of
         Var vv => if V.eq (vv, v') then raise Yes
                   else v
       | UVar uu => if V.eq (uu, v') then raise Yes
                    else v
       | _ => pointwisev at (av v') (ae v') v)
    and ae v' e = pointwisee at (av v') (ae v') e
  in
    fun isvfreeinv v va = (av v va; false) handle Yes => true
    fun isvfreeine v ex = (ae v ex; false) handle Yes => true

    (* These are actually implemented the same way, since
       we internally have disjoint sets of modal and valid
       vars. (but we could distinguish them with different versions
       of av above...) *)
    val isufreeinv = isvfreeinv
    val isufreeine = isvfreeine
  end


end
