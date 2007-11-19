
signature DICT =
sig
    exception Dict of string
    
    (* suffix to extern type labels where we should find the dictionary *)
    val DICT_SUFFIX : string
      
    (* in existential types, the label in the record that holds the dictionary *)
    val DICT_LAB : string
    (* the label for the value *)
    val VALUE_LAB : string

    val translate : CPSTypeCheck.context -> CPS.cexp -> CPS.cexp

end