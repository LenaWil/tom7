
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
   that the Womb presents, it has fairly predictable behavior. 

   Because of the pinout of the chip is not particularly regular, I
   didn't take any care to arrange the bits in any order. Here are the
   actual values.


             ,---,----,         +---------+
     hat    / a b  e f \        |       i |  board
   (front) /  c d  g h  \       |         |
          |              |      +---------+
           `---~~~~-----'
              brim

       bit(0-31)  color
   a    23        blue
   b    18        green
   c    28        blue
   d    17        green
   e    26        green
   f    22        blue
   g    25        green
   h    24        blue
   i    27        red
*)
structure RawWomb :> RAW_WOMB where type light = Word32.word =
struct

(* Straightforward stdio version. Doesn't seem to work on windows very well. *)

(*
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
*)

(* Use SML's IO. Still too much buffering. *)
(*
    val womb = SOME (let val f = BinIO.openOut "i:\\FILE.TXT"
                     in (f, BinIO.getPosOut f)
                     end) handle _ => NONE
            
    fun detect () = Option.isSome womb
    
    fun signal () =
        case womb of
            NONE => ()
          | SOME (f, begin) =>
                let in
                    BinIO.setPosOut(f, begin);
                    BinIO.output1 (f, 0wx2A);
                    BinIO.flushOut f
                end
*)

    val A = Word32.<<(0w1, 0w23)
    val B = Word32.<<(0w1, 0w18)
    val C = Word32.<<(0w1, 0w28)
    val D = Word32.<<(0w1, 0w17)
    val E = Word32.<<(0w1, 0w26)
    val F = Word32.<<(0w1, 0w22)
    val G = Word32.<<(0w1, 0w25)
    val H = Word32.<<(0w1, 0w24)
    val I = Word32.<<(0w1, 0w27)

(* C version tuned to each platform. *)
    exception Womb of string
    type light = Word32.word

    val openwomb_ = _import "ml_openwomb" : unit -> int ;
    val signal_ = _import "ml_signal" : Word32.word -> unit ;

    val found = ref false
    fun already_found () = !found
    fun detect () =
        if !found
        then raise Womb "already opened."
        else (found := openwomb_ () <> 0; !found)
    fun signal_raw w = signal_ w

    fun heartbeat () = ()

end

structure BufferedRawWomb :> RAW_WOMB where type light = Word32.word =
struct
    open RawWomb

    (* XXX should be configured or benchmarked. *)
    val MIN_WRITE =
        case SDL.platform of
            SDL.WIN32 => 0w2 (* takes something like 1.7ms on vista *)
          | SDL.OSX => 0w6 (* takes like 5.6 on OSX *)
          | _ => 0w1 (* ?? *)
        
    val cur = ref (0w0 : Word32.word)
    val want = ref (0w0 : Word32.word)
    val lasttime = ref (SDL.getticks())

    fun flush now =
        let in
            lasttime := now;
            cur := !want;
            RawWomb.signal_raw (!cur)
        end

    fun heartbeat_at now =
        if (!want <> !cur) andalso now - !lasttime >= MIN_WRITE
        then flush now
        else ()

    fun heartbeat () = heartbeat_at (SDL.getticks())

    fun signal_raw w =
        let 
            val now = SDL.getticks ()
        in
            want := w;
            heartbeat_at now
        end

end 

functor WombFn(W : RAW_WOMB where type light = Word32.word) :> WOMB =
struct
    open W

    (* assume it starts off *)
    val cur = ref (0w0 : Word32.word)

    fun signal_raw w = (cur := w; W.signal_raw w)

    fun signal ls = signal_raw (foldr Word32.orb 0w0 ls)

    fun liteon l = signal_raw (Word32.orb(!cur, l))
    fun liteoff l = signal_raw (Word32.andb(!cur, Word32.notb l))

end

structure Womb = WombFn(BufferedRawWomb)
