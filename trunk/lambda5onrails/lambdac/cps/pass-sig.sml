
signature PASSARG =
sig

  type var = Variable.var
  type cval = CPS.cval
  type world = CPS.world
  type cexp = CPS.cexp
  type ctyp = CPS.ctyp

  type exp_result = cexp
  type val_result = cval * ctyp
  type typ_result = ctyp

  (* arbitrary extra argument *)
  type stuff 

  type context = CPSTypeCheck.context

  (* open recursive calls *)
  type selves = { selfv : stuff -> context -> CPS.cval -> CPS.cval * CPS.ctyp,
                  selfe : stuff -> context -> CPS.cexp -> CPS.cexp,
                  selft : stuff -> context -> CPS.ctyp -> CPS.ctyp }

  val case_Addr : stuff -> selves * context -> world -> typ_result
  val case_AllArrow : stuff -> selves * context -> { worlds : var list, tys : var list, vals : ctyp list, body : ctyp } -> typ_result
  val case_At : stuff -> selves * context -> ctyp * world -> typ_result
  val case_Cont : stuff -> selves * context -> ctyp list -> typ_result
  val case_Conts : stuff -> selves * context -> ctyp list list -> typ_result
  val case_Mu : stuff -> selves * context -> int * (var * ctyp) list -> typ_result
  val case_Primcon : stuff -> selves * context -> CPS.primcon * ctyp list -> typ_result
  val case_Product : stuff -> selves * context -> (string * ctyp) list -> typ_result
  val case_Shamrock : stuff -> selves * context -> var * ctyp -> typ_result
  val case_Sum : stuff -> selves * context -> (string * ctyp IL.arminfo) list -> typ_result
  val case_TExists : stuff -> selves * context -> var * ctyp list -> typ_result
  val case_TVar : stuff -> selves * context -> var -> typ_result
  val case_TWdict : stuff -> selves * context -> world -> typ_result
  val case_WExists : stuff -> selves * context -> var * ctyp -> typ_result

  val case_Say : stuff -> selves * context -> var * (string * ctyp) list * cval * cexp -> exp_result
  val case_Say_cc : stuff -> selves * context -> var * (string * ctyp) list * cval * cexp -> exp_result
  val case_Call : stuff -> selves * context -> cval * cval list -> exp_result
  val case_Intcase : stuff -> selves * context -> cval * (IL.intconst * cexp) list * cexp -> exp_result
  val case_Case : stuff -> selves * context -> cval * var * (string * cexp) list * cexp -> exp_result
  val case_ExternType : stuff -> selves * context -> var * string * (var * string) option * cexp -> exp_result
  val case_ExternVal : stuff -> selves * context -> var * string * ctyp * world option * cexp -> exp_result
  val case_ExternWorld : stuff -> selves * context -> string * CPS.worldkind * cexp -> exp_result
  val case_Go : stuff -> selves * context -> world * cval * cexp -> exp_result
  val case_Go_cc : stuff -> selves * context -> { w : world, addr : cval, env : cval, f : cval } -> exp_result
  val case_Go_mar : stuff -> selves * context -> { w : world, addr : cval, bytes : cval } -> exp_result
  val case_Halt : stuff -> selves * context -> exp_result
  val case_Leta : stuff -> selves * context -> var * cval * cexp -> exp_result
  val case_Letsham : stuff -> selves * context -> var * cval * cexp -> exp_result
  val case_Native : stuff -> selves * context -> { var : var, po : Primop.primop, tys : ctyp list, args : cval list, bod : cexp } -> exp_result
  val case_Primcall : stuff -> selves * context -> { var : var, sym : string, dom : ctyp list, cod : ctyp, args : cval list, bod : cexp } -> exp_result
  val case_Primop : stuff -> selves * context -> var list * CPS.primop * cval list * cexp -> exp_result
  val case_Put : stuff -> selves * context -> var * cval * cexp -> exp_result
  val case_TUnpack : stuff -> selves * context -> var * var * (var * ctyp) list * cval * cexp -> exp_result
  val case_WUnpack : stuff -> selves * context -> var * var * cval * cexp -> exp_result

  val case_AllApp : stuff -> selves * context -> { f : cval, worlds : world list, tys : ctyp list, vals : cval list } -> val_result
  val case_AllLam : stuff -> selves * context -> { worlds : var list, tys : var list, vals : (var * ctyp) list, body : cval } -> val_result
  val case_Codelab : stuff -> selves * context -> string -> val_result
  val case_Dict : stuff -> selves * context -> (var * var, cval, var * var, cval) CPS.ctypfront -> val_result
  val case_Dictfor : stuff -> selves * context -> ctyp -> val_result
  val case_Fsel : stuff -> selves * context -> cval * int -> val_result
  val case_Hold : stuff -> selves * context -> world * cval -> val_result
  val case_Inj : stuff -> selves * context -> string * ctyp * cval option -> val_result
  val case_Inline : stuff -> selves * context -> cval -> val_result
  val case_Int : stuff -> selves * context -> IL.intconst -> val_result
  val case_Lams : stuff -> selves * context -> (var * (var * ctyp) list * cexp) list -> val_result
  val case_Proj : stuff -> selves * context -> string * cval -> val_result
  val case_Record : stuff -> selves * context -> (string * cval) list -> val_result
  val case_Roll : stuff -> selves * context -> ctyp * cval -> val_result
  val case_Sham : stuff -> selves * context -> var * cval -> val_result
  val case_String : stuff -> selves * context -> string -> val_result
  val case_TPack : stuff -> selves * context -> ctyp * ctyp * cval * cval list -> val_result
  val case_UVar : stuff -> selves * context -> var -> val_result
  val case_Unroll : stuff -> selves * context -> cval -> val_result
  val case_VLeta : stuff -> selves * context -> var * cval * cval -> val_result
  val case_VLetsham : stuff -> selves * context -> var * cval * cval -> val_result
  val case_VTUnpack : stuff -> selves * context -> var * var * (var * ctyp) list * cval * cval -> val_result
  val case_Var : stuff -> selves * context -> var -> val_result
  val case_WDict : stuff -> selves * context -> string -> val_result
  val case_WDictfor : stuff -> selves * context -> world -> val_result
  val case_WPack : stuff -> selves * context -> world * cval -> val_result

end

signature PASS =
sig

  type stuff

  val convertv : stuff -> CPSTypeCheck.context -> CPS.cval -> CPS.cval * CPS.ctyp
  val converte : stuff -> CPSTypeCheck.context -> CPS.cexp -> CPS.cexp
  val convertt : stuff -> CPSTypeCheck.context -> CPS.ctyp -> CPS.ctyp

  (* XXX convertprogram... *)

end