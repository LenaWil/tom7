structure Images =
struct

  exception NoSuchImage

  fun requireimage s =
      let val s = "graphics/" ^ s
      in
          case SDL.Image.load s of
              NONE => (print ("couldn't open " ^ s ^ "\n");
                       raise NoSuchImage)
            | SOME p => p
      end

  local
      open SDL.Util.Cursor
      nonfix + -
  in
      val pointercursor =
        make
        { w = 16, hot_x = 0, hot_y = 0,
          pixels =
          [X, -, -, -, -, -, -, -, -, -, -, -, -, -, -, -,

           X, X, -, -, -, -, -, -, -, -, -, -, -, -, -, -,

           X, O, X, -, -, -, -, -, -, -, -, -, -, -, -, -,

           X, O, O, X, -, -, -, -, -, -, -, -, -, -, -, -,

           X, O, O, O, X, -, -, -, -, -, -, -, -, -, -, -,

           X, O, O, O, O, X, -, -, -, -, -, -, -, -, -, -,

           X, O, O, O, O, O, X, -, -, -, -, -, -, -, -, -,

           X, O, O, O, O, O, O, X, -, -, -, -, -, -, -, -,

           X, O, O, O, O, O, O, O, X, -, -, -, -, -, -, -,

           X, O, O, O, O, O, O, O, O, X, -, -, -, -, -, -,

           X, O, O, O, O, O, X, X, X, X, X, -, -, -, -, -,

           X, O, O, X, O, O, X, -, -, -, -, -, -, -, -, -,

           X, O, X, -, X, O, O, X, -, -, -, -, -, -, -, -,

           X, X, -, -, X, O, O, X, -, -, -, -, -, -, -, -,

           X, -, -, -, -, X, O, O, X, -, -, -, -, -, -, -,

           -, -, -, -, -, X, O, O, X, -, -, -, -, -, -, -,

           -, -, -, -, -, -, X, O, O, X, -, -, -, -, -, -,

           -, -, -, -, -, -, X, O, O, X, -, -, -, -, -, -,

           -, -, -, -, -, -, -, X, X, -, -, -, -, -, -, -,

           -, -, -, -, -, -, -, -, -, -, -, -, -, -, -, -] }

      val selcursor =
        make
        { w = 16, hot_x = 0, hot_y = 0,
          pixels =
          [X, -, -, -, -, -, -, -, -, -, -, -, -, -, -, -,

           X, X, -, -, -, -, -, O, O, X, O, O, X, O, O, -,

           X, O, X, -, -, -, -, X, -, -, -, -, -, -, X, -,

           X, O, O, X, -, -, -, O, -, -, -, -, -, -, O, -,

           X, O, O, O, X, -, -, O, -, -, -, -, -, -, O, -,

           X, O, O, O, O, X, -, X, -, -, -, -, -, -, X, -,

           X, O, O, O, O, O, X, O, O, X, O, O, X, O, O, -,

           X, O, O, O, O, O, O, X, -, -, -, -, -, -, -, -,

           X, O, O, O, O, O, O, O, X, -, -, -, -, -, -, -,

           X, O, O, O, O, O, O, O, O, X, -, -, -, -, -, -,

           X, O, O, O, O, O, X, X, X, X, X, -, -, -, -, -,

           X, O, O, X, O, O, X, -, -, -, -, -, -, -, -, -,

           X, O, X, -, X, O, O, X, -, -, -, -, -, -, -, -,

           X, X, -, -, X, O, O, X, -, -, -, -, -, -, -, -,

           X, -, -, -, -, X, O, O, X, -, -, -, -, -, -, -,

           -, -, -, -, -, X, O, O, X, -, -, -, -, -, -, -,

           -, -, -, -, -, -, X, O, O, X, -, -, -, -, -, -,

           -, -, -, -, -, -, X, O, O, X, -, -, -, -, -, -,

           -, -, -, -, -, -, -, X, X, -, -, -, -, -, -, -,

           -, -, -, -, -, -, -, -, -, -, -, -, -, -, -, -] }


      val handcursor =
        make
        { w = 16, hot_x = 8, hot_y = 8,
          pixels =
          [-, -, -, -, X, X, -, X, X, -, X, X, -, -, -, -,

           -, -, -, X, O, O, X, O, O, X, O, O, X, X, X, -,

           -, -, -, X, O, O, X, O, O, X, O, O, X, O, O, X,

           -, -, -, X, O, O, X, O, O, X, O, O, X, O, O, X,

           -, -, -, X, O, O, X, O, O, X, O, O, X, O, O, X,

           -, X, X, X, O, O, X, O, O, X, O, O, X, O, O, X,

           X, O, O, X, O, O, X, O, O, X, O, O, X, O, O, X,

           X, O, O, X, O, O, O, O, O, O, O, O, O, O, O, X,

           X, O, O, O, O, O, O, O, O, O, O, O, O, O, O, X,

           X, O, O, O, O, O, O, O, O, O, O, O, O, O, O, X,

           X, O, O, O, O, O, O, O, O, O, O, O, O, O, O, X,

           -, X, O, O, O, O, O, O, O, O, O, O, O, O, O, X,

           -, -, X, X, O, O, O, O, O, O, O, O, O, O, X, -,

           -, -, -, -, X, O, O, O, O, O, O, O, O, X, -, -,

           -, -, -, -, X, O, O, O, O, O, O, O, O, X, -, -,

           -, -, -, -, -, X, X, X, X, X, X, X, X, -, -, -] }

  end
end
