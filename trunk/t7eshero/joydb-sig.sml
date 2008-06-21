
signature JOYDB =
sig

    exception JoyDB of string

    (* Identifies (as best as possible) a joystick using its permanent
       features. This is so that we can remember the configuration for
       a particular joystick and not get confused if a different one
       gets plugged in. *)
    eqtype joyid

    (* If this joystick number was registered with JoyDB, then return its
       joyid. Raises JoyDB if not. *)
    val id : int -> joyid

    (* Do this only once. It opens all of the joysticks and returns the
       joystick id of each one. *)
    val register_all : unit -> joyid Vector.vector

    val tostring : joyid -> string
    val fromstring : string -> joyid

end
