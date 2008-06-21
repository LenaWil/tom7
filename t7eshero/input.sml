
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

    datatype rawevent =
        Key of SDL.sdlk
      | JButton of { button : int }
      | JHat of { hat : int, state : SDL.Joystick.hatstate }
    (* ... more, if we support them *)

    type ('a, 'b) mapping = ('a * 'b) list
    val mempty = nil
    fun minsert (k, v) nil = [(k, v)]
      | minsert (k, v) ((kk, vv) :: r) = if (k = kk) then (k, v) :: r
                                         else (kk, vv) :: minsert (k, v) r

    type joyinfo = 
        { joy : SDL.joy,
          name : string,
          axes : int,
          balls : int,
          hats : int,
          buttons : int,
          mapping : (rawevent, inevent) mapping }
    val joys = ref (Array.fromList nil) : joyinfo Array.array ref
    val keymap = ref mempty : (rawevent, inevent) mapping ref

    (* FIXME need default keyboard mapping *)
    fun clearmap Keyboard = keymap := mempty
      | clearmap (Joy i) =
        let val { joy, name, axes, balls, hats, buttons, mapping = _ } = Array.sub(!joys, i)
        in
            Array.update(!joys, i,
                         { joy = joy, name = name, axes = axes, balls = balls, hats = hats,
                           buttons = buttons,
                           (* XXX could use default repository of configs? *)
                           mapping = mempty })
        end

    fun setmap Keyboard re ine = keymap := minsert (re, ine) (!keymap)
      | setmap (Joy i) re ine =
        let val { joy, name, axes, balls, hats, buttons, mapping } = Array.sub(!joys, i)
        in
            Array.update(!joys, i,
                         { joy = joy, name = name, axes = axes, balls = balls, hats = hats,
                           buttons = buttons, mapping = minsert (re, ine) mapping })
        end

    fun belongsto (SDL.E_KeyDown _) Keyboard = true
      | belongsto (SDL.E_KeyUp _) Keyboard = true (* ? *)
      | belongsto (SDL.E_JoyDown { which, ... }) (Joy w) = w = which
      | belongsto (SDL.E_JoyUp { which, ... }) (Joy w) = w = which
      | belongsto (SDL.E_JoyHat { which, ... }) (Joy w) = w = which
    (* XXX JoyAxis and JoyBall, but these are not implemented in SDLML yet! *)
      | belongsto _ _ = false

    fun devicename Keyboard = "Keyboard"
      | devicename (Joy i) =
        let val { name, axes, balls, hats, buttons, ... } = Array.sub(!joys, i)
        in
            Int.toString i ^ ": " ^ 
            name ^ " " ^ Int.toString axes ^ "/" ^ Int.toString balls ^ "/" ^
            Int.toString hats ^ "/" ^ Int.toString buttons
        end


    fun devices () = Keyboard :: List.tabulate(Array.length(!joys), fn i => Joy i)

    val already_registered = ref false
    fun register_all () =
        let
        in
            if !already_registered then raise Input "already registered."
            else ();
            already_registered := true;
            joys :=
            Array.tabulate(Joystick.number () - 1, 
                           (fn i => 
                            let val j = Joystick.openjoy i
                            in { joy = j,
                                 name = Joystick.name i,
                                 axes = Joystick.numaxes j,
                                 balls = Joystick.numballs j,
                                 hats = Joystick.numhats j,
                                 mapping = mempty,
                                 buttons = Joystick.numbuttons j }
                            end));
            Joystick.setstate Joystick.ENABLE
        end

    fun input_map e =
        NONE (* XXX *)


    fun joy n =
        if n < 0 orelse n >= Array.length(!joys)
        then raise Input "joystick out of range"
        else Joy n

    fun save () = raise Input "unimplemented"
    fun load () = raise Input "unimplemented"

    (* export *)
    val map = input_map
    val keyboard = Keyboard
end