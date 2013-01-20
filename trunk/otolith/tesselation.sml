structure Tesselation :> TESSELATION =
struct

  structure TArg =
  struct
    type key = unit
    fun compare _ = EQUAL
    fun tostring () = ""
  end

  structure KT = KeyedTesselation(TArg)

  open KT

  exception Tesselation of string
  type tesselation = KT.keyedtesselation
  fun tesselation rect = KT.rectangle () rect

  structure N =
  struct
    open N
    fun coords n = N.coords n ()
    fun trymove n xy = N.trymove n () xy
  end

  fun closestedge s xy = KT.closestedge s () xy

  fun getnodewithin s xy d = KT.getnodewithin s () xy d

  fun splitedge s xy = KT.splitedge s () xy

  (* XXX *)
  fun check _ = ()

  fun toworld s = KT.toworld (fn () => "") s
  fun stok "" = SOME ()
    | stok _ = NONE
  fun fromworld w = KT.fromworld stok w

end
