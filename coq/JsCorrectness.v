Set Implicit Arguments.
Require Import Shared.
Require Import LibFix LibList.
Require Import JsSyntax JsSyntaxAux JsPreliminary JsPreliminaryAux.
Require Import JsInterpreter JsPrettyInterm JsPrettyRules.


(**************************************************************)
(** ** Implicit Types -- copied from JsPreliminary *)

Implicit Type b : bool.
Implicit Type n : number.
Implicit Type k : int.
Implicit Type s : string.
Implicit Type i : literal.
Implicit Type l : object_loc.
Implicit Type w : prim.
Implicit Type v : value.
Implicit Type r : ref.
(*Implicit Type B : builtin.*)
Implicit Type T : type.

Implicit Type rt : restype.
Implicit Type rv : resvalue.
Implicit Type lab : label.
Implicit Type labs : label_set.
Implicit Type R : res.
Implicit Type o : out.
Implicit Type ct : codetype.

Implicit Type x : prop_name.
Implicit Type str : strictness_flag.
Implicit Type m : mutability.
Implicit Type Ad : attributes_data.
Implicit Type Aa : attributes_accessor.
Implicit Type A : attributes.
Implicit Type Desc : descriptor.
Implicit Type D : full_descriptor.

Implicit Type L : env_loc.
Implicit Type E : env_record.
Implicit Type Ed : decl_env_record.
Implicit Type X : lexical_env.
Implicit Type O : object.
Implicit Type S : state.
Implicit Type C : execution_ctx.
Implicit Type P : object_properties_type.

Implicit Type e : expr.
Implicit Type p : prog.
Implicit Type t : stat.


(**************************************************************)
(** Generic constructions *)

Lemma get_arg_correct : forall args vs,
  arguments_from args vs ->
  forall num,
    num < length vs ->
    get_arg num args = LibList.nth num vs.
Proof.
  introv A. induction~ A.
   introv I. false I. lets (I'&_): (rm I). inverts~ I'.
   introv I. destruct* num. simpl. rewrite <- IHA.
    unfolds. repeat rewrite~ get_nth_nil.
    rewrite length_cons in I. nat_math.
   introv I. destruct* num. simpl. rewrite <- IHA.
    unfolds. repeat rewrite~ get_nth_cons.
    rewrite length_cons in I. nat_math.
Qed.


(**************************************************************)
(** Monadic constructors *)

Inductive not_ter : result -> Prop :=
  | not_ter_div : not_ter out_div
  | not_ter_stuck : not_ter result_stuck
  | not_ter_bottom : not_ter result_bottom.

Lemma not_ter_forall : forall res,
  ~ not_ter res <-> exists S R, res = out_ter S R.
Proof.
  iff P.
   destruct res; try (false P; constructors).
    destruct o. false P; constructors. repeat eexists.
   lets (S&R&E): (rm P). intro A. substs. inverts A.
Qed.


Ltac inverts_not_ter NT I :=
  let NT' := fresh NT in
  inversion NT as [NT'|NT'|NT']; clear NT; (* [inverts NT as NT'] does not work. *)
  symmetry in NT';
  try rewrite NT' in * |-;
  try inverts I.

(* [need_ter I NT E res S R] generates two goals:
   * one where [not_ter res]
   * one where [res = out_ter S R] *)
Ltac need_ter I NT E res S R k :=
  let res0 := fresh "res" in
  let EQres0 := fresh I in
  sets_eq res0 EQres0: res;
  symmetry in EQres0;
  tests NT: (not_ter res0); [
      try solve [ inverts_not_ter NT I ]
    | rewrite not_ter_forall in NT;
      lets (S&R&E): (rm NT); rewrite E in I; clear E; simpl in I; k ].

