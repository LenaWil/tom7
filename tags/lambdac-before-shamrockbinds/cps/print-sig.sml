
signature CPSPRINT =
sig

    val ttol : CPS.ctyp    -> Layout.layout
    val vtol : CPS.cval    -> Layout.layout
    val etol : CPS.cexp    -> Layout.layout
    val wtol : CPS.world   -> Layout.layout
    val ptol : CPS.program -> Layout.layout


    (* display a variable, or show "_" if not free in (type/val/exp) *)
    val vbindt : Variable.var -> CPS.ctyp -> Layout.layout
    val vbindv : Variable.var -> CPS.cval -> Layout.layout
    val vbinde : Variable.var -> CPS.cexp -> Layout.layout

end