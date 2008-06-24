
structure Serialize =
struct

    exception Serialize of string

    fun QQ #"?" = true
      | QQ _ = false

    fun uo f NONE = "-"
      | uo f (SOME x) = "+" ^ f x
    fun uno f "-" = NONE
      | uno f s =
        if CharVector.sub(s, 0) = #"+"
        then SOME (f (String.substring(s, 1, size s - 1)))
        else raise Serialize "bad option"

    val ue = StringUtil.urlencode
    val une = (fn x => case StringUtil.urldecode x of
               NONE => raise Serialize "bad urlencoded string"
             | SOME s => s)
    (* To keep invariant that nothing has the empty string as a representation *)
    fun ulist nil = "%"
      | ulist l = StringUtil.delimit "?" (map ue l)
    fun unlist "%" = nil
      | unlist s = map une (String.tokens QQ s)

end