(* Unfolds one monadic contructor in the environnement. *)
Ltac if_unmonad := (* This removes some information... *)
  let NT := fresh "NT" in
  let E := fresh "Eq" in
  let S := fresh "S" in
  let R := fresh "R" in
  match goal with

  | I: if_success_value ?runs ?C ?rev ?K = ?res |- ?g =>
    unfold if_success_value in I; if_unmonad

  | I: if_success ?rev ?K = ?res |- ?g =>
    unfold if_success in I; if_unmonad

  | I: if_success_state ?rv ?res ?K = ?res' |- ?g =>
    need_ter I NT E res S R ltac:(
      let C := fresh "C" in
      asserts C: ((res_type R = restype_normal -> g)
        /\ (res_type R = restype_break -> g)
        /\ ((res_type R = restype_continue
          \/ res_type R = restype_return
          \/ res_type R = restype_throw) ->
        result_normal (out_ter S (res_overwrite_value_if_empty rv R))
          = res' -> g)); [
          splits;
          let RT := fresh "RT" in
          introv RT; first [ rewrite RT in I | clear I; introv I ]
      | let C1 := fresh "C" in
        let C2 := fresh "C" in
        let C3 := fresh "C" in
        lets (C1&C2&C3): (rm C);
        destruct (res_type R); [ apply C1 | apply C2
          | apply C3 | apply C3 | apply C3 ];
          first [ reflexivity | inverts~ I; fail | idtac] ])

  | I: if_ter ?res ?K = ?res' |- ?g =>
    need_ter I NT E res S R ltac:idtac

  | I: result_normal (out_ter ?S1 ?R1)
      = result_normal (out_ter ?S0 ?R0) |- ?g =>
    inverts~ I

  | I: out_ter ?S1 ?R1 = out_ter ?S0 ?R0 |- ?g =>
    inverts~ I

  end.

Ltac unfold_everything_in_goal k kloop :=
  repeat (match goal with
  | |- context[if_ter ?res ?K] =>
    unfold if_ter
  | |- context[if_success_state ?rv ?res ?K] =>
    unfold if_success_state
  | |- context[if_success ?res ?K] =>
    unfold if_success
  | |- context[if_success_value ?runs ?C ?res ?K] =>
    unfold if_success_value
  | |- context[ref_get_value ?runs ?S ?C ?rv] =>
    unfold ref_get_value
  | |- context[prim_value_get ?runs ?S ?C ?v ?x] =>
    unfold prim_value_get
  | |- context[if_object ?o ?k] =>
    unfold if_object
  | |- context[if_value ?o ?k] =>
    unfold if_value
  | |- context[run_prog ?num ?S ?C ?p] =>
    let R := fresh "R" in
    sets_eq R: (run_prog num S C p);
    k R
  | |- context[run_stat ?num ?S ?C ?t] =>
    let R := fresh "R" in
    sets_eq R: (run_stat num S C t);
    k R
  | |- context[run_expr ?num ?S ?C ?e] =>
    let R := fresh "R" in
    sets_eq R: (run_expr num S C e);
    k R
  | |- context[run_elements ?num ?S ?C ?rv ?els] =>
    let R := fresh "R" in
    sets_eq R: (run_elements num S C rv els);
    k R
  | |- context[run_call_full ?num ?S ?C ?l ?v ?args] =>
    let R := fresh "R" in
    sets_eq R: (run_call_full num S C l v args);
    k R
  | |- context[ref_kind_of ?r] =>
    unfold ref_kind_of
  | |- context[ref_base ?r] =>
    let rb := fresh "rb" in
    sets_eq rb: (ref_base r);
    let v := fresh "v" in
    destruct rb as [v|?];
    [ let p := fresh "p" in
      destruct v as [p|?];
      [ destruct p|]
    |]
  | |- context[res_type ?r] =>
    let rt := fresh "rt" in
    sets_eq rt: (res_type r);
    destruct rt
  | |- context[res_value ?r] =>
    let rv := fresh "rv" in
    sets_eq rv: (res_value r);
    destruct rv
  end; kloop).


(**************************************************************)
(** Operations on objects *)

(* TODO
Lemma run_object_method_correct :
  forall Proj S l,
  (* TODO:  Add correctness properties. *)
    object_method Proj S l (run_object_method Proj S l).
Proof.
  introv. eexists. splits*.
  apply pick_spec.
  skip. (* Need properties about [l]. *)
Qed.
*)


(**************************************************************)
(** Correctness of interpreter *)

Definition follow_spec {T Te : Type}
    (conv : T -> Te) (red : state -> execution_ctx -> Te -> out -> Prop)
    (run : state -> execution_ctx -> T -> result) := forall S C (e : T) o,
  run S C e = o ->
  red S C (conv e) o.

Definition follow_expr := follow_spec expr_basic red_expr.
Definition follow_stat := follow_spec stat_basic red_stat.
Definition follow_prog := follow_spec prog_basic red_prog.
Definition follow_elements rv :=
  follow_spec (prog_1 rv) red_prog.
Definition follow_call vs :=
  follow_spec
    (fun B => spec_call_prealloc B vs)
    red_expr.
Definition follow_call_full l vs :=
  follow_spec
    (fun v => spec_call l v vs)
    red_expr.


(**************************************************************)
(** Operations on environments *)


(**************************************************************)
(** ** Main theorems *)

Theorem run_prog_not_div : forall num S C p,
  run_prog num S C p <> out_div
with run_stat_not_div : forall num S C t,
  run_stat num S C t <> out_div
with run_expr_not_div : forall num S C e,
  run_expr num S C e <> out_div
with run_elements_not_div : forall num S C rv els,
  run_elements num S C rv els <> out_div
with run_call_full_not_div : forall num S C l v args,
  run_call_full num S C l v args <> out_div.
Proof.

  (* run_prog_not_div *)
  destruct num. auto*.
  destruct p. simpls. auto*.

  (* run_stat_not_div *)
  destruct num. auto*.
  destruct t. simpls. auto*. unfold_everything_in_goal ltac:(fun R =>
    asserts: (R <> out_div); [subst*|
      let o := fresh "o" in
      destruct R as [o| |]; tryfalse;
      try destruct o; tryfalse]) ltac:(
    repeat case_if; try discriminate).

Qed.

Theorem run_prog_correct : forall num,
  follow_prog (run_prog num)
with run_stat_correct : forall num,
  follow_stat (run_stat num)
with run_expr_correct : forall num,
  follow_expr (run_expr num)
with run_elements_correct : forall num rv,
  follow_elements rv (fun S C => run_elements num S C rv)
with run_call_correct : forall num vs,
  follow_call vs (fun S C B => run_call num S C B vs)
with run_call_full_correct : forall num l vs,
  follow_call_full l vs (fun S C v => run_call_full num S C l v vs).
Proof.

  (* run_prog_correct *)
  destruct num. auto*.
  intros S0 C p o R. destruct p as [str es].
  forwards RC: run_elements_correct R.
  apply~ red_prog_prog.

  (* run_stat_correct *)
  destruct num. auto*.
  intros S0 C t o R. destruct t.

   (* stat_expr *)
   simpls. repeat if_unmonad.
    inverts_not_ter NT R. forwards: run_expr_correct R2.
     apply red_stat_abort. (* TODO:  This could be turned into a tactic. *)
      skip. (* Needs implementation of [out_of_ext_stat]. *)
      constructors.
      intro A. inverts A.
    inverts_not_ter NT R.
    forwards: run_expr_correct R2.
     apply red_stat_abort. (* TODO:  This could be turned into a tactic. *)
      skip. (* Needs implementation of [out_of_ext_stat]. *)
      constructors.
      intro A. inverts A.
    skip.
    skip.
    skip.

   (* stat_label *)
   skip.

   (* TODO: Complete *)
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.
   skip.

  (* run_expr_correct *)
  skip.

  (* run_elements_correct *)
  skip.

  (* run_call_correct *)
  skip.

  (* run_call_full_correct *)
  skip.

Admitted.

