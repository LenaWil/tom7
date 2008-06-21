
signature INPUT =
sig

    exception Input of string

    (* An input device: The keyboard or a joystick. *)
    eqtype device

    datatype inevent =
        StrumUp
      | StrumDown
      | ButtonUp of int
      | ButtonDown of int
        (* XXX axes... *)

    (* If this SDL event corresponds to a registered device
       and it's a button with a mapping, return that. *)
    val map : SDL.event -> (device * inevent) option

    (* As best a description of the device (as currently attached) 
       as we can manage. *)
    val devicename : device -> string

    (* Do this only once. It opens all of the joysticks and returns the
       joystick id of each one. *)
    val register_all : unit -> unit

    val devices : unit -> device list


    val save : unit -> unit
    val load : unit -> unit

end
