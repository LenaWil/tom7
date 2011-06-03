structure Images = struct

  exception NoSuchImage

  fun requireimage s =
      let val s = "graphics/" ^ s
      in
          case SDL.Image.load s of
              NONE => (print ("couldn't open " ^ s ^ "\n");
                       raise NoSuchImage)
            | SOME p => p
      end

end
