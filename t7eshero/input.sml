
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
      | JButton of int
      | JHat of { hat : int, state : SDL.Joystick.hatstate }
    (* ... more, if we support them *)

    datatype configevent =
        C_StrumUp
      | C_StrumDown
      | C_Button of int

    type mapping = (rawevent * configevent) list
    val mempty = nil
    fun minsert nil (k, v) = [(k, v)]
      | minsert ((kk, vv) :: r) (k, v) = if (k = kk) then (k, v) :: r
                                         else (kk, vv) :: minsert r (k, v)
    fun mlookup nil k = NONE
      | mlookup ((kk, vv) :: r) k = if k = kk then SOME vv else mlookup r k

    type joyinfo = 
        { joy : SDL.joy,
          name : string,
          axes : int,
          balls : int,
          hats : int,
          buttons : int,
          mapping : mapping }
    val joys = ref (Array.fromList nil) : joyinfo Array.array ref
    val keymap = ref mempty : mapping ref

    fun getmap Keyboard = !keymap
      | getmap (Joy i) = #mapping (Array.sub(!joys, i))

    fun restoremap Keyboard m = keymap := m
      | restoremap (Joy i) m =
        let val { joy, name, axes, balls, hats, buttons, mapping } = Array.sub(!joys, i)
        in
            Array.update(!joys, i,
                         { joy = joy, name = name, axes = axes, balls = balls, hats = hats,
                           buttons = buttons, mapping = m })
        end


    (* FIXME need default keyboard mapping *)
    fun clearmap Keyboard = restoremap Keyboard mempty
        (* XXX could use default repository of configs? *)
      | clearmap (Joy i) = restoremap (Joy i) mempty

    fun setmap dev re ine = restoremap dev (minsert (getmap dev) (re, ine))

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
                            in 
                               print ("Registering joystick " ^ Joystick.name i ^ "\n");
                               { joy = j,
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
        let
            datatype dir = PRESS | RELEASE
            fun withdir d PRESS   (C_Button f)  = (d, ButtonDown f)
              | withdir d RELEASE (C_Button f)  = (d, ButtonUp f)
              | withdir d _       (C_StrumDown) = (d, StrumDown)
              | withdir d _       (C_StrumUp)   = (d, StrumUp)
        in
        (case e of
             SDL.E_KeyDown _ => NONE (* XXX unimplemented *)
           | SDL.E_JoyDown { which, button, ... } =>
            (case mlookup (getmap (Joy which)) (JButton button) of
                 SOME ce => SOME(withdir (Joy which) PRESS ce)
               | NONE => NONE)

           | SDL.E_JoyUp { which, button, ... } =>
            (case mlookup (getmap (Joy which)) (JButton button) of
                 SOME ce => SOME(withdir (Joy which) RELEASE ce)
               | NONE => NONE)

           | SDL.E_JoyHat { which, hat, state, ... } =>
                  (* Assumes that centered hat is "release".

                     XXX But there's a minor problem: If we have the
                     hat configured for strumming in the up-down
                     direction, and someone holds up (1 correct
                     strum), and then while holding up somehow
                     triggers left/right movement, we get an incorrect
                     strum for each time we come back to the up
                     position. This doesn't happen on the guitars I've
                     observed so far. *)
                 (* XXX Actually this won't let us use the hat as a button, because we're looking
                    it up by a specific state. I'll try to fix it if I ever find a guitar that
                    works that way. *)
             (case mlookup (getmap (Joy which)) (JHat { hat = hat, state = state }) of
                  SOME ce => 
                      if Joystick.hat_centered state
                      then SOME(withdir (Joy which) RELEASE ce)
                      else SOME(withdir (Joy which) PRESS   ce)
                | NONE => NONE)
           | _ => NONE)
        end

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