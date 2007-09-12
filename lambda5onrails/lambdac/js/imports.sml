
structure JSImports =
struct

  datatype jstype = JS_EVENT

  fun importtype "event" = SOME JS_EVENT
    | importtype _ = NONE

end
