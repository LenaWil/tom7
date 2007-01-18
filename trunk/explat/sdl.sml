
structure SDL :> SDL =
struct

  (* a "safe" pointer can be set to null when
     it is imperatively freed, so that we can
     then later block operations on it *)
  type safe = MLton.Pointer.t ref
  type ptr = MLton.Pointer.t 

  type color = Word32.word

  exception SDL of string
  exception Invalid
  val null = MLton.Pointer.null
  fun check (ref p) = if p = null then raise Invalid else ()
  fun clear r = r := null

  fun !! (ref p) = if p = null then raise Invalid else p

  (* XXX endianness... *)
  fun color (r, g, b, a) = 
    Word32.orb
    (Word32.<< (Word32.fromInt (Word8.toInt a), 0w24),
     Word32.orb
     (Word32.<< (Word32.fromInt (Word8.toInt r), 0w16),
      Word32.orb
      (Word32.<< (Word32.fromInt (Word8.toInt g), 0w8),
       Word32.fromInt (Word8.toInt b))))

  type surface = safe


    datatype sdlk =
        SDLK_UNKNOWN            
      | SDLK_BACKSPACE          
      | SDLK_TAB                
      | SDLK_CLEAR              
      | SDLK_RETURN             
      | SDLK_PAUSE              
      | SDLK_ESCAPE             
      | SDLK_SPACE              
      | SDLK_EXCLAIM            
      | SDLK_QUOTEDBL           
      | SDLK_HASH               
      | SDLK_DOLLAR             
      | SDLK_AMPERSAND          
      | SDLK_QUOTE              
      | SDLK_LEFTPAREN          
      | SDLK_RIGHTPAREN         
      | SDLK_ASTERISK           
      | SDLK_PLUS               
      | SDLK_COMMA              
      | SDLK_MINUS              
      | SDLK_PERIOD             
      | SDLK_SLASH              
      | SDLK_0                  
      | SDLK_1                  
      | SDLK_2                  
      | SDLK_3                  
      | SDLK_4                  
      | SDLK_5                  
      | SDLK_6                  
      | SDLK_7                  
      | SDLK_8                  
      | SDLK_9                  
      | SDLK_COLON              
      | SDLK_SEMICOLON          
      | SDLK_LESS               
      | SDLK_EQUALS             
      | SDLK_GREATER            
      | SDLK_QUESTION           
      | SDLK_AT                 
      | SDLK_LEFTBRACKET        
      | SDLK_BACKSLASH          
      | SDLK_RIGHTBRACKET       
      | SDLK_CARET              
      | SDLK_UNDERSCORE         
      | SDLK_BACKQUOTE          
      | SDLK_a                  
      | SDLK_b                  
      | SDLK_c                  
      | SDLK_d                  
      | SDLK_e                  
      | SDLK_f                  
      | SDLK_g                  
      | SDLK_h                  
      | SDLK_i                  
      | SDLK_j                  
      | SDLK_k                  
      | SDLK_l                  
      | SDLK_m                  
      | SDLK_n                  
      | SDLK_o                  
      | SDLK_p                  
      | SDLK_q                  
      | SDLK_r                  
      | SDLK_s                  
      | SDLK_t                  
      | SDLK_u                  
      | SDLK_v                  
      | SDLK_w                  
      | SDLK_x                  
      | SDLK_y                  
      | SDLK_z                  
      | SDLK_DELETE             
      | SDLK_WORLD_0            
      | SDLK_WORLD_1            
      | SDLK_WORLD_2            
      | SDLK_WORLD_3            
      | SDLK_WORLD_4            
      | SDLK_WORLD_5            
      | SDLK_WORLD_6            
      | SDLK_WORLD_7            
      | SDLK_WORLD_8            
      | SDLK_WORLD_9            
      | SDLK_WORLD_10           
      | SDLK_WORLD_11           
      | SDLK_WORLD_12           
      | SDLK_WORLD_13           
      | SDLK_WORLD_14           
      | SDLK_WORLD_15           
      | SDLK_WORLD_16           
      | SDLK_WORLD_17           
      | SDLK_WORLD_18           
      | SDLK_WORLD_19           
      | SDLK_WORLD_20           
      | SDLK_WORLD_21           
      | SDLK_WORLD_22           
      | SDLK_WORLD_23           
      | SDLK_WORLD_24           
      | SDLK_WORLD_25           
      | SDLK_WORLD_26           
      | SDLK_WORLD_27           
      | SDLK_WORLD_28           
      | SDLK_WORLD_29           
      | SDLK_WORLD_30           
      | SDLK_WORLD_31           
      | SDLK_WORLD_32           
      | SDLK_WORLD_33           
      | SDLK_WORLD_34           
      | SDLK_WORLD_35           
      | SDLK_WORLD_36           
      | SDLK_WORLD_37           
      | SDLK_WORLD_38           
      | SDLK_WORLD_39           
      | SDLK_WORLD_40           
      | SDLK_WORLD_41           
      | SDLK_WORLD_42           
      | SDLK_WORLD_43           
      | SDLK_WORLD_44           
      | SDLK_WORLD_45           
      | SDLK_WORLD_46           
      | SDLK_WORLD_47           
      | SDLK_WORLD_48           
      | SDLK_WORLD_49           
      | SDLK_WORLD_50           
      | SDLK_WORLD_51           
      | SDLK_WORLD_52           
      | SDLK_WORLD_53           
      | SDLK_WORLD_54           
      | SDLK_WORLD_55           
      | SDLK_WORLD_56           
      | SDLK_WORLD_57           
      | SDLK_WORLD_58           
      | SDLK_WORLD_59           
      | SDLK_WORLD_60           
      | SDLK_WORLD_61           
      | SDLK_WORLD_62           
      | SDLK_WORLD_63           
      | SDLK_WORLD_64           
      | SDLK_WORLD_65           
      | SDLK_WORLD_66           
      | SDLK_WORLD_67           
      | SDLK_WORLD_68           
      | SDLK_WORLD_69           
      | SDLK_WORLD_70           
      | SDLK_WORLD_71           
      | SDLK_WORLD_72           
      | SDLK_WORLD_73           
      | SDLK_WORLD_74           
      | SDLK_WORLD_75           
      | SDLK_WORLD_76           
      | SDLK_WORLD_77           
      | SDLK_WORLD_78           
      | SDLK_WORLD_79           
      | SDLK_WORLD_80           
      | SDLK_WORLD_81           
      | SDLK_WORLD_82           
      | SDLK_WORLD_83           
      | SDLK_WORLD_84           
      | SDLK_WORLD_85           
      | SDLK_WORLD_86           
      | SDLK_WORLD_87           
      | SDLK_WORLD_88           
      | SDLK_WORLD_89           
      | SDLK_WORLD_90           
      | SDLK_WORLD_91           
      | SDLK_WORLD_92           
      | SDLK_WORLD_93           
      | SDLK_WORLD_94           
      | SDLK_WORLD_95           
      | SDLK_KP0                
      | SDLK_KP1                
      | SDLK_KP2                
      | SDLK_KP3                
      | SDLK_KP4                
      | SDLK_KP5                
      | SDLK_KP6                
      | SDLK_KP7                
      | SDLK_KP8                
      | SDLK_KP9                
      | SDLK_KP_PERIOD          
      | SDLK_KP_DIVIDE          
      | SDLK_KP_MULTIPLY        
      | SDLK_KP_MINUS           
      | SDLK_KP_PLUS            
      | SDLK_KP_ENTER           
      | SDLK_KP_EQUALS          
      | SDLK_UP                 
      | SDLK_DOWN               
      | SDLK_RIGHT              
      | SDLK_LEFT               
      | SDLK_INSERT             
      | SDLK_HOME               
      | SDLK_END                
      | SDLK_PAGEUP             
      | SDLK_PAGEDOWN           
      | SDLK_F1                 
      | SDLK_F2                 
      | SDLK_F3                 
      | SDLK_F4                 
      | SDLK_F5                 
      | SDLK_F6                 
      | SDLK_F7                 
      | SDLK_F8                 
      | SDLK_F9                 
      | SDLK_F10                
      | SDLK_F11                
      | SDLK_F12                
      | SDLK_F13                
      | SDLK_F14                
      | SDLK_F15                
      | SDLK_NUMLOCK            
      | SDLK_CAPSLOCK           
      | SDLK_SCROLLOCK          
      | SDLK_RSHIFT             
      | SDLK_LSHIFT             
      | SDLK_RCTRL              
      | SDLK_LCTRL              
      | SDLK_RALT               
      | SDLK_LALT               
      | SDLK_RMETA              
      | SDLK_LMETA              
      | SDLK_LSUPER             
      | SDLK_RSUPER             
      | SDLK_MODE               
      | SDLK_COMPOSE            
      | SDLK_HELP               
      | SDLK_PRINT              
      | SDLK_SYSREQ             
      | SDLK_BREAK              
      | SDLK_MENU               
      | SDLK_POWER              
      | SDLK_EURO               
      | SDLK_UNDO               


    datatype event =
      E_Active
    | E_KeyDown of { sym : sdlk }
    | E_KeyUp of { sym : sdlk }
    | E_MouseMotion
    | E_MouseDown
    | E_MouseUp
    | E_JoyAxis
    | E_JoyDown
    | E_JoyUp
    | E_JoyHat
    | E_JoyBall
    | E_Resize
    | E_Expose
    | E_SysWM
    | E_User
    | E_Quit
    | E_Unknown

  local
  val sdlk =
    Vector.fromList
    ([
     (* 0-7 *)
     SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN,
     SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN,

     SDLK_BACKSPACE,          (* = 8 *)
     SDLK_TAB,                (* = 9 *)

     SDLK_UNKNOWN, SDLK_UNKNOWN,

     SDLK_CLEAR,              (* = 12 *)
     SDLK_RETURN,             (* = 13 *)

     SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN,
     SDLK_UNKNOWN,

     SDLK_PAUSE,              (* = 19 *)

     SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN,
     SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN,

     SDLK_ESCAPE,             (* = 27 *)

     SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN, SDLK_UNKNOWN,

     SDLK_SPACE,              (* = 32 *)
     SDLK_EXCLAIM,            (* = 33 *)
     SDLK_QUOTEDBL,           (* = 34 *)
     SDLK_HASH,               (* = 35 *)
     SDLK_DOLLAR,             (* = 36 *)
     SDLK_AMPERSAND,          (* = 38 *)
     SDLK_QUOTE,              (* = 39 *)
     SDLK_LEFTPAREN,          (* = 40 *)
     SDLK_RIGHTPAREN,         (* = 41 *)
     SDLK_ASTERISK,           (* = 42 *)
     SDLK_PLUS,               (* = 43 *)
     SDLK_COMMA,              (* = 44 *)
     SDLK_MINUS,              (* = 45 *)
     SDLK_PERIOD,             (* = 46 *)
     SDLK_SLASH,              (* = 47 *)
     SDLK_0,                  (* = 48 *)
     SDLK_1,                  (* = 49 *)
     SDLK_2,                  (* = 50 *)
     SDLK_3,                  (* = 51 *)
     SDLK_4,                  (* = 52 *)
     SDLK_5,                  (* = 53 *)
     SDLK_6,                  (* = 54 *)
     SDLK_7,                  (* = 55 *)
     SDLK_8,                  (* = 56 *)
     SDLK_9,                  (* = 57 *)
     SDLK_COLON,              (* = 58 *)
     SDLK_SEMICOLON,          (* = 59 *)
     SDLK_LESS,               (* = 60 *)
     SDLK_EQUALS,             (* = 61 *)
     SDLK_GREATER,            (* = 62 *)
     SDLK_QUESTION,           (* = 63 *)
     SDLK_AT,                 (* = 64 *)

     (* (uppercase) *)
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,
     SDLK_UNKNOWN,

     SDLK_LEFTBRACKET,        (* = 91 *)
     SDLK_BACKSLASH,          (* = 92 *)
     SDLK_RIGHTBRACKET,       (* = 93 *)
     SDLK_CARET,              (* = 94 *)
     SDLK_UNDERSCORE,         (* = 95 *)
     SDLK_BACKQUOTE,          (* = 96 *)
     SDLK_a,                  (* = 97 *)
     SDLK_b,                  (* = 98 *)
     SDLK_c,                  (* = 99 *)
     SDLK_d,                  (* = 100 *)
     SDLK_e,                  (* = 101 *)
     SDLK_f,                  (* = 102 *)
     SDLK_g,                  (* = 103 *)
     SDLK_h,                  (* = 104 *)
     SDLK_i,                  (* = 105 *)
     SDLK_j,                  (* = 106 *)
     SDLK_k,                  (* = 107 *)
     SDLK_l,                  (* = 108 *)
     SDLK_m,                  (* = 109 *)
     SDLK_n,                  (* = 110 *)
     SDLK_o,                  (* = 111 *)
     SDLK_p,                  (* = 112 *)
     SDLK_q,                  (* = 113 *)
     SDLK_r,                  (* = 114 *)
     SDLK_s,                  (* = 115 *)
     SDLK_t,                  (* = 116 *)
     SDLK_u,                  (* = 117 *)
     SDLK_v,                  (* = 118 *)
     SDLK_w,                  (* = 119 *)
     SDLK_x,                  (* = 120 *)
     SDLK_y,                  (* = 121 *)
     SDLK_z,                  (* = 122 *)
     SDLK_DELETE              (* = 127 *)

     ] @ List.tabulate (160 - 127 - 1, fn _ => SDLK_UNKNOWN) @ [
     
     SDLK_WORLD_0,            (* = 160 *)
     SDLK_WORLD_1,            (* = 161 *)
     SDLK_WORLD_2,            (* = 162 *)
     SDLK_WORLD_3,            (* = 163 *)
     SDLK_WORLD_4,            (* = 164 *)
     SDLK_WORLD_5,            (* = 165 *)
     SDLK_WORLD_6,            (* = 166 *)
     SDLK_WORLD_7,            (* = 167 *)
     SDLK_WORLD_8,            (* = 168 *)
     SDLK_WORLD_9,            (* = 169 *)
     SDLK_WORLD_10,           (* = 170 *)
     SDLK_WORLD_11,           (* = 171 *)
     SDLK_WORLD_12,           (* = 172 *)
     SDLK_WORLD_13,           (* = 173 *)
     SDLK_WORLD_14,           (* = 174 *)
     SDLK_WORLD_15,           (* = 175 *)
     SDLK_WORLD_16,           (* = 176 *)
     SDLK_WORLD_17,           (* = 177 *)
     SDLK_WORLD_18,           (* = 178 *)
     SDLK_WORLD_19,           (* = 179 *)
     SDLK_WORLD_20,           (* = 180 *)
     SDLK_WORLD_21,           (* = 181 *)
     SDLK_WORLD_22,           (* = 182 *)
     SDLK_WORLD_23,           (* = 183 *)
     SDLK_WORLD_24,           (* = 184 *)
     SDLK_WORLD_25,           (* = 185 *)
     SDLK_WORLD_26,           (* = 186 *)
     SDLK_WORLD_27,           (* = 187 *)
     SDLK_WORLD_28,           (* = 188 *)
     SDLK_WORLD_29,           (* = 189 *)
     SDLK_WORLD_30,           (* = 190 *)
     SDLK_WORLD_31,           (* = 191 *)
     SDLK_WORLD_32,           (* = 192 *)
     SDLK_WORLD_33,           (* = 193 *)
     SDLK_WORLD_34,           (* = 194 *)
     SDLK_WORLD_35,           (* = 195 *)
     SDLK_WORLD_36,           (* = 196 *)
     SDLK_WORLD_37,           (* = 197 *)
     SDLK_WORLD_38,           (* = 198 *)
     SDLK_WORLD_39,           (* = 199 *)
     SDLK_WORLD_40,           (* = 200 *)
     SDLK_WORLD_41,           (* = 201 *)
     SDLK_WORLD_42,           (* = 202 *)
     SDLK_WORLD_43,           (* = 203 *)
     SDLK_WORLD_44,           (* = 204 *)
     SDLK_WORLD_45,           (* = 205 *)
     SDLK_WORLD_46,           (* = 206 *)
     SDLK_WORLD_47,           (* = 207 *)
     SDLK_WORLD_48,           (* = 208 *)
     SDLK_WORLD_49,           (* = 209 *)
     SDLK_WORLD_50,           (* = 210 *)
     SDLK_WORLD_51,           (* = 211 *)
     SDLK_WORLD_52,           (* = 212 *)
     SDLK_WORLD_53,           (* = 213 *)
     SDLK_WORLD_54,           (* = 214 *)
     SDLK_WORLD_55,           (* = 215 *)
     SDLK_WORLD_56,           (* = 216 *)
     SDLK_WORLD_57,           (* = 217 *)
     SDLK_WORLD_58,           (* = 218 *)
     SDLK_WORLD_59,           (* = 219 *)
     SDLK_WORLD_60,           (* = 220 *)
     SDLK_WORLD_61,           (* = 221 *)
     SDLK_WORLD_62,           (* = 222 *)
     SDLK_WORLD_63,           (* = 223 *)
     SDLK_WORLD_64,           (* = 224 *)
     SDLK_WORLD_65,           (* = 225 *)
     SDLK_WORLD_66,           (* = 226 *)
     SDLK_WORLD_67,           (* = 227 *)
     SDLK_WORLD_68,           (* = 228 *)
     SDLK_WORLD_69,           (* = 229 *)
     SDLK_WORLD_70,           (* = 230 *)
     SDLK_WORLD_71,           (* = 231 *)
     SDLK_WORLD_72,           (* = 232 *)
     SDLK_WORLD_73,           (* = 233 *)
     SDLK_WORLD_74,           (* = 234 *)
     SDLK_WORLD_75,           (* = 235 *)
     SDLK_WORLD_76,           (* = 236 *)
     SDLK_WORLD_77,           (* = 237 *)
     SDLK_WORLD_78,           (* = 238 *)
     SDLK_WORLD_79,           (* = 239 *)
     SDLK_WORLD_80,           (* = 240 *)
     SDLK_WORLD_81,           (* = 241 *)
     SDLK_WORLD_82,           (* = 242 *)
     SDLK_WORLD_83,           (* = 243 *)
     SDLK_WORLD_84,           (* = 244 *)
     SDLK_WORLD_85,           (* = 245 *)
     SDLK_WORLD_86,           (* = 246 *)
     SDLK_WORLD_87,           (* = 247 *)
     SDLK_WORLD_88,           (* = 248 *)
     SDLK_WORLD_89,           (* = 249 *)
     SDLK_WORLD_90,           (* = 250 *)
     SDLK_WORLD_91,           (* = 251 *)
     SDLK_WORLD_92,           (* = 252 *)
     SDLK_WORLD_93,           (* = 253 *)
     SDLK_WORLD_94,           (* = 254 *)
     SDLK_WORLD_95,           (* = 255 *)
     SDLK_KP0,                (* = 256 *)
     SDLK_KP1,                (* = 257 *)
     SDLK_KP2,                (* = 258 *)
     SDLK_KP3,                (* = 259 *)
     SDLK_KP4,                (* = 260 *)
     SDLK_KP5,                (* = 261 *)
     SDLK_KP6,                (* = 262 *)
     SDLK_KP7,                (* = 263 *)
     SDLK_KP8,                (* = 264 *)
     SDLK_KP9,                (* = 265 *)
     SDLK_KP_PERIOD,          (* = 266 *)
     SDLK_KP_DIVIDE,          (* = 267 *)
     SDLK_KP_MULTIPLY,        (* = 268 *)
     SDLK_KP_MINUS,           (* = 269 *)
     SDLK_KP_PLUS,            (* = 270 *)
     SDLK_KP_ENTER,           (* = 271 *)
     SDLK_KP_EQUALS,          (* = 272 *)
     SDLK_UP,                 (* = 273 *)
     SDLK_DOWN,               (* = 274 *)
     SDLK_RIGHT,              (* = 275 *)
     SDLK_LEFT,               (* = 276 *)
     SDLK_INSERT,             (* = 277 *)
     SDLK_HOME,               (* = 278 *)
     SDLK_END,                (* = 279 *)
     SDLK_PAGEUP,             (* = 280 *)
     SDLK_PAGEDOWN,           (* = 281 *)
     SDLK_F1,                 (* = 282 *)
     SDLK_F2,                 (* = 283 *)
     SDLK_F3,                 (* = 284 *)
     SDLK_F4,                 (* = 285 *)
     SDLK_F5,                 (* = 286 *)
     SDLK_F6,                 (* = 287 *)
     SDLK_F7,                 (* = 288 *)
     SDLK_F8,                 (* = 289 *)
     SDLK_F9,                 (* = 290 *)
     SDLK_F10,                (* = 291 *)
     SDLK_F11,                (* = 292 *)
     SDLK_F12,                (* = 293 *)
     SDLK_F13,                (* = 294 *)
     SDLK_F14,                (* = 295 *)
     SDLK_F15,                (* = 296 *)
     SDLK_NUMLOCK,            (* = 300 *)
     SDLK_CAPSLOCK,           (* = 301 *)
     SDLK_SCROLLOCK,          (* = 302 *)
     SDLK_RSHIFT,             (* = 303 *)
     SDLK_LSHIFT,             (* = 304 *)
     SDLK_RCTRL,              (* = 305 *)
     SDLK_LCTRL,              (* = 306 *)
     SDLK_RALT,               (* = 307 *)
     SDLK_LALT,               (* = 308 *)
     SDLK_RMETA,              (* = 309 *)
     SDLK_LMETA,              (* = 310 *)
     SDLK_LSUPER,             (* = 311 *)
     SDLK_RSUPER,             (* = 312 *)
     SDLK_MODE,               (* = 313 *)
     SDLK_COMPOSE,            (* = 314 *)
     SDLK_HELP,               (* = 315 *)
     SDLK_PRINT,              (* = 316 *)
     SDLK_SYSREQ,             (* = 317 *)
     SDLK_BREAK,              (* = 318 *)
     SDLK_MENU,               (* = 319 *)
     SDLK_POWER,              (* = 320 *)
     SDLK_EURO,               (* = 321 *)
     SDLK_UNDO                (* = 322 *)
        ])
  in
    (* XXX should also provide the inverse of this function *)
    fun sdlkey n =
      if n < 0 orelse n > Vector.length sdlk
      then SDLK_UNKNOWN
      else Vector.sub(sdlk, n)
  end

  val surface_width_ = _import "ml_surfacewidth" : ptr -> int ;
  val surface_height_ = _import "ml_surfaceheight" : ptr -> int ;
  val clearsurface_ = _import "ml_clearsurface" : ptr * Word32.word -> unit ;
  val newevent_ = _import "ml_newevent" : unit -> ptr ;
  val free_ = _import "free" : ptr -> unit ;
  val eventtag_ = _import "ml_eventtag" : ptr -> int ;
  val event_keyboard_sym_ = _import "ml_event_keyboard_sym" : ptr -> int ;

  fun clearsurface (s, w) = clearsurface_ (!! s, w)

  fun surface_width s = surface_width_ (!!s)
  fun surface_height s = surface_height_ (!!s)

  fun convertevent_ e =
   (* XXX need to get props too... *)
    (case eventtag_ e of
       1 => E_Active
         (* XXX more... *)
     | 2 => E_KeyDown { sym = sdlkey (event_keyboard_sym_ e) }
     | 3 => E_KeyUp { sym = sdlkey (event_keyboard_sym_ e) }
     | 4 => E_MouseMotion
     | 5 => E_MouseDown
     | 6 => E_MouseUp
     | 7 => E_JoyAxis
     | 8 => E_JoyBall
     | 9 => E_JoyHat
     | 10 => E_JoyDown
     | 11 => E_JoyUp
     | 12 => E_Quit
     | 13 => E_SysWM
     (* reserved..
     | 14 => 
     | 15 =>
        *)
     | 16 => E_Resize
     | 17 => E_Expose
     | _ => E_Unknown
       )

  fun pollevent () =
    let
      val p = _import "SDL_PollEvent" : ptr -> int ;
      val e = newevent_ ()
    in
      case p e of
        0 => 
          let in
          (* no event *)
            free_ e;
            NONE
          end
      | _ =>
          let 
            val ret = convertevent_ e
          in
            free_ e;
            SOME ret
          end
    end

  local val fl = _import "SDL_Flip" : ptr -> unit ;
  in
    fun flip p = fl (!!p)
  end

  local 
    val mkscreen = _import "ml_makescreen" : int * int -> ptr ;
  in
    fun makescreen (w, h) =
      let
        val p = mkscreen (w, h)
      in
        if p = null
        then raise SDL "couldn't make screen"
        else ref p
      end
  end

  local val ba = _import "ml_blitall" : ptr * ptr * int * int -> unit ;
  in
    fun blitall (s1, s2, x, y) = ba (!!s1, !!s2, x, y)
  end


  (* **** initialization **** *)
  local val init = _import "ml_init" : unit -> int ;
  in
    val () = 
      case init () of
        0 => raise SDL "could not initialize"
      | _ => ()
  end
  

  structure Image =
  struct
      fun load s =
      let 
          val lp = _import "IMG_Load" : string -> ptr ;
          val p = lp (s ^ "\000")
      in
          if (MLton.Pointer.null = p)
          then NONE
          else SOME (ref p)
      end
  end


end

