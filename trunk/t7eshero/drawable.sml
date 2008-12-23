
structure Drawable :> DRAWABLE =
struct
    
    type drawable = { draw : unit -> unit,
                      resize : unit -> unit,
                      heartbeat : unit -> unit }

    fun don't () = ()
    fun drawable r = r
    val nodraw = drawable { draw = don't, resize = don't, heartbeat = don't }
    fun drawonly f = drawable { draw = f, resize = don't, heartbeat = don't }
    fun draw { draw, resize, heartbeat } = draw ()
    fun resize { draw, resize, heartbeat } = resize ()
    fun heartbeat { draw, resize, heartbeat } = heartbeat ()

end
