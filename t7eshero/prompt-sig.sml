(* Modal prompts with simple responses. *)
signature PROMPT =
sig

    val prompt :
        { 
          (* For these, NONE means to center *)
          x : int option,
          y : int option,
          (* For these, NONE means to choose an
             appropriate size based on the contents *)
          width : int option,
          height : int option,
          
          question : string,

          (* This will always accept 'confirm'
             and 'cancel' (e.g. enter/esc), but
             might not display a cancel string
             for purely informational prompts. *)
          ok : string,
          cancel : string option,

          (* Drawn in the top LHS if supplied *)
          icon : SDL.surface option,
          
          (* If not supplied, then don't draw these *)
          (* XXX support translucent gradients *)
          bordercolor : SDL.color option,
          bgcolortop : SDL.color option,
          bgcolorbot : SDL.color option,

          parent : Drawable.drawable

          (* XXX some way to indicate what counts as a
             confirmation / cancel joystick action? *)
          } -> bool

    (* Yes/No question *)
    val yesno : Drawable.drawable -> string -> bool
    (* Continue/Cancel question *)
    val okcancel : Drawable.drawable -> string -> bool

    (* Surprise! Something has failed. *)
    val no : Drawable.drawable -> string -> bool

    (* XXX bug, etc... *)
end