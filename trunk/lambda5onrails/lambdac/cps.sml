structure CPS :> CPS =
struct
  
  structure V = Variable
  infixr 9 `
  fun a ` b = a b

  exception CPS of string

  datatype primcon = VEC | REF | DICTIONARY | INT | STRING | EXN | BYTES
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

  datatype worldkind = datatype IL.worldkind

  datatype primop = 
      LOCALHOST 
    | BIND 
    | MARSHAL 
    | SAY | SAY_CC

  fun primop_cmp (LOCALHOST, LOCALHOST) = EQUAL
    | primop_cmp (LOCALHOST, _) = LESS
    | primop_cmp (_, LOCALHOST) = GREATER
    | primop_cmp (BIND, BIND) = EQUAL
    | primop_cmp (BIND, _) = LESS
    | primop_cmp (_, BIND) = GREATER
    | primop_cmp (MARSHAL, MARSHAL) = EQUAL
    | primop_cmp (MARSHAL, _) = LESS
    | primop_cmp (_, MARSHAL) = GREATER
    | primop_cmp (SAY, SAY) = EQUAL
    | primop_cmp (SAY, _) = LESS
    | primop_cmp (_, SAY) = GREATER
    | primop_cmp (SAY_CC, SAY_CC) = EQUAL

  datatype leaf =
    (* worlds *)
    W_ | WC_ of string |
    (* types *)
    AT_ | CONT_ | CONTS_ | ALLARROW_ | WEXISTS_ | TEXISTS_ | PRODUCT_ | TWDICT_ | ADDR_ |
    MU_ | SUM_ | SHAMROCK_ | TVAR_ | PRIMCON_ of primcon | NONCARRIER_ |
    (* exps *)
    CALL_ | HALT_ | GO_ | GO_CC_ | GO_MAR_ | PRIMOP_ of primop |
    PUT_ | LETSHAM_ | LETA_ | WUNPACK_ | TUNPACK_ | CASE_ | EXTERNVAL_ |
    EXTERNWORLD_ of worldkind | EXTERNTYPE_ | PRIMCALL_ | NATIVE_ of Primop.primop |
    (* vals *)
    LAMS_ | FSEL_ | VINT_ of IL.intconst | VSTRING_ | PROJ_ | RECORD_ | HOLD_ | WPACK_ |
    TPACK_ | SHAM_ | INJ_ | ROLL_ | UNROLL_ | CODELAB_ | WDICTFOR_ | WDICT_ |
    DICTFOR_ | DICT_ | ALLLAM_ | ALLAPP_ | VLETA_ | VLETSHAM_ | VTUNPACK_ |
    (* globals *)
    POLYCODE_ | CODE_ |

    (* data *)
    STRING_ of string | INT_ of int | BOOL_ of bool | NONE_

  fun leaf_cmp (l1, l2) =
    case (l1, l2) of
      (W_, W_) => EQUAL
    | (W_, _) => LESS
    | (_, W_) => GREATER
    | (WC_ s, WC_ s') => String.compare (s, s')
    | (WC_ _, _) => LESS
    | (_, WC_ _) => GREATER
    | (AT_, AT_) => EQUAL
    | (AT_, _) => LESS
    | (_, AT_) => GREATER
    | (CONT_, CONT_) => EQUAL
    | (CONT_, _) => LESS
    | (_, CONT_) => GREATER
    | (CONTS_, CONTS_) => EQUAL
    | (CONTS_, _) => LESS
    | (_, CONTS_) => GREATER
    | (ALLARROW_, ALLARROW_) => EQUAL
    | (ALLARROW_, _) => LESS
    | (_, ALLARROW_) => GREATER

    | (WEXISTS_, WEXISTS_) => EQUAL
    | (WEXISTS_, _) => LESS
    | (_, WEXISTS_) => GREATER

    | (TEXISTS_, TEXISTS_) => EQUAL
    | (TEXISTS_, _) => LESS
    | (_, TEXISTS_) => GREATER

    | (PRODUCT_, PRODUCT_) => EQUAL
    | (PRODUCT_, _) => LESS
    | (_, PRODUCT_) => GREATER

    | (PRIMCON_ pc, PRIMCON_ pc') => pc_cmp (pc, pc')
    | (PRIMCON_ _, _) => LESS
    | (_, PRIMCON_ _) => GREATER

    | (TWDICT_, TWDICT_) => EQUAL
    | (TWDICT_, _) => LESS
    | (_, TWDICT_) => GREATER

    | (ADDR_, ADDR_) => EQUAL
    | (ADDR_, _) => LESS
    | (_, ADDR_) => GREATER

    | (MU_, MU_) => EQUAL
    | (MU_, _) => LESS
    | (_, MU_) => GREATER

    | (SUM_, SUM_) => EQUAL
    | (SUM_, _) => LESS
    | (_, SUM_) => GREATER

    | (SHAMROCK_, SHAMROCK_) => EQUAL
    | (SHAMROCK_, _) => LESS
    | (_, SHAMROCK_) => GREATER

    | (TVAR_, TVAR_) => EQUAL
    | (TVAR_, _) => LESS
    | (_, TVAR_) => GREATER

    | (NONCARRIER_, NONCARRIER_) => EQUAL
    | (NONCARRIER_, _) => LESS
    | (_, NONCARRIER_) => GREATER

    | (CALL_, CALL_) => EQUAL
    | (CALL_, _) => LESS
    | (_, CALL_) => GREATER

    | (HALT_, HALT_) => EQUAL
    | (HALT_, _) => LESS
    | (_, HALT_) => GREATER

    | (GO_, GO_) => EQUAL
    | (GO_, _) => LESS
    | (_, GO_) => GREATER

    | (GO_CC_, GO_CC_) => EQUAL
    | (GO_CC_, _) => LESS
    | (_, GO_CC_) => GREATER

    | (GO_MAR_, GO_MAR_) => EQUAL
    | (GO_MAR_, _) => LESS
    | (_, GO_MAR_) => GREATER

    | (PRIMOP_ po, PRIMOP_ po') => primop_cmp (po, po')
    | (PRIMOP_ _, _) => LESS
    | (_, PRIMOP_ _) => GREATER

    | (PUT_, PUT_) => EQUAL
    | (PUT_, _) => LESS
    | (_, PUT_) => GREATER

    | (LETSHAM_, LETSHAM_) => EQUAL
    | (LETSHAM_, _) => LESS
    | (_, LETSHAM_) => GREATER

    | (LETA_, LETA_) => EQUAL
    | (LETA_, _) => LESS
    | (_, LETA_) => GREATER

    | (WUNPACK_, WUNPACK_) => EQUAL
    | (WUNPACK_, _) => LESS
    | (_, WUNPACK_) => GREATER

    | (TUNPACK_, TUNPACK_) => EQUAL
    | (TUNPACK_, _) => LESS
    | (_, TUNPACK_) => GREATER

    | (CASE_, CASE_) => EQUAL
    | (CASE_, _) => LESS
    | (_, CASE_) => GREATER

    | (EXTERNVAL_, EXTERNVAL_) => EQUAL
    | (EXTERNVAL_, _) => LESS
    | (_, EXTERNVAL_) => GREATER

    | (EXTERNTYPE_, EXTERNTYPE_) => EQUAL
    | (EXTERNTYPE_, _) => LESS
    | (_, EXTERNTYPE_) => GREATER

    | (PRIMCALL_, PRIMCALL_) => EQUAL
    | (PRIMCALL_, _) => LESS
    | (_, PRIMCALL_) => GREATER

    | (EXTERNWORLD_ w, EXTERNWORLD_ w') => IL.worldkind_cmp (w, w')
    | (EXTERNWORLD_ _, _) => LESS
    | (_, EXTERNWORLD_ _) => GREATER

    | (NATIVE_ p, NATIVE_ p') => Primop.primop_cmp(p, p')
    | (NATIVE_ _, _) => LESS
    | (_, NATIVE_ _) => GREATER

    | (LAMS_, LAMS_) => EQUAL
    | (LAMS_, _) => LESS
    | (_, LAMS_) => GREATER

    | (FSEL_, FSEL_) => EQUAL
    | (FSEL_, _) => LESS
    | (_, FSEL_) => GREATER

    | (VSTRING_, VSTRING_) => EQUAL
    | (VSTRING_, _) => LESS
    | (_, VSTRING_) => GREATER

    | (PROJ_, PROJ_) => EQUAL
    | (PROJ_, _) => LESS
    | (_, PROJ_) => GREATER

    | (RECORD_, RECORD_) => EQUAL
    | (RECORD_, _) => LESS
    | (_, RECORD_) => GREATER

    | (HOLD_, HOLD_) => EQUAL
    | (HOLD_, _) => LESS
    | (_, HOLD_) => GREATER

    | (WPACK_, WPACK_) => EQUAL
    | (WPACK_, _) => LESS
    | (_, WPACK_) => GREATER

    | (VINT_ i, VINT_ i') => IntConst.compare (i, i')
    | (VINT_ _, _) => LESS
    | (_, VINT_ _) => GREATER

    | (TPACK_, TPACK_) => EQUAL
    | (TPACK_, _) => LESS
    | (_, TPACK_) => GREATER

    | (SHAM_, SHAM_) => EQUAL
    | (SHAM_, _) => LESS
    | (_, SHAM_) => GREATER

    | (INJ_, INJ_) => EQUAL
    | (INJ_, _) => LESS
    | (_, INJ_) => GREATER

    | (ROLL_, ROLL_) => EQUAL
    | (ROLL_, _) => LESS
    | (_, ROLL_) => GREATER

    | (UNROLL_, UNROLL_) => EQUAL
    | (UNROLL_, _) => LESS
    | (_, UNROLL_) => GREATER

    | (CODELAB_, CODELAB_) => EQUAL
    | (CODELAB_, _) => LESS
    | (_, CODELAB_) => GREATER

    | (WDICTFOR_, WDICTFOR_) => EQUAL
    | (WDICTFOR_, _) => LESS
    | (_, WDICTFOR_) => GREATER

    | (WDICT_, WDICT_) => EQUAL
    | (WDICT_, _) => LESS
    | (_, WDICT_) => GREATER

    | (DICTFOR_, DICTFOR_) => EQUAL
    | (DICTFOR_, _) => LESS
    | (_, DICTFOR_) => GREATER

    | (DICT_, DICT_) => EQUAL
    | (DICT_, _) => LESS
    | (_, DICT_) => GREATER

    | (ALLLAM_, ALLLAM_) => EQUAL
    | (ALLLAM_, _) => LESS
    | (_, ALLLAM_) => GREATER

    | (ALLAPP_, ALLAPP_) => EQUAL
    | (ALLAPP_, _) => LESS
    | (_, ALLAPP_) => GREATER

    | (VLETA_, VLETA_) => EQUAL
    | (VLETA_, _) => LESS
    | (_, VLETA_) => GREATER

    | (VLETSHAM_, VLETSHAM_) => EQUAL
    | (VLETSHAM_, _) => LESS
    | (_, VLETSHAM_) => GREATER

    | (VTUNPACK_, VTUNPACK_) => EQUAL
    | (VTUNPACK_, _) => LESS
    | (_, VTUNPACK_) => GREATER

    | (POLYCODE_, POLYCODE_) => EQUAL
    | (POLYCODE_, _) => LESS
    | (_, POLYCODE_) => GREATER

    | (CODE_, CODE_) => EQUAL
    | (CODE_, _) => LESS
    | (_, CODE_) => GREATER

    | (STRING_ s, STRING_ s') => String.compare(s, s')
    | (STRING_ _, _) => LESS
    | (_, STRING_ _) => GREATER

    | (INT_ i, INT_ i') => Int.compare(i, i')
    | (INT_ _, _) => LESS
    | (_, INT_ _) => GREATER

    | (BOOL_ b, BOOL_ b') => Util.bool_compare (b, b')
    | (BOOL_ _, _) => LESS
    | (_, BOOL_ _) => GREATER

    | (NONE_, NONE_) => EQUAL

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

  structure AST = ASTFn(type var = allvar
                        val var_cmp = allvar_cmp
                        val var_eq = allvar_eq
                        val var_vary = allvar_vary
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

  fun W' wv = $$W_ // VV (WV wv)
  fun WC' s = $$(WC_ s)

  (* -------- injections:   types -------- *)

  fun At' (t, w) = $$AT_ // t // w
  fun Cont' tl = $$CONT_ // SS tl
  fun Conts' tll = $$CONTS_ // SS (map SS tll)
  fun AllArrow' { worlds, tys, vals, body } = $$ALLARROW_ // BB (map WV worlds,
                                                                 BB(map TV tys,
                                                                    SS vals // body))
  fun WExists' (wv, t) = $$WEXISTS_ // (WV wv \\ t)
  fun TExists' (tv, tl) = $$TEXISTS_ // (WV tv \\ SS tl)
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
  fun Primop' (vl, po, va, exp) = $$(PRIMOP_ po) // SS va // BB(map MV vl, exp)
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
  fun ExternVal' (v, s, t, wo, e) =
    $$EXTERNVAL_ // $$(STRING_ s) // t // (case wo of
                                             SOME w => w // (MV v \\ e)
                                           | NONE => $$NONE_ // (UV v \\ e))

  fun ExternWorld' (s, wk, e) = $$(EXTERNWORLD_ wk) // $$(STRING_ s) // e
  fun ExternType' (v, s, vso, e) =
    $$EXTERNTYPE_ // $$(STRING_ s) // (case vso of
                                         SOME (v, s) => $$(STRING_ s) // (TV v \\ UV v \\ e)
                                       | NONE => $$NONE_ // (TV v \\ e))

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
     | TExists (tv, tl) => $$TEXISTS_ // (WV (#1 tv) \\ UV (#2 tv) \\ SS tl)
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
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of string * worldkind * 'cexp
    (* always kind 0; optional argument is a value import of the 
       (valid) dictionary for that type *)
    | ExternType of var * string * (var * string) option * 'cexp

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
    | l / r =>
      (case (look l, look r) of
         ($W_, V (WV wv)) => W wv
       | _ => raise CPS "no")
    | _ => raise CPS "no"

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

  (* PERF unnecessary look/hides can have big costs *)
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
    | $TEXISTS_ / (WV tv \ a) => TExists (tv, SSi a)
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
  (* ------------ outjections: exps ------- *)
  (* ------------ outjections: globals ------- *)

  fun cval _ = raise CPS "unimplemented cval"
  fun cexp _ = raise CPS "unimplemented cexp"
  fun cglo _ = raise CPS "unimplemented cglo"
  val world_cmp = ast_cmp
  val ctyp_cmp = ast_cmp

  fun subww w v a = sub w (WV v) a
  val subwt = subww
  val subwe = subww
  val subwv = subww
  fun subtt t v a = sub t (TV v) a
  val subtv = subtt
  val subte = subtt
  fun subvv m v a = sub m (MV v) a
  val subve = subvv

  (* PERF could be more efficient. would be especially worth it for type_eq *)
  fun ctyp_eq p = ctyp_cmp p = EQUAL
  fun world_eq p = world_cmp p = EQUAL

  fun Shamrock0' t = Shamrock' (V.namedvar "shamt_unused", t)
  fun Sham0' va = Sham' (V.namedvar "sham_unused", va)
  fun Zerocon' pc = Primcon' (pc, nil)

  fun Lam' (v, vl, e) = Fsel' (Lams' [(v, vl, e)], 0)
  fun Lift' (v, cv, e) = Letsham'(v, Sham' (V.namedvar "lift_unused", cv), e)
  fun Bind' (v, cv, e) = Primop' ([v], BIND, [cv], e)
  fun Bindat' (v, w, cv, e) = Leta' (v, Hold' (w, cv), e)
  fun Marshal' (v, vd, va, e) = Primop' ([v], MARSHAL, [vd, va], e)
  fun Say' (v, vf, e) = Primop' ([v], SAY, [vf], e)
  fun Say_cc' (v, vf, e) = Primop' ([v], SAY_CC, [vf], e)
  fun Dictionary' t = Primcon' (DICTIONARY, [t])
  fun EProj' (v, s, va, e) = Bind' (v, Proj'(s, va), e)

end
