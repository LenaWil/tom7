
signature CPSPRINT =
sig

    val ttol : CPS.ctyp -> Layout.layout
    val vtol : CPS.cval -> Layout.layout
    val etol : CPS.cexp -> Layout.layout

end