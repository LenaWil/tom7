
signature CPSDICT =
sig
    exception CPSDict of string
    
    val translate : CPS.cexp -> CPS.cexp

end