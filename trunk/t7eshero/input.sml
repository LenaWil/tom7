
structure Input :> INPUT =
struct

    exception Input of string
    structure Joystick = SDL.Joystick

    val FILENAME = "input.hero"

    datatype device =
        Keyboard
        (* index into joys array *)
      | Joy of int

    datatype axis =
        AxisWhammy
      | AxisUnknown of int

    datatype inevent =
        StrumUp
      | StrumDown
      | ButtonUp of int
      | ButtonDown of int
      (* These are just impulse events (no 'up') *)
      | Drum of int

      | Axis of axis * real

    datatype actualbutton =
        Key of SDL.sdlk
      | JButton of int
      | JHat of { hat : int, state : SDL.Joystick.hatstate }
    (* ... more, if we support them *)

    datatype configevent =
        C_StrumUp
      | C_StrumDown
      | C_Button of int
      | C_Drum of int

    open Serialize

    fun retostring (Key k) = "k?" ^ SDL.sdlktostring k
      | retostring (JButton i) = "b?" ^ Int.toString i
      | retostring (JHat { hat, state }) =
        "h?" ^ Int.toString hat ^ "?" ^
        ue (SDL.Joystick.hatstatetostring state)

    fun refromstring s =
        case String.tokens QQ s of
            ["k", ks] => (Key (valOf (SDL.sdlkfromstring ks)) handle Option => raise Input "bad key")
          | ["b", jb] => (JButton (valOf (Int.fromString jb)) handle Option => raise Input "bad button")
          | ["h", jh, js] => (JHat { hat = valOf (Int.fromString jh),
                                     state = valOf (SDL.Joystick.hatstatefromstring js) }
                              handle Option => raise Input "bad hat")
          | _ => raise Input ("bad re: " ^ s)

    fun cetostring (C_StrumUp) = "u"
      | cetostring (C_StrumDown) = "d"
      | cetostring (C_Button b) = "b?" ^ Int.toString b
      | cetostring (C_Drum d) = "r?" ^ Int.toString d

    fun cefromstring "u" = C_StrumUp
      | cefromstring "d" = C_StrumDown
      | cefromstring s =
        case String.tokens QQ s of
            ["b", i] => (C_Button (valOf (Int.fromString i)) handle Option => raise Input "bad ce button")
          | ["r", i] => (C_Drum (valOf (Int.fromString i)) handle Option => raise Input "bad re button")
          | _ => raise Input "bad ce"

    type mapping = (actualbutton * configevent) list
    val mempty = nil
    fun minsert nil (k, v) = [(k, v)]
      | minsert ((kk, vv) :: r) (k, v) = if (k = kk) then (k, v) :: r
                                         else (kk, vv) :: minsert r (k, v)
    fun mlookup nil k = NONE
      | mlookup ((kk, vv) :: r) k = if k = kk then SOME vv else mlookup r k

    fun mtostring l = ulist (map (fn (k, v) => ue(retostring k) ^ "?" ^ ue(cetostring v)) l)
    fun mfromstring sl =
        map (fn s =>
             case String.tokens QQ s of
                 [k, v] => (refromstring (une k), cefromstring (une v))
               | _ => raise Input "bad mapping entry") (unlist sl)


    type axisconfig = { which : int, axis : axis, min : int, max : int }
    fun axistostring AxisWhammy = "w"
      | axistostring (AxisUnknown i) = Int.toString i
    fun axisfromstring "w" = AxisWhammy
      | axisfromstring x = (AxisUnknown (valOf (Int.fromString x))) handle _ => raise Input "bad axis"

    fun atostring l =
        ulist (map (fn { which, axis, min, max } =>
                    Int.toString which ^ "?" ^ axistostring axis ^ "?" ^
                    Int.toString min ^ "?" ^ Int.toString max) l)
    fun afromstring s =
        map (fn s =>
             case String.tokens QQ s of
                 [id, axis, min, max] =>
                     { which = valOf (Int.fromString id),
                       axis = axisfromstring axis,
                       min = valOf (Int.fromString min),
                       max = valOf (Int.fromString max) }
               | _ => raise Input "bad axis entry") (unlist s)

    type joyinfo =
        { joy : SDL.joy,
          name : string,
          naxes : int,
          balls : int,
          hats : int,
          buttons : int,
          axes : axisconfig list,
          mapping : mapping }
    val joys = ref (Array.fromList nil) : joyinfo Array.array ref
    val keymap = ref mempty : mapping ref

    fun getmap Keyboard = !keymap
      | getmap (Joy i) = #mapping (Array.sub(!joys, i))

    fun restoremap Keyboard m = keymap := m
      | restoremap (Joy i) m =
        let val { joy, name, naxes, balls, hats, buttons, axes, mapping } = Array.sub(!joys, i)
        in
            Array.update(!joys, i,
                         { joy = joy, name = name, naxes = naxes, balls = balls, hats = hats,
                           buttons = buttons, mapping = m, axes = axes })
        end

    fun setaxes i a =
        let val { joy, name, naxes, balls, hats, buttons, axes, mapping } = Array.sub(!joys, i)
        in
            Array.update(!joys, i,
                         { joy = joy, name = name, naxes = naxes, balls = balls, hats = hats,
                           buttons = buttons, mapping = mapping, axes = a })
        end

    (* FIXME need default keyboard mapping *)
    fun clearmap Keyboard = restoremap Keyboard mempty
        (* XXX could use default repository of configs? *)
      | clearmap (Joy i) = restoremap (Joy i) mempty

    fun setmap dev re ine = restoremap dev (minsert (getmap dev) (re, ine))
    fun setaxis Keyboard _ = raise Input "can't set axis for a keyboard"
      | setaxis (Joy i) a =
        let
            (* all other axes *)
            val axes = List.filter (fn { which, ... } => which <> #which a) (#axes (Array.sub(!joys, i)))
        in  setaxes i (a :: axes)
        end

    fun belongsto (SDL.E_KeyDown _) Keyboard = true
      | belongsto (SDL.E_KeyUp _) Keyboard = true (* ? *)
      | belongsto (SDL.E_JoyDown { which, ... }) (Joy w) = w = which
      | belongsto (SDL.E_JoyUp { which, ... }) (Joy w) = w = which
      | belongsto (SDL.E_JoyHat { which, ... }) (Joy w) = w = which
      | belongsto (SDL.E_JoyAxis { which, ...}) (Joy w) = w = which
    (* XXX JoyAxis and JoyBall, but these are not implemented in SDLML yet! *)
      | belongsto _ _ = false

    fun devicename Keyboard = "Keyboard"
      | devicename (Joy i) =
        let val { name, naxes, balls, hats, buttons, ... } = Array.sub(!joys, i)
        in
            Int.toString i ^ ": " ^
            name ^ " " ^ Int.toString naxes ^ "/" ^ Int.toString balls ^ "/" ^
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
            print ("There are " ^ Int.toString (Joystick.number ()) ^ " joysticks.\n");
            joys :=
            Array.tabulate(Joystick.number (),
                           (fn i =>
                            let val j = Joystick.openjoy i
                            in
                               print ("Registering joystick " ^ Joystick.name i ^ "\n");
                               { joy = j,
                                 name = Joystick.name i,
                                 naxes = Joystick.numaxes j,
                                 balls = Joystick.numballs j,
                                 hats = Joystick.numhats j,
                                 axes = nil,
                                 mapping = mempty,
                                 buttons = Joystick.numbuttons j }
                            end));
            Joystick.setstate Joystick.ENABLE
        end

    fun input_map e =
        let
            datatype dir = PRESS | RELEASE
            fun withdir d PRESS   (C_Button f)  = SOME(d, ButtonDown f)
              | withdir d RELEASE (C_Button f)  = SOME(d, ButtonUp f)
              | withdir d RELEASE (C_StrumDown) = NONE
              | withdir d RELEASE (C_StrumUp)   = NONE
              | withdir d PRESS   (C_StrumDown) = SOME(d, StrumDown)
              | withdir d PRESS   (C_StrumUp)   = SOME(d, StrumUp)
              | withdir d PRESS   (C_Drum f)    = SOME(d, Drum f)
              | withdir d RELEASE (C_Drum _)    = NONE
        in
        (case e of
             SDL.E_KeyDown { sym } =>
                 (case mlookup (getmap Keyboard) (Key sym) of
                      SOME ce => withdir Keyboard PRESS ce
                    | NONE => NONE)
           | SDL.E_KeyUp { sym } =>
                 (case mlookup (getmap Keyboard) (Key sym) of
                      SOME ce => withdir Keyboard RELEASE ce
                    | NONE => NONE)

           | SDL.E_JoyAxis { which = j, axis, v } =>
            let val axes = #axes (Array.sub(!joys, j))
            in
                (* in axisconfig, which refers to the axis not the joystick *)
                case List.find (fn { which = a, ... } => a = axis) axes of
                    SOME { axis, min, max, ... } =>
                        let (* clamp to the alleged min/max *)
                            val v = Int.max(min, v)
                            val v = Int.min(max, v)
                        in
                            SOME(Joy j, Axis (axis, real (v - min) / real (max - min)))
                        end
                  | NONE => NONE
            end

           | SDL.E_JoyDown { which, button, ... } =>
            (case mlookup (getmap (Joy which)) (JButton button) of
                 SOME ce => withdir (Joy which) PRESS ce
               | NONE => NONE)

           | SDL.E_JoyUp { which, button, ... } =>
            (case mlookup (getmap (Joy which)) (JButton button) of
                 SOME ce => withdir (Joy which) RELEASE ce
               | NONE => NONE)

           | SDL.E_JoyHat { which, hat, state, ... } =>
              (* Assumes that centered hat is "release".

                 XXX But there's a minor problem: If we have the hat
                 configured for strumming in the up-down direction,
                 and someone holds up (1 correct strum), and then
                 while holding up somehow triggers left/right
                 movement, we get an incorrect strum for each time we
                 come back to the up position. This doesn't happen on
                 the guitars I've observed so far. *)
             (* XXX Actually this won't let us use the hat as a button, because
                we're looking it up by a specific state. I'll try to
                fix it if I ever find a guitar that works that way. *)
             (case mlookup (getmap (Joy which)) (JHat { hat = hat, state = state }) of
                  SOME ce =>
                      if Joystick.hat_centered state
                      then withdir (Joy which) RELEASE ce
                      else withdir (Joy which) PRESS   ce
                | NONE => NONE)
           | _ => NONE)
        end

    fun joy n =
        if n < 0 orelse n >= Array.length(!joys)
        then raise Input "joystick out of range"
        else Joy n

    fun save () =
      let
        fun joytf { joy = _, name, naxes, balls, hats, buttons, mapping, axes } =
          InputTF.J { name = name, naxes = naxes, balls = balls, hats = hats, buttons = buttons,
                      mapping = mtostring mapping, axes = atostring axes }
        val file = InputTF.F { keymap = mtostring (!keymap),
                               joys = Array.foldr (fn (j, r) => joytf j :: r) nil (!joys) }
      in
        InputTF.F.tofile FILENAME file
      end

    fun load () =
        let
          val InputTF.F { keymap = km, joys = js } =
            (case InputTF.F.maybefromfile FILENAME of
               NONE => InputTF.F.default
             | SOME f => f) handle IO.Io _ => InputTF.F.default

          val js = map (fn InputTF.J { name, naxes, balls, hats, buttons, mapping, axes } =>
                        { name = name, naxes = naxes, balls = balls,
                          hats = hats, buttons = buttons,
                          mapping = mfromstring mapping, axes = afromstring axes }) js
        in
          keymap := mfromstring km;

          (* configure these joysticks if any are currently activated. *)
          Util.for 0 (Array.length (!joys) - 1)
          (fn j =>
           let val { joy = _, name, naxes, balls, hats, buttons,
                     mapping = _, axes = _ } = Array.sub(!joys, j)
           in
             case List.find (fn { name = n, naxes = a, balls = b, hats = h, buttons = u, ... } =>
                             n = name andalso a = naxes andalso b = balls andalso h = hats
                             andalso u = buttons) js of
               NONE => print ("Didn't configure joystick #" ^ Int.toString j ^ " (" ^ name ^ ")\n")
             | SOME ({ mapping, axes, ... }) =>
                 let in
                   print ("Restoring joystick #" ^ Int.toString j ^ " (" ^ name ^ ") from saved\n");
                   restoremap (Joy j) mapping;
                   setaxes j axes
                 end
           end)
        end

    (* export *)
    val map = input_map
    val keyboard = Keyboard
end