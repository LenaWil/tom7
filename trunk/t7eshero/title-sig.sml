
signature TITLE =
sig

    (* Information on how the game is configured *)
    type config
    
    (* Display the menu. Returns a midi file to play,
       a selected difficulty level, a slowfactor, and
       a configuration. *)
    val loop : unit -> { midi : string,
                         difficulty : Hero.difficulty,
                         slowfactor : int,
                         config : config }

    (* Get the configured joystick map. 
       XXX: This should be improved to select the particular
       joystick in play, as well as allow from keyboard, etc. *)
    val joymap : config -> (int -> int)

end
