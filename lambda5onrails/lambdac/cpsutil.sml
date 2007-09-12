
structure CPSUtil :> CPSUTIL =
struct

  structure V = Variable
  type var = V.var
  infixr 9 `
  fun a ` b = a b

  open CPS

  fun ctyp' (At p) = At' p
    | ctyp' (Cont p) = Cont' p
    | ctyp' (AllArrow p) = AllArrow' p
    | ctyp' (WExists p) = WExists' p
    | ctyp' (TExists p) = TExists' p
    | ctyp' (Product p) = Product' p
    | ctyp' (Addr p) = Addr' p
    | ctyp' (TWdict p) = TWdict' p
    | ctyp' (Mu p) = Mu' p
    | ctyp' (Sum p) = Sum' p
    | ctyp' (Primcon p) = Primcon' p
    | ctyp' (Conts p) = Conts' p
    | ctyp' (Shamrock p) = Shamrock' p
    | ctyp' (TVar p) = TVar' p

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
                                          po,
                                          map fv vl, fe e)
    | Primcall { var, sym, dom, cod, args, bod } => Primcall' { var = var, sym = sym,
                                                                dom = map ft dom,
                                                                cod = ft cod,
                                                                args = map fv args,
                                                                bod = fe bod }
    | Native { var, po, tys, args, bod } => Native' { var = var, po = po, tys = map ft tys,
                                                      args = map fv args, bod = fe bod }
    | Put (vv, v, e) => Put' (vv, fv v, fe e)
    | Letsham (vv, v, e) => Letsham' (vv, fv v, fe e)
    | Leta (vv, v, e) => Leta' (vv, fv v, fe e)
    | WUnpack (vv1, vv2, v, e) => WUnpack' (vv1, vv2, fv v, fe e)
    | TUnpack (vv1, vd, vv2, v, e) => TUnpack' (vv1, vd, vv2, fv v, fe e)
    | Case (v, vv, sel, def) => Case' (fv v, vv, ListUtil.mapsecond fe sel, fe def)
    | Intcase (v, iel, def) => Intcase' (fv v, ListUtil.mapsecond fe iel, fe def)
    | ExternVal (v, l, t, wo, e) => ExternVal' (v, l, ft t, Option.map fw wo, fe e)
    | ExternWorld (l, k, e) => ExternWorld' (l, k, fe e)
    | ExternType (v, l, vso, e) => ExternType' (v, l, vso, fe e)
    | Say (v, stl, k, e) => Say' (v, ListUtil.mapsecond ft stl, fv k, fe e)
    | Say_cc (v, stl, k, e) => Say_cc' (v, ListUtil.mapsecond ft stl, fv k, fe e)

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
    | Inline v => Inline' ` fv v
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

  fun pointwiset ft typ = pointwisetw (fn w => w) ft typ
  fun pointwisee ft fv fe exp = pointwiseew (fn w => w) ft fv fe exp
  fun pointwisev ft fv fe value = pointwisevw (fn w => w) ft fv fe value

  val ttt = Product' nil
  val vvv = Int' (IntConst.fromInt 0)
  val eee = Halt'

  fun appwiset ft typ = ignore ` pointwiset (fn t => (ft t; ttt)) typ
  fun appwisev ft fv fe value =
    ignore `
    pointwisev (fn t => (ft t; ttt)) (fn v => (fv v; vvv)) (fn e => (fe e; eee)) 
               value
  fun appwisee ft fv fe exp =
    ignore `
    pointwisee (fn t => (ft t; ttt)) (fn v => (fv v; vvv)) (fn e => (fe e; eee)) 
               exp

  fun occursw var (w : world) =
    case world w of
      W var' => if V.eq (var, var') then raise Occurs else w
    | WC _ => w

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

end
