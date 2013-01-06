(* The in-memory representation of a letter and alphabet during
   editing. Each letter has its own editing state (undo, selection,
   etc.) and the alphabet is just an array of those, one for each
   letter. *)
structure Editing =
struct

  exception Editing of string

  (* Just low ASCII. We'll probably want some non-letter characters
     with special meanings but we don't need a hundred. *)
  val RADIX = 128

  structure L = Letter
  structure CM = Letter.CM
  structure GA = GrowArray

  (* Workspace for a specific character. *)
  type workspace =
      { letter : L.letter ref,
        undostate : L.letter UndoState.undostate,
        (* Currently selected vertices. First index is the polygon,
           second is the vertex on that polygon. Often nil. *)
        selected : (int * int) list ref }

  val selected = ref nil : (int * int) list ref

  fun initial_workspace () : workspace =
      { letter = ref { polys = GA.empty () },
        undostate = UndoState.undostate (),
        selected = ref nil }

  val workspaces = Array.tabulate (RADIX, fn _ => initial_workspace ())

  local
    val current_ = ref (ord #"A")
  in
    fun set_current c =
        if c >= 0 andalso c < RADIX
        then current_ := c
        else ()
    fun current () = !current_
  end

  fun loadfromfile alphafile =
      let
          val s = StringUtil.readfile alphafile
          val a : L.alphabet = L.alphabetfromstring s
      in
          CM.appi
          (fn (ch, l) =>
           let val i = ord ch
           in if i < RADIX
              then Array.update (workspaces,
                                 i,
                                 { letter = ref l,
                                   undostate = UndoState.undostate (),
                                   selected = ref nil })
              else ()
           end) a
      end handle _ => ()

  fun savetofile alphafile =
      let
          val a = Array.foldli (fn (i,
                                    { letter = ref l, ... } : workspace,
                                    m) =>
                                (* Don't insert empty ones. *)
                                if GA.length (#polys l) > 0
                                then CM.insert (m, chr i, l)
                                else m) CM.empty workspaces
      in
          StringUtil.writefile alphafile (L.alphabettostring a)
      end

  fun letter () = !(#letter (Array.sub (workspaces, current ())))
  fun undostate () = #undostate (Array.sub (workspaces, current ()))
  fun selected () = !(#selected (Array.sub (workspaces, current ())))

  fun set_letter l = #letter (Array.sub (workspaces, current ())) := l
  fun set_selected l = #selected (Array.sub (workspaces, current ())) := l

  (* Call before making a modification to the state. Keeps the buffer
     length from exceeding MAX_UNDO. Doesn't duplicate the state if it
     is already on the undo buffer. *)
  val MAX_UNDO = 100
  fun savestate () =
      let
          val us = undostate ()
      in
          (case UndoState.peek us of
               NONE => UndoState.save us (L.copyletter (letter ()))
             | SOME prev =>
                   if L.lettereq (prev, letter ())
                   then ()
                   else UndoState.save us (L.copyletter (letter ())));
          UndoState.truncate us MAX_UNDO
      end

  fun undo () =
      (* FIXME need to clear selection, since it could contain
         invalid indices. *)
      case UndoState.undo (undostate ()) of
          NONE => ()
        | SOME s => set_letter (L.copyletter s)

  fun redo () =
      (* XXX ditto... *)
      case UndoState.redo (undostate ()) of
          NONE => ()
        | SOME s => set_letter (L.copyletter s)

end