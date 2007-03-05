
signature CPSDICT =
sig
    exception CPSDict of string
    
    (* suffix to extern type labels where we should find the dictionary *)
    val DICT_SUFFIX : string
    
    val translate : CPS.cexp -> CPS.cexp

end