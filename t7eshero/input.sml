
structure Input :> INPUT =
struct

    exception Input of string
    structure Joystick = SDL.Joystick

    datatype device =
        Keyboard
        (* index into joys array *)
      | Joy of int

    datatype inevent =
        StrumUp
      | StrumDown
      | ButtonUp of int
      | ButtonDown of int
        (* XXX axes... *)

    type joyinfo = 
        { joy : SDL.joy,
          name : string,
          axes : int,
          balls : int,
          hats : int,
          buttons : int }
    val joys = ref (Array.fromList nil) : joyinfo Array.array ref

    fun devicename Keyboard = "Keyboard"
      | devicename (Joy i) =
        let val { name, axes, balls, hats, buttons, ... } = Array.sub(!joys, i)
        in
            Int.toString i ^ ": " ^ 
            name ^ " " ^ Int.toString axes ^ "/" ^ Int.toString balls ^ "/" ^
            Int.toString hats ^ "/" ^ Int.toString buttons
        end

    fun devices () = Keyboard :: List.tabulate(Array.length(!joys), fn i => Joy i)

    fun register_all () =
        let
        in
            joys :=
            Array.tabulate(Joystick.number () - 1, 
                           (fn i => 
                            let val j = Joystick.openjoy i
                            in { joy = j,
                                 name = Joystick.name i,
                                 axes = Joystick.numaxes j,
                                 balls = Joystick.numballs j,
                                 hats = Joystick.numhats j,
                                 buttons = Joystick.numbuttons j }
                            end));
            Joystick.setstate Joystick.ENABLE
        end



    fun save () = raise Input "unimplemented"
    fun load () = raise Input "unimplemented"

end