(* Copyright 2010 Tom Murphy VII and Erin Catto. See COPYING for details. *)

(* Contacts between bodies during simulation.

   A "contact" in this sense does not necessarily mean that the two
   bodies are touching, rather, it means that the simulator is tracking
   them because their bounding boxes overlap. Contacts persist to make
   incremental updates more efficient.

   In BoxDiaDia this signature is used twice: Once transparently for
   the internal BDDContact structure, which clients should ignore, and
   once abstractly for the final client interface.

   Corresponding to dynamics/contacts/b2contact.h. *)
signature BDDCONTACT =
sig

  (* Supplied by functor argument *)
  type fixture_data
  type body_data


  type body
  type fixture
  type joint
  type world
  type contact
  type filter

  (* Get the contact manifold, which should not be modified unless you
     understand the internals of BoxDiaDia. *)
  val get_manifold : contact -> BDDTypes.manifold

  (* Get the world manifold. *)
  val get_world_manifold : contact -> BDDTypes.world_manifold

  (* Is this contact touching? *)
  val is_touching : contact -> bool

  (* Enable or disable this contact. This can be used inside the
     pre-solve contact listener. The contact is only disabled for
     the current time step (or sub-step in continuous collisions). *)
  val set_enabled : contact * bool -> unit
  val get_enabled : contact -> bool

  (* Get the next contact in the world's contact list. *)
  val get_next : contact -> contact option

  (* Get the fixtures in this contact. *)
  val get_fixtures : contact -> fixture * fixture
  val get_fixture_a : contact -> fixture
  val get_fixture_b : contact -> fixture

  (* Evaluate this contact with your own manifold and transforms. *)
  val evaluate : BDDTypes.manifold * BDDMath.transform * BDDMath.transform -> void

end
