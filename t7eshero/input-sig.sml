
signature INPUT =
sig

    exception Input of string

    (* An input device: The keyboard or a joystick. *)
    eqtype device
    type mapping

    datatype inevent =
        StrumUp
      | StrumDown
      | ButtonUp of int
      | ButtonDown of int
        (* XXX axes... *)


    datatype rawevent =
        Key of SDL.sdlk
      | JButton of { button : int }
      | JHat of { hat : int, state : SDL.Joystick.hatstate }
    (* ... more, if we support them *)

    val keyboard : device
    val joy : int -> device


    (* Configuration *)

    val getmap : device -> mapping
    (* Erase all configured mappings for a device, so that map returns nothing
       for it. This can't clear some keyboard mappings, though, because the
       keyboard is always our last-resort input device. *)
    val clearmap : device -> unit

    (* Set the mapping for a particular device event. *)
    val setmap : device -> rawevent -> inevent -> unit
    val restoremap : device -> mapping -> unit

    (* Is this (unmapped) SDL event associated with the device? *)
    val belongsto : SDL.event -> device -> bool



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
