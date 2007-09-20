structure Leaf =
struct

  datatype primcon = 
    VEC 
  | REF
    (* the type of dictionaries for this type *)
  | DICTIONARY
  | INT
  | STRING
  | EXN
    (* marshalled data *)
  | BYTES 

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

  datatype primop = 
      (* binds uvar *)
      LOCALHOST 
      (* binds regular var *)
    | BIND 
      (* takes 'a dict and 'a -> bytes *)
    | MARSHAL
      (* takes a unit cont (or closure) and reifies it as a js string *)
    (* | SAY | SAY_CC *)

  fun primop_cmp (LOCALHOST, LOCALHOST) = EQUAL
    | primop_cmp (LOCALHOST, _) = LESS
    | primop_cmp (_, LOCALHOST) = GREATER
    | primop_cmp (BIND, BIND) = EQUAL
    | primop_cmp (BIND, _) = LESS
    | primop_cmp (_, BIND) = GREATER
    | primop_cmp (MARSHAL, MARSHAL) = EQUAL
(*
    | primop_cmp (MARSHAL, _) = LESS
    | primop_cmp (_, MARSHAL) = GREATER
    | primop_cmp (SAY, SAY) = EQUAL
    | primop_cmp (SAY, _) = LESS
    | primop_cmp (_, SAY) = GREATER
    | primop_cmp (SAY_CC, SAY_CC) = EQUAL
*)

  datatype leaf =
    (* worlds *)
    (* XXX Not necessary: we now have real variable occurrences 
       for worlds thanks to AST *) W_ | 
    WC_ of string |
    (* types *)
    AT_ | CONT_ | CONTS_ | ALLARROW_ | WEXISTS_ | TEXISTS_ | PRODUCT_ | TWDICT_ | ADDR_ |
    MU_ | SUM_ | SHAMROCK_ | TVAR_ | PRIMCON_ of primcon | NONCARRIER_ |
    (* exps *)
    CALL_ | HALT_ | GO_ | GO_CC_ | GO_MAR_ | PRIMOP_ of primop |
    PUT_ | LETSHAM_ | LETA_ | WUNPACK_ | TUNPACK_ | CASE_ | INTCASE_ | EXTERNVAL_ |
    EXTERNWORLD_ of IL.worldkind | EXTERNTYPE_ | PRIMCALL_ | NATIVE_ of Primop.primop |
    SAY_ | 
    (* vals *)
    LAMS_ | FSEL_ | VINT_ of IL.intconst | VSTRING_ | PROJ_ | RECORD_ | HOLD_ | WPACK_ |
    TPACK_ | SHAM_ | INJ_ | ROLL_ | UNROLL_ | CODELAB_ | WDICTFOR_ | WDICT_ |
    DICTFOR_ | DICT_ | ALLLAM_ | ALLAPP_ | VLETA_ | VLETSHAM_ | VTUNPACK_ |
    INLINE_ |
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

    | (INTCASE_, INTCASE_) => EQUAL
    | (INTCASE_, _) => LESS
    | (_, INTCASE_) => GREATER

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

    | (SAY_, SAY_) => EQUAL
    | (SAY_, _) => LESS
    | (_, SAY_) => GREATER

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

    | (INLINE_, INLINE_) => EQUAL
    | (INLINE_, _) => LESS
    | (_, INLINE_) => GREATER

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

end
