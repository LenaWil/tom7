
signature INPUT =
sig

    exception Input of string

    (* An input device: The keyboard or a joystick. *)
    eqtype device
    type mapping

    (* Currently we don't try to figure out which accelerometer axis is
       which, since we only use them for dancing. *)
    datatype axis =
        AxisWhammy
      | AxisUnknown of int

    (* These are the kinds of events that the game can receive from configure devices. *)
    datatype inevent =
        StrumUp
      | StrumDown
      | ButtonUp of int
      | ButtonDown of int
      (* These are just impulse events (no 'up') *)
      | Drum of int

        (* Axis is (above) and a float 0.0--1.0 indicating its position out of
           its configured min--max range. *)
      | Axis of axis * real

    (* We assume the up/down action of a button is on the same
       key or button, otherwise everything will be screwed up.
       So we configure with respect to configevents, not inevents. *)
    datatype configevent =
        C_StrumUp
      | C_StrumDown
      | C_Button of int
      | C_Drum of int

    (* These are physical thingies that can be pressed and released. They
       have SDL events (up and down) associated with them. *)
    datatype actualbutton =
        Key of SDL.sdlk
      | JButton of int
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
    val setmap : device -> actualbutton -> configevent -> unit
    val restoremap : device -> mapping -> unit
    (* only for joysticks *)
    val setaxis : device -> { which : int, axis : axis, min : int, max : int } -> unit

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
    (* Load after registering joysticks to restore saved configuration for them *)
    val load : unit -> unit

end
