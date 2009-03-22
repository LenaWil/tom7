
(* Support for Laser Suspension Womb.
   This is proprietary one-off hardware, so you probably want to disable
   this.

   For cross-platform compatibility and driver avoidance, this uses the
   Mass Storage Device profile for USB. That means it appears as a drive
   on the computer with a single file called FILE.TXT. It appears to the
   host OS that the file can be written to. The Womb does not actually
   save the data (to avoid the Flash ram being worn out by repeated
   writes; it is rated to about 100,000), but it uses the data in the
   write to signal the device.

   This is a big hack. The operating system could choose to write to
   this alleged disk pretty much any way it wants, defragging it or
   creating metadata or whatever. But for the tiny FAT16 filesystem
   that the Womb presents, it has fairly predictable behavior. *)
structure Womb :> WOMB =
struct

    val fopen = _import "fopen" : string * string -> MLton.Pointer.t ;
    val fclose = _import "fclose" : MLton.Pointer.t -> unit ;
    val writeword = _import "ml_writeword" : MLton.Pointer.t * Word32.word -> unit ;
    val fseek = _import "ml_fseek" : MLton.Pointer.t * int -> unit ;
    val fflush = _import "fflush" : MLton.Pointer.t -> unit ;

    val womb = ref MLton.Pointer.null : MLton.Pointer.t ref

    fun detect () =
        let
            val p = fopen ("i:\\FILE.TXT", "wb")
        in
            womb := p;
            p <> MLton.Pointer.null
        end

    fun signal () =
        if !womb <> MLton.Pointer.null
        then
            let in
                fseek(!womb, 0);
                writeword(!womb, 0wxDEADBEEF);
                fflush(!womb)
            end
        else ()

end
