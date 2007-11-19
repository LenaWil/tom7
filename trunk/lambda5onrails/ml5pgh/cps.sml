
structure CPS :> CPS =
struct
  
  structure V = Variable
  structure VS = V.Set
  infixr 9 `
  fun a ` b = a b

  exception CPS of string

  open Leaf

  datatype worldkind = datatype IL.worldkind

  (* a variable can be type, universal, modal, or world *)
  datatype allvar = TV of V.var | UV of V.var | MV of V.var | WV of V.var

  fun allvar_cmp (TV v1, TV v2) = V.compare (v1, v2)
    | allvar_cmp (TV _, _) = LESS
    | allvar_cmp (_, TV _) = GREATER
    | allvar_cmp (UV v1, UV v2) = V.compare (v1, v2)
    | allvar_cmp (UV _, _) = LESS
    | allvar_cmp (_, UV _) = GREATER
    | allvar_cmp (MV v1, MV v2) = V.compare (v1, v2)
    | allvar_cmp (MV _, _) = LESS
    | allvar_cmp (_, MV _) = GREATER
    | allvar_cmp (WV v1, WV v2) = V.compare (v1, v2)

  fun allvar_eq (v1, v2) = allvar_cmp (v1, v2) = EQUAL
  fun allvar_vary (TV v) = TV (V.alphavary v)
    | allvar_vary (UV v) = UV (V.alphavary v)
    | allvar_vary (MV v) = MV (V.alphavary v)
    | allvar_vary (WV v) = WV (V.alphavary v)
  fun allvar_tostring (TV v) = "TV." ^ V.tostring v
    | allvar_tostring (UV v) = "UV." ^ V.tostring v
    | allvar_tostring (MV v) = "MV." ^ V.tostring v
    | allvar_tostring (WV v) = "WV." ^ V.tostring v

  structure AST = ASTFn(type var = allvar
                        val var_cmp = allvar_cmp
                        val var_eq = allvar_eq
                        val var_vary = allvar_vary
                        val var_tostring = allvar_tostring
                        val Exn = CPS
                        type leaf = leaf
                        val leaf_cmp = leaf_cmp)

  open AST
  (* shadow AST's var *)
  type var = V.var


  datatype arminfo = datatype IL.arminfo
  datatype worldfront = W of Variable.var | WC of string

  type cglo = ast
  type cval = ast
  type ctyp = ast
  type cexp = ast
  type world = ast

  datatype ('tbind, 'ctyp, 'wbind, 'world) ctypfront =
      At of 'ctyp * 'world
    | Cont of 'ctyp list
    | Conts of 'ctyp list list
    | AllArrow of { worlds : 'wbind list, tys : 'tbind list, vals : 'ctyp list, body : 'ctyp }
    | WExists of 'wbind * 'ctyp
    | TExists of 'tbind * 'ctyp list
    | Product of (string * 'ctyp) list
    | TWdict of 'world
    | Addr of 'world
    (* all variables bound in all arms *)
    | Mu of int * ('tbind * 'ctyp) list
    | Sum of (string * 'ctyp IL.arminfo) list
    | Primcon of primcon * 'ctyp list
    | Shamrock of 'wbind * 'ctyp
    | TVar of var
    
  infixr / \ // \\

  (* -------- injections:   worlds ------- *)

  fun W' wv = VV (WV wv)
  fun WC' s = $$(WC_ s)

  (* -------- injections:   types -------- *)

  fun At' (t, w) = $$AT_ // t // w
  fun Cont' tl = $$CONT_ // SS tl
  fun Conts' tll = $$CONTS_ // SS (map SS tll)
  fun AllArrow' { worlds, tys, vals, body } = $$ALLARROW_ // BB (map WV worlds,
                                                                 BB(map TV tys,
                                                                    SS vals // body))
  fun WExists' (wv, t) = $$WEXISTS_ // (WV wv \\ t)
  fun TExists' (tv, tl) = $$TEXISTS_ // (TV tv \\ SS tl)
  fun Product' stl = $$PRODUCT_ // SS (map op// ` ListUtil.mapfirst ($$ o STRING_) stl)
  fun TWdict' w = $$TWDICT_ // w
  fun Addr' w = $$ADDR_ // w

  (* XXX should canonicalize these so that equations work out at AST level. *)
  fun Mu' (i, vtl : (V.var * ctyp) list) = $$MU_ // $$(INT_ i) // BB(map (TV o #1) vtl, SS (map #2 vtl))
  fun Sum' (sail : (string * ctyp IL.arminfo) list) =
    $$SUM_ // SS (map (fn (s, NonCarrier) => $$(STRING_ s) // $$NONCARRIER_
                        | (s, Carrier { definitely_allocated, carried }) =>
                       $$(STRING_ s) // $$(BOOL_ definitely_allocated) // carried) sail)

  fun Primcon' (pc, tl) = $$(PRIMCON_ pc) // SS tl
  fun Shamrock' (wv, t) = $$SHAMROCK_ // (WV wv \\ t)
  fun TVar' v = VV (TV v)

  (* -------- injections:   exps -------- *)

  fun Call' (v, vl) = $$CALL_ // v // SS vl
  val Halt' = $$HALT_
  fun Go' (w, v, e) = $$GO_ // w // v // e
  fun Go_cc' { w, addr, env, f } = $$GO_CC_ // w // addr // env // f
  fun Go_mar' { w, addr, bytes } = $$GO_MAR_ // w // addr // bytes
  fun Primop' (vl, po, va, exp) = 
    let in
      (* simplify in place for var to var bindings. *)
      case (vl, po, map look va) of
        ([v], Leaf.BIND, [V (MV mv)]) => 
          let in
            (* print "bind var/var simplified\n"; *)
            sub (VV (MV mv)) (MV v) exp
          end
      | _ => $$(PRIMOP_ po) // SS va // BB(map MV vl, exp)
    end
  fun Primcall' { var, sym, dom, cod, args, bod } =
    $$PRIMCALL_ // $$(STRING_ sym) // SS dom // cod // SS args // (MV var \\ bod)
  fun Native' { var, po, tys, args, bod } =
    $$(NATIVE_ po) // SS tys // SS args // (MV var \\ bod)
  fun Put' (v, va, e) = $$PUT_ // va // (UV v \\ e)
  fun Letsham' (v, va, e) = $$LETSHAM_ // va // (UV v \\ e)
  fun Leta' (v, va, e) = $$LETA_ // va // (MV v \\ e)
  fun WUnpack' (wv, dv, va, e) = $$WUNPACK_ // va // (WV wv \\ UV dv \\ e)
  fun TUnpack' (tv, dv, vtl : (var * ctyp) list, va, e) = 
    $$TUNPACK_ // va // (TV tv \\ 
                         UV dv \\ 
                         (SS (map #2 vtl) //
                          BB (map (MV o #1) vtl, e)))
  fun Case' (va, v, sel, def) =
    $$CASE_ // va // (MV v \\ SS ` map (fn (s, e) =>
                                        $$(STRING_ s) // e) sel) // def
  fun Intcase' (va, iel, def) =
    $$INTCASE_ // va // SS ` map (fn (i, e) =>
                                  $$(VINT_ i) // e) iel // def

  fun ExternVal' (v, s, t, wo, e) =
    $$EXTERNVAL_ // $$(STRING_ s) // t // (case wo of
                                             SOME w => w // (MV v \\ e)
                                           | NONE => $$NONE_ // (UV v \\ e))

  fun ExternWorld' (s, wk, e) = $$(EXTERNWORLD_ wk) // $$(STRING_ s) // e
  fun ExternType' (tv, s, vso, e) =
    $$EXTERNTYPE_ // $$(STRING_ s) // (case vso of
                                         SOME (dv, s) => $$(STRING_ s) // (TV tv \\ UV dv \\ e)
                                       | NONE => $$NONE_ // (TV tv \\ e))

  fun Sayb b (v, stl, va : ast, e : ast) = 
                               $$SAY_ // $$(BOOL_ b) //
                               SS ` map (fn (s, t) =>
                                         $$(STRING_ s) // t) stl //
                               va // (MV v \\ e)

  val Say' = Sayb false
  val Say_cc' = Sayb true

  (* -------- injections:   vals -------- *)

  (* function names bound in all bodies.. *)
  fun Lams' vael = $$LAMS_ // BB (map (MV o #1) vael,
                                  SS ` map (fn (_, a : (var * ctyp) list, e) =>
                                            SS (map #2 a) //
                                            BB (map (MV o #1) a, e)) vael)
  fun Fsel' (va, i) = $$FSEL_ // va // $$(INT_ i)
  fun Int' i = $$(VINT_ i)
  fun String' s = $$VSTRING_ // $$(STRING_ s)
  fun Proj' (s, v) = $$PROJ_ // $$(STRING_ s) // v
  fun Record' svl = $$RECORD_ // SS (map (fn (s, v) => $$(STRING_ s) // v) svl)
  fun Hold' (w, va) = $$HOLD_ // w // va
  fun WPack' _ = raise CPS "unimplemented wpack"
  fun TPack' (t, ann, d, vals) = $$TPACK_ // t // ann // d // SS vals
  fun Sham' (wv, va) = $$SHAM_ // (WV wv \\ va)
  fun Inj' (s, t, vo) = $$INJ_ // $$(STRING_ s) // t // (case vo of
                                                           NONE => $$NONE_
                                                         | SOME v => v)
  fun Roll' (ty, va) = $$ROLL_ // ty // va
  fun Unroll' va = $$UNROLL_ // va
  fun Codelab' s = $$CODELAB_ // $$(STRING_ s)
  fun Var' v = VV (MV v)
  fun UVar' u = VV (UV u)
  fun WDictfor' w = $$WDICTFOR_ // w
  fun WDict' s = $$WDICT_ // $$(STRING_ s)
  fun Dictfor' t = $$DICTFOR_ // t
  fun AllLam' { worlds, tys, vals : (var * ctyp) list, body } =
    $$ALLLAM_ // BB(map WV worlds,
                    BB(map TV tys,
                       SS (map #2 vals) //
                       BB (map (MV o #1) vals, body)))
  fun AllApp' { f, worlds, tys, vals } = $$ALLAPP_ // f // SS worlds // SS tys // SS vals
  fun VLeta' (v, va, va') = $$VLETA_ // va // (MV v \\ va')
  fun VLetsham' (v, va, va') = $$VLETSHAM_ // va // (UV v \\ va')
  fun VTUnpack' (tv, dv, vtl : (var * ctyp) list, va, bod) = 
    $$VTUNPACK_ // va // (TV tv \\ 
                          UV dv \\ 
                          (SS (map #2 vtl) //
                           BB (map (MV o #1) vtl, bod)))
  fun Inline' v = $$INLINE_ // v

  (* slicker way to do this? *)
  fun Dict' tf = $$DICT_ //
    (case tf : (var * var, cval, var * var, cval) ctypfront of
       At (t, w) => $$AT_ // t // w
     | Cont tl => $$CONT_ // SS tl
     | Conts tll => $$CONTS_ // SS (map SS tll)
     | AllArrow { worlds, tys, vals, body } => $$ALLARROW_ // BB(map WV (map #1 worlds),
                                                                 BB(map UV (map #2 worlds),
                                                                    BB(map TV (map #1 tys),
                                                                       BB(map UV (map #2 tys),
                                                                          SS vals // body))))
     | WExists (wv, t) => $$WEXISTS_ // (WV (#1 wv) \\ UV (#2 wv) \\ t)
     | TExists (tv, tl) => $$TEXISTS_ // (TV (#1 tv) \\ UV (#2 tv) \\ SS tl)
     | Product stl => $$PRODUCT_ // SS (map op// ` ListUtil.mapfirst ($$ o STRING_) stl)
     | TWdict w => $$TWDICT_ // w
     | Addr w => $$ADDR_ // w
     | Mu (i, vtl) => $$MU_ // $$(INT_ i) // 
         let val (vl, tl) = ListPair.unzip vtl
         in
           BB(map TV (map #1 vl),
              BB(map UV (map #2 vl),
                 SS tl))
         end
     | Sum sail =>
         $$SUM_ // SS (map (fn (s, NonCarrier) => $$(STRING_ s) // $$NONCARRIER_
                             | (s, Carrier { definitely_allocated, carried }) =>
                            $$(STRING_ s) // $$(BOOL_ definitely_allocated) // carried) sail)
     | Primcon (pc, tl) => $$(PRIMCON_ pc) // SS tl
     | Shamrock ((wv, dv), t) => $$SHAMROCK_ // (WV wv \\ UV dv \\ t)
     | TVar v => raise CPS "dict tvar not allowed")

  (* -------- injections:   globals -------- *)

  fun PolyCode' (v, va, t) = $$POLYCODE_ // (WV v \\ (va // t))
  fun Code' (va, t, s) = $$CODE_ // va // t // $$(STRING_ s)

  datatype ('cexp, 'cval) cexpfront =
      Call of 'cval * 'cval list
    | Halt
    | Go of world * 'cval * 'cexp
      (* post closure conversion *)
    | Go_cc of { w : world, addr : 'cval, env : 'cval, f : 'cval }
      (* post marshaling conversion *)
    | Go_mar of { w : world, addr : 'cval, bytes : 'cval }
    | Primop of var list * primop * 'cval list * 'cexp
      (* call to external function *)
    | Primcall of { var : var, sym : string, dom : ctyp list, cod : ctyp, args : 'cval list, bod : 'cexp }
      (* some built-in thing *)
    | Native of { var : var, po : Primop.primop, tys : ctyp list, args : 'cval list, bod : 'cexp }
    | Put of var * 'cval * 'cexp
    | Letsham of var * 'cval * 'cexp
    | Leta of var * 'cval * 'cexp
    (* world var, XXXWD dict, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    (* typ var, dict var, contents vars *)
    | TUnpack of var * var * (var * ctyp) list * 'cval * 'cexp
    (* contents var only bound in arms, not default *)
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | Intcase of 'cval * (IL.intconst * 'cexp) list * 'cexp
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of string * worldkind * 'cexp
    (* always kind 0; optional argument is a value import of the 
       (valid) dictionary for that type *)
    | ExternType of var * string * (var * string) option * 'cexp
    | Say of var * (string * ctyp) list * 'cval * 'cexp
    | Say_cc of var * (string * ctyp) list * 'cval * 'cexp

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
    | Inline of 'cval
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

  type program  = { 
                    (* The world constants. *)
                    worlds : (string * worldkind) list,
                    (* The globals (hoisted code). Before hoisting,
                       there is usually only the main *)
                    globals : (string * cglo) list,
                    (* The entry point for the program. *)
                    main : string

                    }
    
  (* ------------ outjections: worlds ------- *)
  fun world a =
    case look a of 
      $(WC_ s) => WC s
    | V (WV wv) => W wv
    | _ => raise CPS "bad world"

  (* ------------ outjections: types ------- *)
  fun pair a =
    case look a of
      x / y => (x, y)
    | _ => raise CPS "expected pair"

  fun WVi (WV wv) = wv
    | WVi _ = raise CPS "expected WV"
  fun TVi (TV tv) = tv
    | TVi _ = raise CPS "expected TV"
  fun MVi (MV mv) = mv
    | MVi _ = raise CPS "expected MV"
  fun UVi (UV uv) = uv
    | UVi _ = raise CPS "expected UV"
  fun SSi a = 
    case look a of
      S x => x 
    | _ => raise CPS "expected SS"
  fun STRINGi a =
    case look a of
      $(STRING_ s) => s
    | _ => raise CPS "expected STRING"
  fun INTi a =
    case look a of
      $(INT_ i) => i
    | _ => raise CPS "expected INT"
  fun VINTi a =
    case look a of
      $(VINT_ i) => i
    | _ => raise CPS "expected VINT"
  fun BOOLi a =
    case look a of
      $(BOOL_ b) => b
    | _ => raise CPS "expected BOOL"
      
  fun slash a =
    case look a of 
      l / r => (l, r)
    | _ => raise CPS "expected /"

  fun slash2 a =
    case look a of
      h / a => (h, slash a)
    | _ => raise CPS "expected /2"

  fun slash3 a =
    case look a of
      h / a => (h, slash2 a)
    | _ => raise CPS "expected /3"


  (* PERF unnecessary look/hides can have big costs
     (not true as much now that we have explicit substitutions in AST) *)
  fun ctyp a = 
    case look2 a of
      V (TV v) => TVar v
    | $AT_ / t / w => At (t, w)
    | $CONT_ / S tl => Cont tl
    | $CONTS_ / S tll => Conts (map (fn (S tl) => tl
                                      | _ => raise CPS "bad conts") (map look tll))
    | $ADDR_ / w => Addr (hide w)
    | $TWDICT_ / w => TWdict (hide w)
    | $SHAMROCK_ / (WV v \ t) => Shamrock (v, t)
    | $ALLARROW_ / B (wv, r) => 
        (case look2 r of
           B(tv, vals / body) => AllArrow { worlds = map WVi wv,
                                            tys    = map TVi tv,
                                            vals   = SSi vals,
                                            body   = body }
         | _ => raise CPS "bad allarrow")
    | $WEXISTS_ / (WV wv \ t) => WExists (wv, t)
    | $TEXISTS_ / (TV tv \ a) => TExists (tv, SSi a)
    | $SUM_ / S (arms : ast list) =>
           Sum (map (fn a =>
                     case look3 a of
                       $(STRING_ s) / $NONCARRIER_ => (s, NonCarrier)
                     | $(STRING_ s) / $(BOOL_ da) / carried => (s, Carrier { definitely_allocated = da,
                                                                             carried = hide carried })
                     | _ => raise CPS "bad sum arm") arms)
    | $MU_ / l / r =>
           (case (look l, look2 r) of
              ($(INT_ i), B(tv, S tys)) => Mu (i, ListPair.zip(map TVi tv, tys))
            | _ => raise CPS "bad mu")
    | $PRODUCT_ / S stl =>
           Product (map (fn a =>
                         case look a of
                           lab / ty => (STRINGi lab, ty)
                         | _ => raise CPS "bad product arm") stl)
    | $(PRIMCON_ pc) / S tl => Primcon (pc, tl)

    | _ => raise CPS "expected typ"

  (* ------------ outjections: values ------- *)
  fun cval ast = 
    case look2 ast of
      $LAMS_ / B(fs, lams) =>
      let val lams = map (fn a =>
                          case look2 a of
                            S tys / B (args, body) => (ListPair.zip(map MVi args, tys), body)
                          | _ => raise CPS "bad lams") (SSi lams)
      in
        Lams ` ListPair.map (fn (name, (args, body)) => (MVi name, args, body)) (fs, lams)
      end
    | $FSEL_ / va / i => Fsel (va, INTi i)
    | $(VINT_ i) => Int i
    | $VSTRING_ / $(STRING_ s) => String s
    | $PROJ_ / lab / va => Proj(STRINGi lab, va)
    | $RECORD_ / S arms => Record ` map (fn a =>
                                         case look a of
                                           str / v => (STRINGi str, v)
                                         | _ => raise CPS "bad record arm") arms
    | $HOLD_ / w / va => Hold (w, va)
    | $WPACK_ / _ => raise CPS "unimplemented wpackout"
    | $TPACK_ / t / r => let val (ann, (d, vals)) = slash2 r
                         in TPack (t, ann, d, SSi vals)
                         end
    | $SHAM_ / (WV wv \ va) => Sham (wv, va)
    | $INJ_ / lab / r => (case look r of
                           t / vo => Inj (STRINGi lab, t, (case look vo of
                                                             $NONE_ => NONE
                                                           | _ => SOME vo))
                         | _ => raise CPS "bad inj")
    | $ROLL_ / ty / va => Roll (ty, va)
    | $UNROLL_ / va => Unroll (hide va)
    | $CODELAB_ / $(STRING_ s) => Codelab s
    | V (MV v) => Var v
    | V (UV u) => UVar u
    | $ALLLAM_ / B(worlds, bind) =>
                         (case look3 bind of
                            B (tys, S valts / B(vals, bod)) => AllLam { worlds = map WVi worlds,
                                                                        tys = map TVi tys,
                                                                        vals = ListPair.zip(map MVi vals,
                                                                                            valts),
                                                                        body = bod }
                          | _ => raise CPS "bad alllam")
    | $ALLAPP_ / f / r => let val (worlds, (tys, vals)) = slash2 r
                          in AllApp { f = f, worlds = SSi worlds, tys = SSi tys, vals = SSi vals }
                          end
    | $VLETA_ / va / r => (case look r of
                            MV v \ va' => VLeta (v, va, va')
                          | _ => raise CPS "bad vleta")
    | $VLETSHAM_ / va / r => (case look r of
                                UV v \ va' => VLetsham(v, va, va')
                              | _ => raise CPS "bad vletsham")
    | $INLINE_ / va => Inline(hide va)
    | $WDICTFOR_ / w => WDictfor ` hide w
    | $WDICT_ / $(STRING_ s) => WDict s
    | $DICTFOR_ / t => Dictfor ` hide t
    | $VTUNPACK_ / va / r =>
         (case look4 r of
            TV tv \ UV dv \ (S tys / B (vars, e)) => VTUnpack (tv, dv, 
                                                               ListPair.zip(map MVi vars, tys), 
                                                               va, e)
          | _ => raise CPS "bad vtunpack")
    | $DICT_ / what / r => Dict
        (case look what / look r of
           $AT_ / t / w => At (t, w)
         | $ADDR_ / w => Addr ` hide w
         | $TWDICT_ / w => TWdict ` hide w
         | $WEXISTS_ / (WV wv \ r) =>
           (case look r of
              UV dv \ t => WExists ((wv, dv), t)
            | _ => raise CPS "bad wexists dict")

         | $TEXISTS_ / (TV tv \ r) => 
           (case look r of
              UV dv \ tl => TExists ((tv, dv), SSi tl)
            | _ => raise CPS "bad texists dict")
         | $PRODUCT_ / S stl =>
              Product (map (fn a =>
                            case look a of
                              lab / t => (STRINGi lab, t)
                            | _ => raise CPS "bad product dict") stl)
         | $MU_ / i / r =>
              (case look3 r of
                 B(tvl, B(dvl, S tl)) =>
                   Mu (INTi i, ListUtil.map3 (fn (tv, dv, t) => ((TVi tv, UVi dv), t)) tvl dvl tl)
               | _ => raise CPS "bad mu")
         | $SUM_ / S stl =>
              Sum (map (fn a =>
                        case look2 a of
                          $(STRING_ s) / da / ca => (s, Carrier { definitely_allocated = BOOLi da,
                                                                  carried = ca })
                        | $(STRING_ s) / $NONCARRIER_ => (s, NonCarrier)
                        | _ => raise CPS "bad sum arm") stl)
         | $CONT_ / S tl => Cont tl
         | $CONTS_ / S tll => Conts (map SSi tll)
         | $ALLARROW_ / B(wv, r) =>
              (case look4 r of
                 B(wdv, B(tv, B(tdv, vals / body))) => AllArrow { worlds = ListPair.zip (map WVi wv, 
                                                                                         map UVi wdv),
                                                                  tys = ListPair.zip (map TVi tv,
                                                                                      map UVi tdv),
                                                                  vals = SSi vals,
                                                                  body = body }
               | _ => raise CPS "bad allarrow")
         | $(PRIMCON_ pc) / S tl => Primcon (pc, tl)
         | $SHAMROCK_ / (WV wv \ bind) =>
                 (case look bind of
                    UV dv \ t => Shamrock ((wv, dv), t)
                  | _ => raise CPS "bad shamrock")
         (* no tvars. *)
         | _ => raise CPS "unimplemented or bad dict")

    | _ => raise CPS "bad cval"
      

  (* ------------ outjections: exps ------- *)

  fun cexp ast =
    case look2 ast of
      $HALT_ => Halt
    | $CALL_ / v / r => Call (v, SSi r)
    | $GO_ / w / r => (case look r of v / e => Go (w, v, e) | _ => raise CPS "bad go")
    | $GO_CC_ / w / r => (case look r of
                            addr / r =>
                              (case look r of
                                 env / f => Go_cc { w = w, addr = addr, env = env, f = f }
                               | _ => raise CPS "bad gocc")
                          | _ => raise CPS "bad gocc")
    | $GO_MAR_ / w / r => (case look r of 
                             v / b => Go_mar { w = w, addr = v, bytes = b } 
                           | _ => raise CPS "bad go")
    | $(PRIMOP_ po) / vas / bod => (case (look vas, look bod) of
                                      (S va, B(vl, exp)) => Primop(map MVi vl, po, va, exp)
                                    | _ => raise CPS "Bad primop")
    | $PRIMCALL_ / sym / r => 
      let val (dom, (cod, (args, bind))) = slash3 r
      in case (look sym, look dom, look args, look bind) of
            ($(STRING_ sym), S dom, S args, MV mv \ bod) => Primcall { var = mv, dom = dom, cod = cod,
                                                                       args = args, bod = bod, sym = sym }
          | _ => raise CPS "bad primcall"
      end
    | $(NATIVE_ po) / tys / r =>
      (case (look tys, look2 r) of
         (S tys, S args / (v \ bod)) => Native { var = MVi v, bod = bod, po = po, tys = tys, args = args }
       | _ => raise CPS "bad native")
    | $SAY_ / b / rest => 
         (case (look b, look2 rest) of
            ($(BOOL_ b), S stl / va / bind) =>
              (if b then Say_cc
               else Say)
                  (case look bind of
                     v \ e => (MVi v, map (fn x => 
                                           case look2 x of
                                             $(STRING_ s) / t => (s, hide t)
                                           | _ => raise CPS "bad say stl") stl, va, e)
                   | _ => raise CPS "bad say bind")
          | _ => raise CPS "bad say")

    | $PUT_ / va / bind => 
         (case look bind of
            (UV v \ e) => Put (v, va, e)
          | _ => raise CPS "bad put")
    | $LETA_ / va / bind => 
         (case look bind of
            (MV v \ e) => Leta (v, va, e)
          | _ => raise CPS "bad leta")
    | $LETSHAM_ / va / bind => 
         (case look bind of
            (UV v \ e) => Letsham (v, va, e)
          | _ => raise CPS "bad letsham")
    | $WUNPACK_ / va / bind =>
         (case look2 bind of
            WV wv \ UV dv \ e => WUnpack (wv, dv, va, e)
          | _ => raise CPS "bad wunpack")
    | $TUNPACK_ / va / r =>
         (case look4 r of
            TV tv \ UV dv \ (S tys / B (vars, e)) => TUnpack (tv, dv, ListPair.zip(map MVi vars, tys), va, e)
          | _ => raise CPS "bad tunpack")
    | $CASE_ / va / r =>
         (case look r of
            bind / def => 
              (case look2 bind of
                 (MV v \ S arms) => Case (va, v, map (fn a =>
                                                     case look a of
                                                       s / e => (STRINGi s, e)
                                                     | _ => raise CPS "bad case arm") arms, def)
               | _ => raise CPS "bad case bind")
          | _ => raise CPS "bad case")
    | $INTCASE_ / va / r => 
         (case look r of
            arms / def =>
              (case look arms of
                 S arms => Intcase (va, map (fn a =>
                                             case look a of
                                               i / e => (VINTi i, e)
                                             | _ => raise CPS "bad intcase arm") arms, def)
               | _ => raise CPS "bad intcase arms")
          | _ => raise CPS "bad intcase")

    | $EXTERNVAL_ / sym / r =>
         let val (t, (wo, bind)) = slash2 r
         in case (look wo, look bind) of
              ($NONE_, UV v \ e) => ExternVal (v, STRINGi sym, t, NONE, e)
            | (_, MV v \ e) => ExternVal (v, STRINGi sym, t, SOME wo, e)
            | _ => raise CPS "bad externval"
         end
    | $(EXTERNWORLD_ wk) / sym / e => ExternWorld (STRINGi sym, wk, e)
    | $EXTERNTYPE_ / sym / r =>
         (case look2 r of
            $(STRING_ s) / (TV v \ bind) => 
             (case look bind of
                UV dv \ e => ExternType (v, STRINGi sym, SOME (dv, s), e)
              | _ => raise CPS "bad externtype bind")
          | $NONE_ / (TV v \ e) => ExternType (v, STRINGi sym, NONE, e)
          | _ => raise CPS "bad externtype vso")
    | _ => raise CPS "expected cexp"

  (* ------------ outjections: globals ------- *)

  fun cglo ast =
    case look3 ast of
      $POLYCODE_ / (WV v \ (va / t)) => PolyCode(v, va, t)
    | $CODE_ / va / t / s => Code (hide va, t, STRINGi s)
    | _ => raise CPS "bad global"

  val world_cmp = ast_cmp
  val ctyp_cmp = ast_cmp
  val cval_cmp = ast_cmp
  val cglo_cmp = ast_cmp
  val cexp_cmp = ast_cmp

  fun subww w v a = sub w (WV v) a
  val subwt = subww
  val subwe = subww
  val subwv = subww
  fun subtt t v a = sub t (TV v) a
  val subtv = subtt
  val subte = subtt
  fun subvv m v a = sub m (MV v) a
  val subve = subvv
  fun subuv u v a = sub u (UV v) a
  val subue = subuv

  fun iswfreeinv w ast = isfree ast (WV w)
  val iswfreeine = iswfreeinv
  val iswfreeint = iswfreeinv
  val iswfreeinw = iswfreeinv

  fun isvfreeinv v ast = isfree ast (MV v)
  val isvfreeine = isvfreeinv
  fun isufreeinv u ast = isfree ast (UV u)
  val isufreeine = isufreeinv

  fun freevarsast ast =
    let
      val m = freevars ast
      val ( u, v, w, t ) = AST.VM.foldri (fn (var, _, (u, v, w, t)) =>
                                          (case var of
                                             WV x => (u, v, VS.add(w, x), t)
                                           | TV x => (u, v, w, VS.add(t, x))
                                           | UV x => (VS.add(u, x), v, w, t)
                                           | MV x => (u, VS.add(v, x), w, t)))
                          (VS.empty, VS.empty, VS.empty, VS.empty) m
    in
      { u = u, v = v, w = w, t = t }
    end

  fun freevarse ast =
    let val { u, v, w, t } = freevarsast ast
    in (v, u)
    end
  val freevarsv = freevarse
  fun freesvarst ast =
    let val { u, v, w, t } = freevarsast ast
    in { w = w, t = t }
    end
  val freesvarse = freesvarst
  val freesvarsv = freesvarst
  val freesvarsw = freesvarst

  fun countvinv v va = count va (MV v)
  val countvine = countvinv
  fun countuinv v va = count va (UV v)
  val countuine = countuinv

  (* if we had hashes, could maybe make this faster *)
  fun ctyp_eq p = ctyp_cmp p = EQUAL
  fun world_eq p = world_cmp p = EQUAL

  fun Shamrock0' t = Shamrock' (V.namedvar "shamt_unused", t)
  fun Sham0' va = Sham' (V.namedvar "sham_unused", va)
  fun Zerocon' pc = Primcon' (pc, nil)
  fun Tuple' l = Product' ` ListUtil.mapi (fn (a, i) => (Int.toString (i + 1), a)) l

  fun Lam' (v, vl, e) = Fsel' (Lams' [(v, vl, e)], 0)
  fun Lift' (v, cv, e) = Letsham'(v, Sham' (V.namedvar "lift_unused", cv), e)
  fun Bind' (v, cv, e) = Primop' ([v], BIND, [cv], e)
  fun Bindat' (v, w, cv, e) = Leta' (v, Hold' (w, cv), e)
  fun Marshal' (v, vd, va, e) = Primop' ([v], MARSHAL, [vd, va], e)
  fun Dictionary' t = Primcon' (DICTIONARY, [t])
  fun EProj' (v, s, va, e) = Bind' (v, Proj'(s, va), e)

end
