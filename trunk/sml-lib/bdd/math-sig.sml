(* Copyright 2010 Tom Murphy VII and Erin Catto. See COPYING for details. *)

signature BDDMATH =
sig

  (* This function is used to ensure that a floating point number is
     not a NaN or infinity. *)
  val is_valid : real -> bool
  (* 1 / sqrt(x). Approximate. *)
  val inv_sqrt : real -> real

  val sqrt : real -> real
  val atan2 : real * real -> real
  val abs : real -> real

  (* 2D column vector. *)
  type vec2
  val vec2 : real * real -> vec2
  val vec2copy : vec2 -> vec2
  val vec2x : vec2 -> real
  val vec2y : vec2 -> real
  val vec2setzero : vec2 -> unit
  val vec2set : vec2 * real * real -> unit
  val vec2setfrom : vec2 * vec2 -> unit
  val vec2neg : vec2 -> vec2
  val vec2idx : vec2 -> int -> real
  val vec2pluseq : vec2 * vec2 -> unit
  val vec2minuseq : vec2 * vec2 -> unit
  val vec2timeseq : vec2 * real -> unit
  val vec2length : vec2 -> real
  val vec2length_squared : vec2 -> real
  (* Convert into a unit vector with the same direction.
     Returns the (old) length. *)
  val vec2normalize : vec2 -> real
  val vec2is_valid : vec2 -> bool

  type vec3
  val vec3 : real * real * real -> vec3
  val vec3copy : vec3 -> vec3
  val vec3x : vec3 -> real
  val vec3y : vec3 -> real
  val vec3z : vec3 -> real
  val vec3zero : vec3 -> unit
  val vec3set : vec3 * real * real * real -> unit
  val vec3neg : vec3 -> vec3
  val vec3idx : vec3 -> int -> real
  val vec3pluseq : vec3 * vec3 -> unit
  val vec3minuseq : vec3 * vec3 -> unit
  val vec3timeseq : vec3 * real -> unit

  (* 2x2 matrix; column-major order. *)
  type mat22
  val mat22cols : vec2 * vec2 -> mat22
  val mat22copy : mat22 -> mat22
  val mat22with : real * real * 
                  real * real -> mat22
  (* Construct this matrix using an angle (radians).
     This matrix becomes an orthonormal rotation matrix. *)
  val mat22angle : real -> mat22
  (* Set this matrix's columns. *)
  val mat22set : mat22 * vec2 * vec2 -> unit
  val mat22setangle : mat22 * real -> unit
  val mat22setidentity : mat22 -> unit
  val mat22setzero : mat22 -> unit
  val mat22getangle : mat22 -> real
  val mat22inverse : mat22 -> mat22
  (* Solve A * x = b, where b is a column vector. This is more efficient
     than computing the inverse in one-shot cases. *)
  val mat22solve : mat22 * vec2 -> vec2

  type mat33
  val mat33 : vec3 * vec3 * vec3 -> mat33
  val mat33setzero : mat33 -> unit
  val dot2 : vec2 * vec2 -> real
  val dot3 : vec3 * vec3 -> real
  val cross2vv : vec2 * vec2 -> real
  val cross2vs : vec2 * real -> vec2
  val cross2sv : real * vec2 -> vec2
  val cross3vv : vec3 * vec3 -> vec3

  (* Solve A * x = b, where b is a column vector. This is more efficient
     than computing the inverse in one-shot cases. *)
  val mat33solve33 : mat33 * vec3 -> vec3
  (* Solve A * x = b, where b is a column vector. This is more efficient
     than computing the inverse in one-shot cases. Solve only the upper
     2-by-2 matrix equation. *)
  val mat33solve22 : mat33 * vec2 -> vec2

  (* A transform contains translation and rotation. It is used to represent
     the position and orientation of rigid frames. *)
  type transform
  val transform : vec2 * mat22 -> transform
  val transformposition : transform -> vec2
  val transformr : transform -> mat22
  val transform_setidentity : transform -> unit
  val transform_set : transform * vec2 * real -> unit
  val transform_getangle : transform -> real

  (* Don't modify these. *)
  val vec2_zero : vec2
  val mat22_identity : mat22
  val transform_identity : transform

  (* Functional math on vectors, matrices, etc. *)
  val vec2sub : vec2 * vec2 -> vec2
  val vec3sub : vec3 * vec3 -> vec3
  val vec2add : vec2 * vec2 -> vec2
  val vec3add : vec3 * vec3 -> vec3
  val mat22add : mat22 * mat22 -> mat22
  val vec2stimes : real * vec2 -> vec2
  val vec3stimes : real * vec3 -> vec3
  val mul22v : mat22 * vec2 -> vec2
  val mul22m : mat22 * mat22 -> mat22
  val mul33v : mat33 * vec3 -> vec3
  val multransformv : transform * vec2 -> vec2
  val vec2eq : vec2 * vec2 -> bool
  val vec2abs : vec2 -> vec2
  val mat22abs : mat22 -> mat22
  val distance : vec2 * vec2 -> real
  val distance_squared : vec2 * vec2 -> real
  val vec2min : vec2 * vec2 -> vec2
  val vec2max : vec2 * vec2 -> vec2
  val clampr : real * real * real -> real
  val vec2clamp : vec2 * vec2 * vec2 -> vec2

  (* These multiply the transpose of the (first) matrix. *)
  val mul_t22mv : mat22 * vec2 -> vec2
  val mul_t22mm : mat22 * mat22 -> mat22
  val mul_ttransformv : transform * vec2 -> vec2

  (* In Box2D, this file defined templated min and max, but clients
     should just use {Int, Real}.{min, max}. *)

  val next_power_of_two : Word32.word -> Word32.word
  val is_power_of_two : Word32.word -> bool

  (* A sweep describes the motion of a body/shape for TOI computation.
     Shapes are defined with respect to the body origin, which may
     not coincide with the center of mass. However, to support dynamics
     we must interpolate the center of mass position. *)
  type sweep
  (* Get the interpolated transform at a specific time.
     alpha is a factor in [0,1], where 0 indicates t0. 
     Modifies the transform. *)
  val sweep_gettransform : sweep * transform * real -> unit
  (* Advance the sweep forward, yielding a new initial state.
     t is the new initial time. *)
  val sweep_advance : sweep * real -> unit
  (* Normalize the angles. *)
  val sweep_normalize : sweep -> unit

end