
structure JSImports =
struct

  datatype jstype = 
    JS_EVENT
  | JS_CHAR

  (* although event itself doesn't really work *)
  fun importtype "event" = SOME JS_EVENT
    | importtype "event.keyCode" = SOME JS_CHAR
    | importtype _ = NONE

end
