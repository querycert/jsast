Set Implicit Arguments.
Require Import Shared.
Require Import LibFix LibList.
Require Import JsSyntax JsSyntaxAux JsPreliminary JsPreliminaryAux.
Require Import JsInterpreter JsPrettyInterm JsPrettyRules.

(* TODO:  Move to Shared. *)

Lemma decide_def : forall {P:Prop} `{Decidable P},
  (decide P) = (If P then true else false).
Proof. intros. rewrite decide_spec. rewrite isTrue_def. case_if*. Qed.

Lemma decide_cases : forall (P:Prop) `{Decidable P},
  (P /\ decide P = true) \/ (~ P /\ decide P = false).
Proof. intros. rewrite decide_spec. rewrite isTrue_def. case_if*. Qed.




Ltac tryfalse_nothing :=
  try match goal with x: nothing |- _ => destruct x end;
  tryfalse.

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
Implicit Type ty : type.

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
Implicit Type W : result.

Implicit Type e : expr.
Implicit Type p : prog.
Implicit Type t : stat.

Implicit Type T : Type.


(**************************************************************)
(** Correctness Properties *)

Definition follow_spec {T Te : Type} (* e.g. T = expr and Te = ext_expr *)
    (conv : T -> Te)
    (red : state -> execution_ctx -> Te -> out -> Prop)
    (run : state -> execution_ctx -> T -> result) := forall S C (e : T) o,
  run S C e = o -> red S C (conv e) o.

Definition spec_follow_spec {Te A : Type} (* e.g. Te = ext_spec *)
    (conv : Te)
    (red : state -> execution_ctx -> Te -> specret A -> Prop)
    (run : state -> execution_ctx -> specres A) := forall S C sp,
  run S C = result_some sp -> red S C conv sp.

Definition follow_expr := follow_spec expr_basic red_expr.
Definition follow_stat := follow_spec stat_basic red_stat.
Definition follow_prog := follow_spec prog_basic red_prog.
Definition follow_elements rv :=
  follow_spec (prog_1 rv) red_prog.
Definition follow_call (run : state -> execution_ctx -> object_loc -> value -> list value -> result) :=
  forall l vs,
    follow_spec (fun v => spec_call l v vs) red_expr (fun S C v => run S C l v vs).
Definition follow_function_has_instance (run : state -> object_loc -> value -> result) :=
  (* Note that this function is related to [spec_function_has_instance_2] instead of
    [spec_function_has_instance_1] as it's much more closer to the specification and
    thus much easier to prove. *)
  forall lv,
    follow_spec (spec_function_has_instance_2 lv) red_expr
      (fun S C lo => run S lo lv).
Definition follow_stat_while (run : state -> execution_ctx -> resvalue -> label_set -> expr -> stat -> result) :=
  forall ls e t,
  follow_spec
    (stat_while_1 ls e t)
    red_stat (fun S C rv => run S C rv ls e t).
Definition follow_stat_do_while (run : state -> execution_ctx -> resvalue -> label_set -> expr -> stat -> result) :=
  forall ls e t,
  follow_spec
    (stat_do_while_1 ls t e)
    red_stat (fun S C rv => run S C rv ls e t).
Definition follow_object_get_own_prop (run : state -> execution_ctx -> object_loc -> prop_name -> specres full_descriptor) :=
  forall l x, spec_follow_spec (spec_object_get_own_prop l x) red_spec
    (fun S C => run S C l x).
Definition follow_object_get_prop (run : state -> execution_ctx -> object_loc -> prop_name -> specres full_descriptor) :=
(*  forall l x, spec_follow_spec (spec_object_get_prop l x) red_spec
    (fun S C => run S C l x). *)
  forall S C l x y,
  run S C l x = result_some y ->
  red_spec S C (spec_object_get_prop l x) y.
Definition follow_object_proto_is_prototype_of (run : state -> object_loc -> object_loc -> result) :=
  forall lthis,
    follow_spec (spec_call_object_proto_is_prototype_of_2_3 lthis) red_expr
      (fun S C l => run S lthis l).
Definition follow_equal (_ : state -> (state -> value -> result) -> (state -> value -> result) -> value -> value -> result) :=
  True. (* TODO *)

Record runs_type_correct runs :=
  make_runs_type_correct {
    runs_type_correct_expr : follow_expr (runs_type_expr runs);
    runs_type_correct_stat : follow_stat (runs_type_stat runs);
    runs_type_correct_prog : follow_prog (runs_type_prog runs);
    runs_type_correct_call : follow_call (runs_type_call runs);
    runs_type_correct_function_has_instance :
      follow_function_has_instance (runs_type_function_has_instance runs);
    runs_type_correct_stat_while : follow_stat_while (runs_type_stat_while runs);
    runs_type_correct_stat_do_while : follow_stat_do_while (runs_type_stat_do_while runs);
    runs_type_correct_object_get_own_prop :
      follow_object_get_own_prop (runs_type_object_get_own_prop runs);
    runs_type_correct_object_get_prop :
      follow_object_get_prop (runs_type_object_get_prop runs);
    runs_type_correct_object_proto_is_prototype_of :
      follow_object_proto_is_prototype_of (runs_type_object_proto_is_prototype_of runs);
    runs_type_correct_equal :
      follow_equal (runs_type_equal runs)
  }.


(**************************************************************)
(** Useful Tactics *)

Ltac absurd_neg :=
  let H := fresh in
  introv H; inverts H; tryfalse.

Hint Constructors abort.


(**************************************************************)
(** General Lemmas *)

Lemma arguments_from_spec_1 : forall args,
  exists v, arguments_from args (v::nil) 
         /\ get_arg 0 args = v.
Proof.
  Hint Constructors arguments_from.
  intros. destruct args as [|v vs]. 
  exists undef. splits*.
  exists v. splits*.
Qed.


Lemma res_overwrite_value_if_empty_empty : forall R,
  res_overwrite_value_if_empty resvalue_empty R = R.
Proof. introv. unfolds. cases_if~. destruct R; simpls; inverts~ e. Qed.

Lemma res_type_res_overwrite_value_if_empty : forall rv R,
  res_type R = res_type (res_overwrite_value_if_empty rv R).
Proof.
  introv. destruct R. unfold res_overwrite_value_if_empty. simpl.
  cases_if; reflexivity.
Qed.

Lemma res_label_res_overwrite_value_if_empty : forall rv R,
  res_label R = res_label (res_overwrite_value_if_empty rv R).
Proof.
  introv. destruct R. unfold res_overwrite_value_if_empty. simpl.
  cases_if; reflexivity.
Qed.

Lemma res_overwrite_value_if_empty_resvalue : forall rv1 rv2, exists rv3,
  res_normal rv3 = res_overwrite_value_if_empty rv1 rv2 /\ (rv3 = rv1 \/ rv3 = rv2).
Proof. introv. unfolds res_overwrite_value_if_empty. cases_if*. Qed.

Lemma or_idempotent : forall A : Prop, A \/ A -> A.
(* This probably already exists, but I didn't found it. *)
Proof. introv [?|?]; auto. Qed.


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

Lemma and_impl_left : forall P1 P2 P3 : Prop,
  (P1 -> P2) ->
  P1 /\ P3 ->
  P2 /\ P3.
Proof. auto*. Qed.

Ltac applys_and_base L :=
  applys~ and_impl_left; [applys~ L|]; try reflexivity.

Tactic Notation "applys_and" constr(E) :=
  applys_and_base (>> E).

Tactic Notation "applys_and" constr(E) constr(A1) :=
  applys_and_base (>> E A1).

Tactic Notation "applys_and" constr(E) constr(A1) constr(A2) :=
  applys_and_base (>> E A1 A2).

Tactic Notation "applys_and" constr(E) constr(A1) constr(A2) constr(A3) :=
  applys_and_base (>> E A1 A2 A3).

Ltac constructors_and :=
  let H := fresh in
  eapply and_impl_left; [ intro H; constructors; exact H |].


Lemma run_callable_correct : forall S v co,
  run_callable S v = Some co ->
  callable S v co.
Proof.
  introv E. destruct v; simpls~.
   inverts~ E.
   sets_eq <- B: (pick_option (object_binds S o)). destruct B; simpls; tryfalse.
    exists o0. splits~. forwards~: @pick_option_correct EQB. inverts~ E.
Qed.


(**************************************************************)
(** Monadic Constructors, Lemmas *)

(* Shared defs *)

(** [eqabort o1 o] assert that [o1] and [o] are equal
    and satisfy the [abort] predicate. *)

Definition eqabort o1 o :=
  o = o1 /\ abort o.

(** [isout W Pred] asserts that [W] is in fact
    an outcome that satisfies [Pred]. *)

Definition isout W (Pred:out->Prop) :=
  exists o1, W = res_out o1 /\ Pred o1.

Hint Unfold isout.

(* Generic *)

Lemma if_empty_label_out : forall T K S R (o : T),
  if_empty_label S R K = result_some o ->
  res_label R = label_empty /\ K tt = result_some o.
Proof. introv H. unfolds in H. cases_if; tryfalse. eexists; auto*. Qed.

Lemma if_some_out : forall (A B : Type) (oa : option A) K (b : B),
  if_some oa K = result_some b ->
  exists (a:A), oa = Some a /\ K a = result_some b.
Proof. introv E. destruct* oa; tryfalse. Qed.

Lemma if_result_some_out : forall (A B : Type) (W : resultof A) K (b : B),
  if_result_some W K = result_some b ->
  exists (y : A), W = result_some y /\ K y = result_some b.
Proof. introv H. destruct* W; tryfalse. Qed.

Lemma if_some_or_default_out : forall (A B : Type) (oa : option A) d K (b : B),
  if_some_or_default oa d K = b ->
     (oa = None /\ d = b)
  \/ (exists a, oa = Some a /\ K a = b).
Proof. introv E. destruct* oa; tryfalse. Qed.


(* Results *)

Definition if_ter_post (K : _ -> _ -> result) o o1 :=
     (o1 = out_div /\ o = o1)
  \/ (exists S R, o1 = out_ter S R /\ K S R = o).

Lemma if_ter_out : forall W K o,
  if_ter W K = o ->
  isout W (if_ter_post K o).
Proof.
  introv H. destruct W as [[|o1]| | | ]; simpls; tryfalse_nothing.
  exists o1. splits~. unfolds. destruct o1 as [|S R].
   inverts* H.
   jauto.
Qed.

Definition if_success_state_post rv0 (K : _ -> _ -> result) o o1 :=
  (o1 = out_div /\ o = o1) \/
  (exists S R, o1 = out_ter S R /\ res_type R = restype_throw /\ o = out_ter S (res_value R)) \/
  (exists S R, o1 = out_ter S R /\ res_type R <> restype_throw /\
    o = out_ter S (res_overwrite_value_if_empty rv0 R)) \/
  exists S rv, o1 = out_ter S (res_normal rv) /\
    K S (res_value (res_overwrite_value_if_empty rv0 rv)) = res_out o.

Lemma if_success_state_out : forall rv W K o,
  if_success_state rv W K = o ->
  isout W (if_success_state_post rv K o).
Proof.
  introv E. forwards~ (o1&WE&P): if_ter_out (rm E). subst W. eexists. splits*.
  inversion_clear P as [?|(S&R&?&H)]. branch~ 1.
  substs. destruct R as [rt rv' rl]. destruct~ rt; simpls;
    try solve [branch 3; repeat eexists; [discriminate | inverts~ H]].
   forwards~ (?&?): if_empty_label_out (rm H). simpls. substs.
    branch 4. repeat eexists. auto*.
   inverts H. branch 2. repeat eexists.
Qed.

Definition if_success_post (K : _ -> _ -> result) o o1 :=
  eqabort o1 o \/
  exists S rv, o1 = out_ter S (res_normal rv) /\ K S rv = o.

Lemma if_success_out : forall W K o,
  if_success W K = o ->
  isout W (if_success_post K o).
Admitted.

  (* Documentation: same with unfolding:
    Lemma if_success_out : forall W K o,
      if_success W K = o ->
      exists o1, W = res_out o1 /\
       (   (o = o1 /\ abort o)
        \/ (exists S rv, o1 = out_ter S rv /\ K S rv = o)).
  *)

Definition if_void_post (K : _ -> result) o o1 :=
  eqabort o1 o \/
  exists S, o1 = out_void S /\ K S = o.

Lemma if_void_out : forall W K o,
  if_void W K = o ->
  isout W (if_void_post K o).
Admitted.

(* TODO: misssing 
    if_not_throw *)

Definition if_any_or_throw_post (K1 K2 : _ -> _ -> result) o o1 :=
  (o1 = out_div /\ o = o1) \/
  (exists S R, o1 = out_ter S R /\ 
    (   (res_type R <> restype_throw /\ K1 S R = o)  
     \/ (res_type R = restype_throw /\ exists (v : value), res_value R = v
           /\ res_label R = label_empty /\ K2 S v = o))). (* Didn't worked when writing [exists (v : value), R = res_throw v]. *)

Lemma if_any_or_throw_out : forall W K1 K2 o,
  if_any_or_throw W K1 K2 = res_out o ->
  isout W (if_any_or_throw_post K1 K2 o).
Admitted.

Definition if_success_or_return_post (K1 : state -> result) (K2 : state -> resvalue -> result) o o1 :=
     (o1 = out_div /\ o = o1)
  \/ exists S R, o1 = out_ter S R /\
     (   (res_type R = restype_normal /\ res_label R = label_empty /\ K1 S = o)
      \/ (res_type R = restype_return /\ res_label R = label_empty /\ K2 S (res_value R) = o)
      \/ (res_type R <> restype_normal /\ res_type R <> restype_return /\ o1 = o)).

Lemma if_success_or_return_out : forall W (K1 : state -> result) (K2 : state -> resvalue -> result) o,
  if_success_or_return W K1 K2 = o ->
  isout W (if_success_or_return_post K1 K2 o).
Admitted.

(* TODO: misssing 
    if_normal_continue_or_break *)

Definition if_break_post (K : _ -> _ -> result) o o1 :=
     (o1 = out_div /\ o = o1)
  \/ (exists S R, o1 = out_ter S R /\ 
      (   (res_type R <> restype_break /\ o1 = o)
       \/ (res_type R = restype_break /\ K S R = o))).

Lemma if_break_out : forall W K o,
  if_break W K = o ->
  isout W (if_break_post K o).
Admitted.

Definition if_value_post (K : _ -> _ -> result) o o1 :=
  eqabort o1 o \/
  exists S v, o1 = out_ter S (res_val v) /\ K S v = o.

Lemma if_value_out : forall W K o,
  if_value W K = o ->
  isout W (if_value_post K o).
Admitted.

Definition if_bool_post (K : _ -> _ -> result) o o1 :=
  eqabort o1 o \/
  exists S z, o1 = out_ter S (res_val (prim_bool z)) /\ K S z = o.

Lemma if_bool_out : forall W K o,
  if_bool W K = o ->
  isout W (if_bool_post K o).
Admitted.

Definition if_object_post (K : _ -> _ -> result) o o1 :=
  eqabort o1 o \/
  exists S l, o1 = out_ter S (res_val (value_object l)) /\ K S l = o.

Lemma if_object_out : forall W K o,
  if_object W K = o ->
  isout W (if_object_post K o).
Admitted.

Definition if_string_post (K : _ -> _ -> result) o o1 :=
  eqabort o1 o \/
  exists S s, o1 = out_ter S (res_val (prim_string s)) /\ K S s = o.

Lemma if_string_out : forall W K o,
  if_string W K = o ->
  isout W (if_string_post K o).
Admitted.

Definition if_number_post (K : _ -> _ -> result) o o1 :=
  eqabort o1 o \/
  exists S n, o1 = out_ter S (res_val (prim_number n)) /\ K S n = o.

Lemma if_number_out : forall W K o,
  if_number W K = o ->
  isout W (if_number_post K o).
Admitted.

Definition if_primitive_post (K : _ -> _ -> result) o o1 :=
  eqabort o1 o \/
  exists S w, o1 = out_ter S (res_val (value_prim w)) /\ K S w = o.

Lemma if_primitive_out : forall W K o,
  if_primitive W K = o ->
  isout W (if_primitive_post K o).
Admitted.

Lemma if_abort_out : forall T o K (t : T),
  if_abort o K = result_some t ->
  abort o /\ K tt = result_some t.
Proof. introv H. destruct* o. simpls. cases_if*. Qed.

Definition if_spec_post (A B:Type) K (b:specret B) y :=
     (exists o, y = specret_out o /\ b = specret_out o /\ abort o) 
  \/ (exists (S:state) (a:A), y = specret_val S a /\ K S a = result_some b).

Lemma if_spec_out : forall (A B : Type) (W : specres A) K (b : specret B),
  if_spec W K = result_some b ->
  exists y, W = result_some y /\ if_spec_post K b y.
Proof. skip.
(*
  introv H. destruct W as [sp| | |]; tryfalse.
  destruct sp; [right* | left]. simpls. eexists. splits~.
  forwards*: if_abort_out H.
*)
Qed.

(* TOOD:  missing 
    if_ter_spec*)

Definition if_spec_ter_post T (K : _ -> _ -> result) o (y:specret T) :=
     (y = specret_out o /\ abort o)
  \/ (exists S a, y = specret_val S a /\ K S a = o).

Lemma if_spec_ter_out : forall T (W : specres T) K o,
  if_spec_ter W K = o -> 
  exists y, W = result_some y /\ if_spec_ter_post K o y.
Proof.
(* TODO
  introv H. destruct W as [sp| | |]; tryfalse.
  destruct (result_some sp)
  destruct sp; [right* | left]. simpls. eexists. splits~.
  forwards*: if_abort_out H.
*)
skip.
Qed.

Definition if_success_spec_post T K (y:specret T) o :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (rv : resvalue), o = out_ter S rv /\ K S rv = result_some y).

Lemma if_success_spec_out : forall T W K (y : specret T),
  if_success_spec W K = result_some y ->
  exists (o : out), W = o /\ if_success_spec_post K y o.
Admitted.

Definition if_value_spec_post T K (y:specret T) o :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (v : value), o = out_ter S v /\ K S v = result_some y).

Lemma if_value_spec_out : forall T W K (y : specret T),
  if_value_spec W K = result_some y ->
  exists (o : out), W = o /\ if_value_spec_post K y o.
Admitted.

Definition if_prim_spec_post T K (y:specret T) o :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (w : prim), o = out_ter S w /\ K S w = result_some y).

Lemma if_prim_spec_out : forall T W K (y : specret T),
  if_prim_spec W K = result_some y ->
  exists (o : out), W = o /\ if_prim_spec_post K y o.
Admitted.

Definition if_bool_spec_post T K (y:specret T) o :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (b : bool), o = out_ter S b /\ K S b = result_some y).

Lemma if_bool_spec_out : forall T W K (y : specret T),
  if_bool_spec W K = result_some y ->
  exists (o : out), W = o /\ if_bool_spec_post K y o.
Admitted.

Definition if_number_spec_post T K (y:specret T) o :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (n : number), o = out_ter S n /\ K S n = result_some y).

Lemma if_number_spec_out : forall T W K (y : specret T),
  if_number_spec W K = result_some y ->
  exists (o : out), W = o /\ if_number_spec_post K y o.
Admitted.

Definition if_string_spec_post T K (y:specret T) o :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (s : string), o = out_ter S s /\ K S s = result_some y).

Lemma if_string_spec_out : forall T W K (y : specret T),
  if_string_spec W K = result_some y ->
  exists (o : out), W = o /\ if_string_spec_post K y o.
Admitted.


(* proofs of old monadic lemmas, might be useful
Lemma if_success_out : forall res K S R,
  if_success res K = out_ter S R ->
  if_regular_lemma res S R (fun S' R' => exists rv,
    R' = res_normal rv /\
    K S' rv = out_ter S R).
Proof.
  introv H. deal_with_ter H; substs.
  sets_eq t Et: (res_type R0). repeat eexists.
  rewrite~ res_overwrite_value_if_empty_empty in HE.
  destruct t; try solve [ left; inverts HE; rewrite <- Et; splits~; discriminate ].
  forwards~ (E1&E2): if_empty_label_out (rm HE).
  right. destruct R0. simpls. substs. repeat eexists. auto*.
Qed.

Lemma if_value_out : forall res K S R,
  if_value res K = out_ter S R ->
  if_regular_lemma res S R (fun S' R' => exists v,
    R' = res_val v /\
    K S' v = out_ter S R).
Proof.
  introv H. deal_with_regular_lemma H if_success_out; substs.
   repeat eexists. left~.
   destruct~ rv; tryfalse. repeat eexists. right. eexists. auto*.
Qed.

Lemma if_object_out : forall res K S R,
  if_object res K = out_ter S R ->
  if_regular_lemma res S R (fun S' R' => exists l,
    R' = res_val (value_object l) /\
    K S' l = out_ter S R).
Proof.
  introv H. deal_with_regular_lemma H if_value_out; substs.
   repeat eexists. left~.
   destruct~ v; tryfalse. repeat eexists. right. eexists. auto*.
Qed.

Lemma if_string_out : forall res K S R,
  if_string res K = out_ter S R ->
  if_regular_lemma res S R (fun S' R' => exists s,
    R' = res_val (prim_string s) /\
    K S' s = out_ter S R).
Proof.
  introv H. deal_with_regular_lemma H if_value_out; substs.
   repeat eexists. left~.
   destruct~ v; tryfalse. destruct~ p; tryfalse. repeat eexists. right. eexists. auto*.
Qed.

Lemma if_success_primitive_out : forall res K S R,
  if_success_primitive res K = out_ter S R ->
  if_regular_lemma res S R (fun S' R' => exists p,
    R' = res_val (p : prim) /\
    K S' p = out_ter S R).
Proof.
  introv H. deal_with_regular_lemma H if_value_out; substs.
   repeat eexists. left~.
   destruct~ v; tryfalse. repeat eexists. right. eexists. auto*.
Qed.

Lemma if_not_throw_out : forall res K S R,
  if_not_throw res K = out_ter S R ->
  exists S0 R0, res = out_ter S0 R0 /\
    ((res_type R0 = restype_throw /\ S = S0 /\ R = R0) \/
     (res_type R0 <> restype_throw /\ K S0 R0 = out_ter S R)).
Proof.
  introv H. deal_with_ter H. substs. destruct R0 as [rt rv rl]; simpls.
  tests: (rt = restype_throw).
   repeat eexists. left. inverts~ HE.
   destruct rt; tryfalse; repeat eexists; right; inverts~ HE.
Qed.
*)

(* Passing *)

(*
Inductive passing_terminates {A : Type} : passing A -> Prop :=
  | passing_terminates_normal : forall S a,
    passing_terminates (passing_normal S a)
  | passing_terminates_abort : forall S R,
    abort (out_ter S R) ->
    passing_terminates (passing_abort (out_ter S R)).

Lemma passing_def_out : forall (A B : Type) bo (K : B -> passing A) (p : passing A),
  passing_def bo K = p ->
  (exists b, bo = Some b /\ K b = p) \/
  (exists res, bo = None /\ p = passing_abort res /\ forall o, result_out o <> res).
Proof. introv E. destruct* bo. right. eexists. splits*. discriminate. Qed.

Lemma passing_defined_out : forall (A B : Type) (p : passing B) K (pr : passing A),
  passing_defined p K = pr ->
  (exists S0 b, p = passing_normal S0 b /\ K S0 b = pr) \/
  (exists res, p = passing_abort res /\ pr = passing_abort res).
Proof. introv E. destruct* p. Qed.

Lemma passing_success_out : forall (A : Type) res K (p : passing A),
  passing_success res K = p ->
  (exists S0 rv, res = out_ter S0 (rv : resvalue) /\
                 K S0 rv = p) \/
  (exists res' S0 rv ls, p = passing_abort res' /\ (forall o, result_out o <> res') /\
                      res = out_ter S0 (res_intro restype_normal rv ls) /\
                      ls <> label_empty) \/
  (exists o, res = result_out o /\ p = passing_abort res /\ abort o) \/
  (p = passing_abort res /\ forall o, res <> o).
Proof.
  introv E. destruct~ res; try solve [branch 4; splits~; discriminate].
  destruct~ o.
   branch 3. eexists. splits~.
  destruct r as [T R L]. destruct~ T; try solve [ branch 3;
    eexists; splits~; constructors; absurd_neg ]. simpls.
  cases_if.
   branch 1. substs. repeat eexists.
   branch 2. substs. repeat eexists; auto*. discriminate.
Qed.

Lemma passing_value_out : forall (A : Type) res K (p : passing A),
  passing_value res K = p ->
  (exists S0 v, res = out_ter S0 (v : value) /\
                 K S0 v = p) \/
  (exists res' S0 rv ls, p = passing_abort res' /\ (forall o, result_out o <> res') /\
                      res = out_ter S0 (res_intro restype_normal rv ls) /\
                      (ls <> label_empty \/ forall v, rv <> v)) \/
  (exists o, res = result_out o /\ p = passing_abort res /\ abort o) \/
  (p = passing_abort res /\ forall o, res <> o).
Proof.
  introv E. destruct~ res; try solve [branch 4; splits~; discriminate].
  destruct~ o.
   branch 3. eexists. splits~.
  destruct r as [T R L]. destruct~ T; try solve [ branch 3;
    eexists; splits~; constructors; absurd_neg ]. simpls.
  cases_if; destruct R; subst; try (
    branch 2; repeat eexists;
    [ discriminate | solve [left*] || solve [try right; discriminate] ]).
  branch 1. repeat eexists.
Qed.
*)


(************************************************************)
(* ** Correctness tactics *)

(** [prove_not_intercept] proves a goal of
    the form "~ abort_intercepted_* _" *)

Ltac prove_not_intercept :=
let H := fresh in intros H; try solve [ inversion H; false~ ].

Hint Extern 1 (~ abort_intercepted_expr _) => prove_not_intercept.
Hint Extern 1 (~ abort_intercepted_stat _) => prove_not_intercept.
Hint Extern 1 (~ abort_intercepted_prog _) => prove_not_intercept.

Ltac prove_abort :=
  solve [ assumption | (constructor; absurd_neg) ].

Ltac abort_tactic L :=
  try subst; apply L;
  [ simpl; congruence
  | try prove_abort
  | try prove_not_intercept ].

Tactic Notation "abort_expr" :=
    abort_tactic red_expr_abort.
Tactic Notation "abort_stat" :=
    abort_tactic red_stat_abort.
Tactic Notation "abort_prog" :=
    abort_tactic red_prog_abort.
Tactic Notation "abort_spec" :=
    abort_tactic red_spec_abort.
Tactic Notation "abort" :=
  match goal with
  | |- red_expr _ _ _ _ => abort_expr
  | |- red_stat _ _ _ _ => abort_stat
  | |- red_prog _ _ _ _ => abort_prog
  | |- red_spec _ _ _ _ => abort_spec
  end.

(** [run_select_ifres] selects the appropriate "out" lemma *)

Ltac run_select_extra T := fail.

Ltac run_select_ifres H :=
  match type of H with ?T = _ => match T with
  | if_ter _ _ => constr:(if_ter_out)
  | if_success _ _ => constr:(if_success_out)
  | if_value _ _ => constr:(if_value_out)
  | if_void _ _ => constr:(if_void_out)
  | if_break _ _ => constr:(if_break_out)
  | if_object _ _ => constr:(if_object_out)
  | if_bool _ _ => constr:(if_bool_out)
  | if_string _ _ => constr:(if_string_out)
  | if_number _ _ => constr:(if_number_out)
  | if_primitive _ _ => constr:(if_primitive_out)
  | if_spec _ _ => constr:(if_spec_out)
  | if_spec_ter _ _ => constr:(if_spec_ter_out)
  | if_success_spec _ _ => constr:(if_success_spec_out)
  | if_value_spec _ _ => constr:(if_value_spec_out)
  | if_prim_spec _ _ => constr:(if_prim_spec_out)
  | if_bool_spec _ _ => constr:(if_bool_spec_out)
  | if_number_spec _ _ => constr:(if_number_spec_out)
  | if_string_spec _ _ => constr:(if_string_spec_out)
  | if_any_or_throw _ _ _ => constr:(if_any_or_throw_out) 
  | if_success_or_return _ _ _ => constr:(if_success_or_return_out) 
  | ?x => run_select_extra T
  end end.

(* template:
Ltac run_select_extra T ::=
  match T with
  | if_any_or_throw _ _ _ => constr:(if_any_or_throw_out) 
  end.
*)


(** [run_select_proj] is used to obtain automatically
    the right correctness lemma out of the correctness record *)
 
Ltac run_select_proj_extra_error HT := fail.
Ltac run_select_proj_extra_ref HT := fail.
Ltac run_select_proj_extra_conversions HT := fail.
Ltac run_select_proj_extra_construct HT := fail.
Ltac run_select_proj_extra_get_value HT := fail.

Ltac run_select_proj H :=
  match type of H with ?T = _ => let HT := get_head T in
  match HT with
  | runs_type_expr => constr:(runs_type_correct_expr)
  | runs_type_stat => constr:(runs_type_correct_stat)
  | runs_type_prog => constr:(runs_type_correct_prog)
  | runs_type_call => constr:(runs_type_correct_call) 
  | runs_type_function_has_instance => constr:(runs_type_correct_function_has_instance) 
  | runs_type_stat_while => constr:(runs_type_correct_stat_while) 
  | runs_type_object_get_own_prop => constr:(runs_type_correct_object_get_own_prop)
  | runs_type_object_get_prop => constr:(runs_type_correct_object_get_prop)
  | runs_type_object_proto_is_prototype_of => constr:(runs_type_correct_object_proto_is_prototype_of) 
  | runs_type_equal => constr:(runs_type_correct_equal) 
  | ?x => run_select_proj_extra_error HT
  | ?x => run_select_proj_extra_ref HT
  | ?x => run_select_proj_extra_conversions HT
  | ?x => run_select_proj_extra_construct HT
  | ?x => run_select_proj_extra_get_value HT
  end end.

(** [prove_runs_type_correct] discharges the trivial goal
    that consists in invoking the induction hypothesis*)

Ltac prove_runs_type_correct :=
  match goal with |- runs_type_correct _ => assumption end.

(* [run_hyp H] exploits the induction hypothesis
   on [runs_type_correct] to the hypothesis [H] *)

Ltac run_hyp_core H R :=
  let H' := fresh in rename H into H';
  let Proj := run_select_proj H' in
  lets R: Proj (rm H');
  try prove_runs_type_correct.

(** [select_ind_hyp] returns the induction hypothesis
    on [runs_type_correct] *)

Ltac select_ind_hyp tt :=
  match goal with IH: runs_type_correct _ |- _ => constr:(IH) end.

(* old run_hyp H:
Ltac run_hyp_core H R :=
  let H' := fresh in rename H into H';
  let IH := select_ind_hyp tt in
  let Proj := run_select_proj H' in
  lets R: Proj IH (rm H').
*)

Tactic Notation "run_hyp" hyp(H) "as" simple_intropattern(R) :=
  run_hyp_core H R.

Tactic Notation "run_hyp" hyp(H) :=
  let T := fresh in rename H into T;
  run_hyp T as H.

Tactic Notation "run_hyp" :=
  match goal with H: _ = result_some _ |- _ => run_hyp H end.

Tactic Notation "run_hyp" "*" hyp(H) :=
  run_hyp H; auto*.

Tactic Notation "run_hyp" "*" :=
  run_hyp; auto*.


(* [run_pre] exploits the appropriate "out" lemma, whether it comes
   from the correctness record or it is an auxiliary lemma. *)

Ltac run_pre_ifres H o1 R1 K :=
   let L := run_select_ifres H in
   lets (o1&R1&K): L (rm H). (* deconstruction of the "isout" *)

Ltac run_pre_core H o1 R1 K :=
   run_pre_ifres H o1 R1 K;
   let O1 := fresh "O1" in
   try (rename R1 into O1; run_hyp O1 as R1).

Tactic Notation "run_pre" hyp(H) "as" ident(o1) ident(R1) ident(K) :=
  let T := fresh in rename H into T;
  run_pre_core T o1 R1 K.

Tactic Notation "run_pre_ifres" "as" ident(o1) ident(R1) :=
  unfold result_some_out in *; unfold res_to_res_void in * ; unfold result_out in *; unfold res_out in *; (* I added this for it does not work, but any better solution is welcomed! -- Martin *)
  match goal with H: _ = result_some _ |- _ =>
    let T := fresh in rename H into T;
    run_pre_ifres T o1 R1 H end.

Tactic Notation "run_pre" "as" ident(o1) ident(R1) :=
  unfold result_some_out in *; unfold res_to_res_void in * ; unfold result_out in *; unfold res_out in *; (* I added this for it does not work, but any better solution is welcomed! -- Martin *)
  match goal with H: _ = result_some _ |- _ =>
    let T := fresh in rename H into T;
    run_pre_core T o1 R1 H end.

Tactic Notation "run_pre" "as" ident(o1) :=
  let R1 := fresh "R1" o1 in
  run_pre as o1 R1.

Tactic Notation "run_pre" :=
  let o1 := fresh "o1" in let R1 := fresh "R1" in
  run_pre as o1 R1.

(** [run_apply Red o1 R1] applys a reduction rule on a given
    [o1] or reduction reaching [o1]. *)

Tactic Notation "run_apply" constr(Red) constr(o1orR1) :=
  applys Red o1orR1.

Tactic Notation "run_apply" constr(Red) constr(o1) constr(R1) :=
  first [ applys Red (rm R1)
        | applys Red o1 ].

(** [run_post] decomposes the conclusion of the "out"
    lemma *)

Ltac run_post_run_expr_get_value := fail.

Ltac run_post_extra := fail.

Ltac run_post_core :=
  let Er := fresh "Er" in
  let Ab := fresh "Ab" in
  let S := fresh "S" in
  let O1 := fresh "O1" in
  let go H X :=
    destruct H as [(Er&Ab)|(S&X&O1&H)];
    [ try abort | try subst_hyp O1 ] in
  match goal with
  | H: if_ter_post _ _ _ |- _ =>
    let R := fresh "R" in go H R
  | H: if_success_post _ _ _ |- _ =>
    let rv := fresh "rv" in go H rv
  | H: if_value_post _ _ _ |- _ =>
    let v := fresh "v" in go H v
  | H: if_void_post _ _ _ |- _ =>
    destruct H as [(Er&Ab)|(S&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_break_post _ _ _ |- _ =>
    let R := fresh "R" in let E := fresh "E" in
    let HT := fresh "HT" in
    destruct H as [(Er&E)|(S&R&O1&[(HT&E)|(HT&H)])];
    [ try abort | try subst_hyp O1 | try subst_hyp O1 ]
  | H: if_object_post _ _ _ |- _ =>
    let l := fresh "l" in go H l
  | H: if_bool_post _ _ _ |- _ =>
    let b := fresh "b" in go H b
  | H: if_string_post _ _ _ |- _ =>
    let s := fresh "s" in go H s
  | H: if_number_post _ _ _ |- _ =>
    let m := fresh "m" in go H m
  | H: if_primitive_post _ _ _ |- _ =>
    let m := fresh "m" in go H m
  | H: if_spec_post _ _ _ |- _ =>
    let o := fresh "o" in let Er' := fresh "Er" in 
    let S := fresh "S" in let a := fresh "a" in
    destruct H as [(o&Er&Er'&Ab)|(S&a&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_spec_ter_post _ _ _ |- _ =>
    let S := fresh "S" in let a := fresh "a" in
    destruct H as [(Er&Ab)|(S&a&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_success_spec_post _ _ _ |- _ =>
    let S := fresh "S" in let rv := fresh "rv" in
    destruct H as [(Er&Ab)|(S&rv&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_value_spec_post _ _ _ |- _ =>
    let S := fresh "S" in let v := fresh "v" in
    destruct H as [(Er&Ab)|(S&v&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_prim_spec_post _ _ _ |- _ =>
    let S := fresh "S" in let w := fresh "w" in
    destruct H as [(Er&Ab)|(S&w&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_bool_spec_post _ _ _ |- _ =>
    let S := fresh "S" in let b := fresh "b" in
    destruct H as [(Er&Ab)|(S&b&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_number_spec_post _ _ _ |- _ =>
    let S := fresh "S" in let n := fresh "n" in
    destruct H as [(Er&Ab)|(S&n&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_string_spec_post _ _ _ |- _ =>
    let S := fresh "S" in let s := fresh "s" in
    destruct H as [(Er&Ab)|(S&s&O1&H)];
    [ try abort | try subst_hyp O1 ]
  | H: if_any_or_throw_post _ _ _ _ |- _ =>
    let R := fresh "R" in
    let N := fresh "N" in let v := fresh "v" in
    let E := fresh "E" in let L := fresh "L" in
    destruct H as [(Er&Ab)|(S&R&O1&[(N&H)|(N&v&E&L&H)])];
    [ try subst_hyp Er; try subst_hyp Ab | try subst_hyp O1 | try subst_hyp O1 ]
  | H: if_success_or_return_post _ _ _ _ |- _ => 
     let S := fresh "S" in let R := fresh "R" in
     let o1 := fresh "o1" in let W1 := fresh "W1" in let O1 := fresh "O1" in 
     let E1 := fresh "E" in let E2 := fresh "E" in 
     destruct H as [(Er&Ab)|(S&R&O1&[(E1&E2&K)|[(E1&E2&K)|(E1&E2&K)]])];
    [ try subst_hyp Er; try subst_hyp Ab; try abort
    | try subst_hyp O1 | try subst_hyp O1 | try subst_hyp O1 ]
  | |- _ => run_post_run_expr_get_value
  | |- _ => run_post_extra
  end.
 

(* template
Ltac run_post_extra ::=
  let Er := fresh "Er" in let Ab := fresh "Ab" in
  let O1 := fresh "O1" in let S := fresh "S" in
  match goal with
  | H: if_any_or_throw_post _ _ _ _ |- _ => ...
  end.

*)


Tactic Notation "run_post" :=
  run_post_core.

(** [run_inv] simplifies equalities in goals
    by performing inversions on equalities. *)

Ltac run_inv :=
  unfold result_some_out in *; unfold res_to_res_void in * ; unfold out_retn in *; unfold result_out in *;
  repeat
  match goal with
  | H: resvalue_value ?v = resvalue_value ?v |- _ => clear H
  | H: resvalue_value _ = resvalue_value _ |- _ => inverts H
  | H: res_spec _ _ = _ |- _ => unfold res_spec in H
  | H: _ = res_spec _ _ |- _ => unfold res_spec in H
  | H: res_out _ = _ |- _ => unfold res_out in H
  | H: _ = res_out _ |- _ => unfold res_out in H
  | H: res_ter _ _ = _ |- _ => unfold res_ter in H
  | H: _ = res_ter _ _ |- _ => unfold res_ter in H
  | H: result_some ?o = result_some ?o |- _ => clear H
  | H: result_some _ = result_some _ |- _ => inverts H
  | H: out_ter ?S ?R = out_ter ?S ?R |- _ => clear H
  | H: out_ter _ _ = out_ter _ _ |- _ => inverts H
  | H: res_intro ?t ?v ?l = res_intro ?t ?v ?l |- _ => clear H
  | H: res_intro _ _ _ = res_intro _ _ _ |- _ => inverts H
  | H: ret _ _ = _ |- _ => unfold ret in H
  | H: _ = ret _ _ |- _ => unfold ret in H
  | H: ret_void _ = _ |- _ => unfold ret_void in H
  | H: _ = ret_void _ |- _ => unfold ret_void in H
  | H: res_void _ = _ |- _ => unfold res_void in H
  | H: _ = res_void _ |- _ => unfold res_void in H
  | H: specret_val ?S ?R = specret_val ?S ?R |- _ => clear H
  | H: specret_val _ _ = specret_val _ _ |- _ => inverts H
  | H: specret_out ?o = specret_out ?o |- _ => clear H
  | H: specret_out _ = _ |- _ => inverts H
  | H: _ = specret_out _ |- _ => inverts H
  | H: out_from_retn ?sp = out_from_retn ?sp |- _ => clear H
  | H: out_from_retn _ = out_from_retn _ |- _ => inverts H
  end.

(** [runs_inv] is the same as [run_inv] followed by subst. *)

Ltac runs_inv :=
  run_inv; subst.

(** Auxiliary tactics to select/check the current "out" *)

Ltac run_get_current_out tt :=
  match goal with
  | |- red_expr _ _ _ ?o => o
  | |- red_stat _ _ _ ?o => o
  | |- red_prog _ _ _ ?o => o
  | |- red_spec _ _ _ ?o => o
  (* TODO:  Complete *)
  end.

Ltac run_check_current_out o :=
  match goal with
  | |- red_expr _ _ _ o => idtac
  | |- red_stat _ _ _ o => idtac
  | |- red_prog _ _ _ o => idtac
  | |- red_spec _ _ _ o => idtac
  (* TODO:  Complete *)
  end.

(** [run_step Red] combines [run_pre], [run_apply Red] and calls
    [run_post] on the main reduction subgoal, followed
    with a cleanup using [run_inv] *)

Ltac run_step Red :=
  let o1 := fresh "o1" in let R1 := fresh "R1" in
  run_pre as o1 R1;
  match Red with ltac_wild => idtac | _ =>
    let o := run_get_current_out tt in
    run_apply Red o1 R1;
    try (run_check_current_out o; run_post; run_inv)
  end.

(** [run_step_using Red Lem] combines [run_pre], 
    a forward to exploit the correctness lemma [Lem], 
    [run_apply Red] and calls
    [run_post] on the main reduction subgoal, followed
    with a cleanup using [run_inv] *)

Ltac run_step_using Red Lem :=
  let o1 := fresh "o1" in let O1 := fresh "O1" in
  let R1 := fresh "R1" in
  run_pre_ifres as o1 O1;
  lets R1: Lem (rm O1);
  try prove_runs_type_correct;
  match Red with ltac_wild => idtac | _ =>
    let o := run_get_current_out tt in
    run_apply Red o1 R1;
    try (run_check_current_out o; run_post; run_inv)
  end.

(** [run_simpl] is intended for simplyfing simple monads
    that do not match over a result, then run
    [run_inv] to clean up the goal. *)

Ltac run_simpl_run_error H T K := fail.

Ltac run_simpl_base H K :=
  let E := fresh "E" in
  match type of H with ?T = _ => match T with
  | if_some _ _ =>
     let x := fresh "x" in
     lets (x&E&K): if_some_out (rm H)
  | if_some_or_default _ _ _ =>
     let x := fresh "x" in
     let E1 := fresh "E" in let E2 := fresh "E" in
     lets [(E1&E2)|(n&E&K)]: if_some_or_default_out (rm H)
  | if_empty_label _ _ _ =>
     lets (E&K): if_empty_label_out (rm H)
  | ?x => run_simpl_run_error H T K
  | ?x => run_hyp_core H K 
  end end.


Ltac run_simpl_core H K :=
  run_simpl_base H K; run_inv.

Tactic Notation "run_simpl" ident(H) "as" ident(K) :=
  let T := fresh in rename H into T;
  run_simpl_core T K.

Tactic Notation "run_simpl" :=
  unfold result_some_out in *; unfold res_to_res_void in * ; unfold result_out in *; unfold res_out in *; (* I added this for it does not work, but any better solution is welcomed! -- Martin *)
  match goal with H: _ = result_some _ |- _ =>
    let H' := fresh in rename H into H';
    run_simpl_core H' H
  end.

(** [run Red] is the same as [run_step Red].
    [run] without arguments is the same as [run_simpl].
    [runs] is same as [run] followed with [subst]. *)

Tactic Notation "run" constr(Red) :=
  run_step Red.

Tactic Notation "run" "*" constr(Red) :=
  run Red; auto*.

Tactic Notation "run" constr(Red) "using" constr(Lem) :=
  run_step_using Red Lem.

Tactic Notation "run" "*" constr(Red) "using" constr(Lem) :=
  run Red using Lem; auto*.


Tactic Notation "runs" constr(Red) :=
  run Red; subst.

Tactic Notation "runs" "*" constr(Red) :=
  run Red; subst; auto*.

Tactic Notation "run" :=
  run_simpl.

Tactic Notation "run" "*" :=
  run; auto*.

Tactic Notation "runs" :=
  run; subst.

Tactic Notation "runs" "*" :=
  runs; auto*.


(* debugging of [run Red]:
  run_pre as o1 R1.
    or: run_pre H as o1 R1 K. (* where H is the hypothesis *)
    or: run_pre_core H o1 R1 K. (* where H is the hypothesis *)
    or: run_pre_lemma H o1 R1 K. (* where H is the hypothesis *)
  run_apply __my_red_lemma__ R1. (* where R1 is the red hypothesis *)
  run_post.
  run_inv.
*)


(************************************************************)
(* ** Correctness Lemmas *)

Lemma run_object_method_correct : forall Z (Proj : _ -> Z) S l (z : Z),
  run_object_method Proj S l = Some z ->
  object_method Proj S l z.
Proof.
  introv B. unfolds. forwards (O&Bi&E): option_map_some_back B.
  forwards: @pick_option_correct Bi. exists* O.
Qed.

Lemma run_object_heap_set_extensible_correct : forall b S l S',
  run_object_heap_set_extensible b S l = Some S' ->
  object_heap_set_extensible b S l S'.
Admitted.

Lemma build_error_correct : forall S C vproto vmsg o,
  build_error S vproto vmsg = o ->
  red_expr S C (spec_build_error vproto vmsg) o.
Proof.
  introv R. unfolds in R.
  match goal with H: context [object_alloc ?s ?o] |- _ => sets_eq X: (object_alloc s o) end.
  destruct X as (l&S'). cases_if.
  applys~ red_spec_build_error EQX. run_inv.
   applys~ red_spec_build_error_1_no_msg.
Qed.

Lemma run_error_correct' : forall S ne o C,
  run_error S ne = o ->
  red_expr S C (spec_error ne) o /\ abort o.
Proof.
  introv R. unfolds in R. run_pre as o1 R1. forwards R0: build_error_correct (rm R1).
  applys_and red_spec_error R0. run_post. splits~. abort. run_inv. splits; [|prove_abort].
  apply~ red_spec_error_1.
Qed.

Lemma run_error_correct : forall S ne o C,
  run_error S ne = o ->
  red_expr S C (spec_error ne) o.
Proof.
  intros. applys* run_error_correct'.
Qed.

Ltac run_simpl_run_error H T K ::=
  match T with run_error _ _ =>
     let N := fresh "N" in
     let C := match goal with |- _ _ ?C _ _ => constr:(C) end in
     lets (K&N): run_error_correct C (rm H)
  end.

Lemma out_error_or_void_correct : forall S C str (ne : native_error) o,
  out_error_or_void S str ne = o ->
  red_expr S C (spec_error_or_void str ne) o /\
    (~ abort o -> o = out_void S).
Proof.
  introv E. unfolds in E. cases_if.
   applys_and red_spec_error_or_void_true. 
   forwards~ (RC&Cr): run_error_correct' E. splits*.
   inverts E. splits~. apply~ red_spec_error_or_void_false.
Qed.

Lemma out_error_or_cst_correct' : forall S C str (ne : native_error) v o,
  out_error_or_cst S str ne v = o ->
  red_expr S C (spec_error_or_cst str ne v) o /\
    (~ abort o -> o = out_ter S v).
Proof.
  introv E. unfolds in E. cases_if.
   applys_and red_spec_error_or_cst_true. forwards~ (RC&Cr): run_error_correct' E. splits*.
   inverts E. splits~. apply~ red_spec_error_or_cst_false.
Qed.

(* LATER: clean up redundant proof for the direct case *)
Lemma out_error_or_cst_correct : forall S C str ne v o,
  out_error_or_cst S str ne v = o ->
  red_expr S C (spec_error_or_cst str ne v) o.
Proof.
  introv HR. unfolds in HR. case_if.
  applys* red_spec_error_or_cst_true.
    applys* run_error_correct.
  run_inv. applys* red_spec_error_or_cst_false.
Qed.


Ltac run_select_proj_extra_error HT ::=
  match HT with
  | run_error => constr:(run_error_correct)
  | run_object_method => constr:(run_object_method_correct)
  end.

Lemma object_has_prop_correct : forall runs S C l x o,
  runs_type_correct runs ->
  object_has_prop runs S C l x = o ->
  red_expr S C (spec_object_has_prop l x) o.
Proof.
  introv IH HR. unfolds in HR. run_simpl. run_hyp E as M.
  applys~ red_spec_object_has_prop M. destruct x0.
  run red_spec_object_has_prop_1_default using runs_type_correct_object_get_prop.
  apply~ red_spec_object_has_prop_2. rewrite decide_def. repeat cases_if~.
Qed.

Lemma run_object_get_prop_correct : forall runs S C l x y,
  runs_type_correct runs ->
  run_object_get_prop runs S C l x = result_some y ->
  red_spec S C (spec_object_get_prop l x) y.
Proof.
  introv IH HR. unfolds in HR. 
  run. applys* red_spec_object_get_prop.
   applys* run_object_method_correct. clear E.
  destruct x0; tryfalse.
  run red_spec_object_get_prop_1_default. case_if.
   subst. run. applys red_spec_object_get_prop_2_undef.
    applys* run_object_method_correct.
    destruct x0; tryfalse.
      destruct p; tryfalse. run_inv. applys red_spec_object_get_prop_3_null.
      applys red_spec_object_get_prop_3_not_null. run_hyp*.
  run_inv. destruct a; tryfalse.
   applys* red_spec_object_get_prop_2_not_undef.
Admitted. (*faster*)


(*TODO: revisit this lemma when rules are fixed w.r.t. "vthis", 
 which should maybe be a value --as it might be null?*)
Lemma object_get_builtin_correct : forall runs S C B (vthis:object_loc) l x o,
  runs_type_correct runs ->
  object_get_builtin runs S C B vthis l x = o ->
  red_expr S C (spec_object_get_1 B vthis l x) o.
Proof.
  introv IH HR. unfolds in HR. destruct B; tryfalse.
  run red_spec_object_get_1_default. destruct a as [|[Ad|Aa]].
    run_inv. applys* red_spec_object_get_2_undef.
    run_inv. applys* red_spec_object_get_2_data.
    applys red_spec_object_get_2_accessor. 
     destruct (attributes_accessor_get Aa); tryfalse.
       destruct p; tryfalse. run_inv.
        applys* red_spec_object_get_3_accessor_undef.
       applys* red_spec_object_get_3_accessor_object. run_hyp*.
Admitted. (* faster *)

Lemma run_object_get_correct : forall runs S C l x o,
  runs_type_correct runs ->
  run_object_get runs S C l x = o ->
  red_expr S C (spec_object_get l x) o.
Proof.
  introv IH HR. unfolds in HR. run.
  applys* red_spec_object_get.
   applys* run_object_method_correct. clear E.
  applys* object_get_builtin_correct.
Qed.


Lemma object_can_put_correct : forall runs S C l x o,
  runs_type_correct runs ->
  object_can_put runs S C l x = o ->
  red_expr S C (spec_object_can_put l x) o.
Proof.
  introv IH HR. unfolds in HR. run. run_hyp E as CP.
  applys~ red_spec_object_can_put CP. destruct x0.
  run red_spec_object_can_put_1_default. destruct a.
   run. run_hyp E as P. applys~ red_spec_object_can_put_2_undef P.
    destruct x0 as [()|lproto]; tryfalse.
     run. run_hyp E as E. apply~ red_spec_object_can_put_4_null.
     run red_spec_object_can_put_4_not_null using run_object_get_prop_correct.
      destruct a as [|[Ad|Aa]].
       run. run_hyp E as E. apply~ red_spec_object_can_put_5_undef.
       run. run_hyp E as E. applys~ red_spec_object_can_put_5_data E. destruct x0.
        applys~ red_spec_object_can_put_6_extens_true.
        applys~ red_spec_object_can_put_6_extens_false.
       run_inv. apply~ red_spec_object_can_put_5_accessor. rewrite decide_def.
        repeat cases_if~.
   destruct a; run_inv.
    apply~ red_spec_object_can_put_2_data.
    apply~ red_spec_object_can_put_2_accessor. rewrite decide_def. repeat cases_if~.
Qed.




Lemma object_define_own_prop_correct : forall runs S C l x Desc str o,
  runs_type_correct runs ->
  object_define_own_prop runs S C l x Desc str = o ->
  red_expr S C (spec_object_define_own_prop l x Desc str) o.
Proof.
  introv IH HR. unfolds in HR. run. 
  (* LATER: create a tactic for the pattern of the next two lines *)
  applys* red_spec_object_define_own_prop.
   applys* run_object_method_correct. clear E.
  destruct x0.
  (* default *)
  run red_spec_object_define_own_prop_1_default.
  let_name as rej. asserts Rej: (forall S o,
      rej S = o ->
      red_expr S C (spec_object_define_own_prop_reject str) o). 
    clear HR S o. introv HR. subst.
    applys* red_spec_object_define_own_prop_reject.
    applys* out_error_or_cst_correct.
    clear EQrej.
  run. applys* red_spec_object_define_own_prop_2.
    applys* run_object_method_correct. clear E. 
  destruct a.
    case_if.
      let_name. run. forwards B: @pick_option_correct (rm E).
       applys* red_spec_object_define_own_prop_3_undef_true A. 
       case_if; case_if*.
      subst. applys* red_spec_object_define_own_prop_3_undef_false.
    let_name as wri. asserts Wri: (forall S A o,
        wri S A = res_out o ->
        red_expr S C (spec_object_define_own_prop_write l x A Desc str) o).
      clear HR S o. introv HR. subst.
      run. forwards B: @pick_option_correct (rm E).
       applys* red_spec_object_define_own_prop_write.
      clear EQwri.
    case_if.
      run_inv. applys* red_spec_object_define_own_prop_3_includes.
      applys* red_spec_object_define_own_prop_3_not_include.
      case_if.
        run_inv. applys* red_spec_object_define_own_prop_4_reject.
        applys* red_spec_object_define_own_prop_4_not_reject. case_if.
          applys* red_spec_object_define_own_prop_5_generic. case_if.
            applys* red_spec_object_define_own_prop_5_a. case_if;
             [ | applys* red_spec_object_define_own_prop_6a_reject].
  let_name. run. forwards B: @pick_option_correct (rm E).
   applys* red_spec_object_define_own_prop_6a_accept A'.
   case_if. destruct a; inverts n2.
     applys red_spec_object_define_own_prop_5_b. rewrite* <- H0.
      case_if.
        applys* red_spec_object_define_own_prop_6b_false_reject.
        applys* red_spec_object_define_own_prop_6b_false_accept.
     applys* red_spec_object_define_own_prop_5_c. case_if. 
       applys* red_spec_object_define_own_prop_6c_1.
       applys* red_spec_object_define_own_prop_6c_2.  
  (* arguments object *)
  skip. (* TODO: implement *)
Admitted.


Lemma prim_new_object_correct : forall S C w o,
  prim_new_object S w = o ->
  red_expr S C (spec_prim_new_object w) o.
Proof. introv H. false. Qed.

Lemma run_error_correct_2 : forall S (ne : native_error) o C,
  run_error S ne = o -> red_expr S C (spec_error ne) o.
Proof. intros. apply* run_error_correct. Qed.

(* todo: move to the right place above here *)
Lemma to_object_correct : forall S C v o,
  to_object S v = o ->
  red_expr S C (spec_to_object v) o.
Proof.
  hint run_error_correct_2, prim_new_object_correct.
  introv HR. unfolds in HR. destruct v as [w|l].
    destruct w.
      applys* red_spec_to_object_undef_or_null. 
      applys* red_spec_to_object_undef_or_null.
      applys* red_spec_to_object_prim. rew_logic*. splits; congruence.
      applys* red_spec_to_object_prim. rew_logic*. splits; congruence.
      applys* red_spec_to_object_prim. rew_logic*. splits; congruence.
    run_inv. applys* red_spec_to_object_object.
Qed.


Lemma prim_value_get_correct : forall runs S C v x o,
  runs_type_correct runs ->
  prim_value_get runs S C v x = o ->
  red_expr S C (spec_prim_value_get v x) o.
Proof.
  introv IH HR. unfolds in HR.
  run red_spec_prim_value_get using to_object_correct.
  applys* red_spec_prim_value_get_1.
  (* TODO: problem with the "this" which is a value or object_loc ?
  lets: object_get_builtin_correct.
  *) skip.
Qed.

Lemma object_put_complete_correct : forall runs S C B vthis l x v str o,
  runs_type_correct runs ->
  object_put_complete runs B S C vthis l x v str = o ->
  red_expr S C (spec_object_put_1 B vthis l x v str) o.
Proof.
  introv IH HR. unfolds in HR. destruct B.
  run red_spec_object_put_1_default using object_can_put_correct. cases_if.
   run red_spec_object_put_2_true. let_name.
    asserts follows_correct: (forall o, True ->
        follow tt = o ->
        red_expr S0 C (spec_object_put_3 vthis l x v str (specret_val S2 a)) o).
      clear HR. introv N E. substs. 
(* TODO:
      run red_spec_object_put_3_not_data.

  |  : forall S0 S C vthis l x v throw Aa y1 o, (* Step 4 *)
      red_spec S C (spec_object_get_prop l x) y1 ->
      red_expr S C (spec_object_put_4 vthis l x v throw y1) o ->
      red_expr S0 C (spec_object_put_3 vthis l x v throw (ret (T:=full_descriptor) S (attributes_accessor_of Aa))) o
      (* According to the spec, it should be every cases that are not [attributes_data_of].  
        There thus lacks a case there:  [full_descriptor_undef]. -- Martin *)

  | red_spec_object_put_4_accessor : forall S0 S C vsetter lfsetter vthis l x v throw Aa o1 o, (* Step 5 *)
      vsetter = attributes_accessor_set Aa ->
      vsetter <> undef -> (* Note: this premise is a derived fact *)
      vsetter = value_object lfsetter ->
      red_expr S C (spec_call lfsetter vthis (v::nil)) o1 ->
      red_expr S C (spec_object_put_5 o1) o ->
      red_expr S0 C (spec_object_put_4 vthis l x v throw (dret S (attributes_accessor_of Aa))) o

  | red_spec_object_put_4_not_accessor_object : forall S0 S C (lthis:object_loc) l x v throw Ad Desc o1 o, (* Step 6 *)
      Desc = descriptor_intro_data v true true true ->
      red_expr S C (spec_object_define_own_prop l x Desc throw) o1 ->
      red_expr S C (spec_object_put_5 o1) o ->
      red_expr S0 C (spec_object_put_4 lthis l x v throw (dret S (attributes_data_of Ad))) o
      (* According to the spec, it should be every cases that are not [attributes_accessor_of].  There thus (unless it's not possible?) lacks a case there:  [full_descriptor_undef]. -- Martin *)

  | red_spec_object_put_4_not_accessor_prim : forall S0 S C (wthis:prim) l x v throw Ad o, (* Step 6, for prim values *)
      red_expr S C (spec_error_or_void throw native_error_type) o ->
      red_expr S0 C (spec_object_put_4 wthis l x v throw (dret S (attributes_data_of Ad))) o

  | red_spec_object_put_5_return : forall S0 S C rv, (* Steps 3.c and 7 *)
      red_expr S0 C (spec_object_put_5 (out_ter S rv)) (out_void S)
*)
 skip.

     destruct a as [|[Ad|Aa]]; try solve [apply~ follows_correct].
     clear EQfollow follow follows_correct.
     destruct vthis as [wthis|lthis].
      apply~ red_spec_object_put_3_data_prim. apply~ out_error_or_void_correct.
      let_simpl. run* red_spec_object_put_3_data_object
        using object_define_own_prop_correct. apply~ red_spec_object_put_5_return.
   apply~ red_spec_object_put_2_false. apply~ out_error_or_void_correct.
Qed.

Lemma prim_value_put_correct : forall runs S C w x v str o,
  runs_type_correct runs ->
  prim_value_put runs S C w x v str = o ->
  red_expr S C (spec_prim_value_put w x v str) o.
Proof.
  introv IH HR. unfolds in HR.
  run red_spec_prim_value_put using to_object_correct.
  applys* red_spec_prim_value_put_1.
  applys* object_put_complete_correct.
Qed.



(*************************************************************)

Lemma env_record_get_binding_value_correct : forall runs S C L rn rs o,
  runs_type_correct runs ->
  env_record_get_binding_value runs S C L rn rs = o ->
  red_expr S C (spec_env_record_get_binding_value L rn rs) o.
Proof.
  introv IH HR. unfolds in HR.
  run_simpl. forwards B: @pick_option_correct (rm E).
  applys~ red_spec_env_record_get_binding_value B. destruct x.
   run_simpl. rewrite <- Heap.binds_equiv_read_option in E. destruct x as [mu v].
    applys~ red_spec_env_record_get_binding_value_1_decl E. do 2 cases_if.
     apply~ out_error_or_cst_correct.
     run_inv. apply~ red_spec_returns.
   run red_spec_env_record_get_binding_value_1_object using object_has_prop_correct.
    cases_if; run_inv.
     apply~ red_spec_env_record_get_binding_value_obj_2_true.
      applys~ run_object_get_correct HR.
     apply~ red_spec_env_record_get_binding_value_obj_2_false.
      applys~ out_error_or_cst_correct HR.
Qed.


Lemma res_res_run_error_correct : forall runs S C ne T (y:specret T),
  runs_type_correct runs ->
  res_res (run_error S ne) = result_some y ->
  red_spec S C (spec_error_spec ne) y.
Proof.
  introv IH HR. unfolds res_res. 
  lets ([|y1]&E&K): if_result_some_out (rm HR); tryfalse_nothing. run_inv.
  lets (E2&Ab): run_error_correct' (rm E).
  applys* red_spec_error_spec.
  abort.
Qed.



Lemma ref_kind_env_record_inv : forall r,
  ref_kind_of r = ref_kind_env_record ->
  exists L, ref_base r = ref_base_type_env_loc L.
Proof.
  introv E. unfolds ref_kind_of.
  destruct (ref_base r).
    destruct v; tryfalse. destruct p; tryfalse.
    exists___*.
Qed.

Lemma ref_kind_base_object_inv : forall r,
  (ref_kind_of r = ref_kind_primitive_base \/
     ref_kind_of r = ref_kind_object) ->
  exists v, ref_base r = ref_base_type_value v.
Proof.
  introv E. unfolds ref_kind_of.
  destruct E; destruct (ref_base r); tryfalse;
    destruct v; tryfalse; try solve [exists___*].
Qed.



Lemma ref_get_value_correct : forall runs S C rv y,
  runs_type_correct runs ->
  ref_get_value runs S C rv = result_some y ->
  red_spec S C (spec_get_value rv) y.
Proof.
  introv IH HR. unfolds in HR. destruct rv; tryfalse.
  run_inv. applys* red_spec_ref_get_value_value.
  let_name as M. 
  asserts M_correct: (
    (  ref_kind_of r = ref_kind_primitive_base 
    \/ ref_kind_of r = ref_kind_object) ->
    M tt = result_some y ->
    red_spec S C (spec_get_value r) y).
   clear HR. introv EQ HR. subst M.
   asserts: (ref_is_property r). unfolds. destruct* EQ.
   lets (v&Ev): ref_kind_base_object_inv EQ. rewrite Ev in HR.
   unfolds ref_has_primitive_base. case_if.  
     run* red_spec_ref_get_value_ref_b using prim_value_get_correct. case_if*. 
      applys* red_spec_ref_get_value_ref_b_1.
     destruct EQ; tryfalse. destruct v as [|l]; tryfalse.
     run* red_spec_ref_get_value_ref_b using run_object_get_correct. case_if*. 
      applys* red_spec_ref_get_value_ref_b_1.
    clear EQM.
  sets_eq k: (ref_kind_of r). destruct k; tryfalse.
  (* case undef *)
  applys* red_spec_ref_get_value_ref_a. unfolds*.
   applys* res_res_run_error_correct.
  (* case prim *)
  applys* M_correct.
  (* case object *)
  applys* M_correct.
  (* case env_record *)
  lets (L&EQL): ref_kind_env_record_inv (sym_eq EQk).
  rewrite EQL in HR.
  run* red_spec_ref_get_value_ref_c using env_record_get_binding_value_correct.
  applys* red_spec_ref_get_value_ref_c_1.
Admitted. (*faster*)


Lemma object_put_correct : forall runs S C l x v str o,
  runs_type_correct runs ->
  object_put runs S C l x v str = o ->
  red_expr S C (spec_object_put l x v str) o.
Admitted.

Lemma env_record_set_mutable_binding_correct : forall runs S C L x v str o,
  runs_type_correct runs ->
  env_record_set_mutable_binding runs S C L x v str = o ->
  red_expr S C (spec_env_record_set_mutable_binding L x v str) o.
Proof.
  introv IH HR. unfolds in HR.
  run_simpl. forwards B: @pick_option_correct (rm E).
  applys~ red_spec_env_record_set_mutable_binding B. destruct x0.
   run_simpl. rewrite <- Heap.binds_equiv_read_option in E. destruct x0 as [mu ?].
    applys~ red_spec_env_record_set_mutable_binding_1_decl E.
    unfold mutability_is_mutable. cases_if in HR as D; run_inv;
      rewrite decide_def in D; repeat cases_if.
     apply~ red_spec_returns.
     apply~ out_error_or_void_correct.
   apply~ red_spec_env_record_set_mutable_binding_1_object.
    applys~ object_put_correct HR.
Qed.

Lemma ref_put_value_correct : forall runs S C rv v o,
  runs_type_correct runs ->
  ref_put_value runs S C rv v = o ->
  red_expr S C (spec_put_value rv v) o.
Admitted.

Lemma run_expr_get_value_correct : forall runs S C e y,
  runs_type_correct runs -> 
  run_expr_get_value runs S C e = result_some y -> 
  red_spec S C (spec_expr_get_value e) y.
Admitted.

Ltac run_select_proj_extra_ref HT ::= 
  match HT with
  | object_put => constr:(object_put_correct)
  | ref_put_value => constr:(ref_put_value_correct)
  | run_expr_get_value => constr:(run_expr_get_value_correct)
  | object_define_own_prop => constr:(object_define_own_prop_correct)
  end.


(* todo; deprecated

Lemma run_expr_get_value_correct : forall runs S C e K o,
  runs_type_correct runs ->
  run_expr_get_value runs S C e K = o -> exists o1,
    red_expr S C (spec_expr_get_value e) o1 /\
      run_expr_get_value_post K o o1.
Admitted.
*)

(*
Ltac run_select_lemma_run_expr_get_value T ::=
  match T with run_expr_get_value _ _ _ _ _ => constr:(run_expr_get_value_correct) end.

Ltac run_post_run_expr_get_value ::=
  let o1 := fresh "o1" in
  let Eq := fresh "Eq" in
  let Er := fresh "Er" in
  let Ab := fresh "Ab" in
  match goal with
  | H: run_expr_get_value_post _ _ _ |- _ =>
    let O1 := fresh "O1" in
    let S1 := fresh "S" in
    let v1 := fresh "v" in
    destruct H as [(o1&Eq&Er&Ab)|(S1&v1&O1&H)];
    [ try abort | try subst_hyp O1 ]
  end.
*)


Lemma env_record_create_mutable_binding_correct : forall runs S C L x deletable_opt o,
  runs_type_correct runs ->
  env_record_create_mutable_binding runs S C L x deletable_opt = o ->
  red_expr S C (spec_env_record_create_mutable_binding L x deletable_opt) o.
Proof.
  introv IH HR. unfolds in HR. let_simpl.
  run_simpl. forwards B: @pick_option_correct (rm E).
  applys~ red_spec_env_record_create_mutable_binding B.
  destruct x0.
   cases_if; run_inv. let_simpl. run_inv.
    apply~ red_spec_env_record_create_mutable_binding_1_decl_indom.
   run red_spec_env_record_create_mutable_binding_1_object
     using object_has_prop_correct. cases_if. let_simpl.
    run* red_spec_env_record_create_mutable_binding_obj_2.
    apply~ red_spec_env_record_create_mutable_binding_obj_3.
Qed.

Lemma env_record_create_set_mutable_binding_correct : forall runs S C L x deletable_opt v str o,
  runs_type_correct runs ->
  env_record_create_set_mutable_binding runs S C L x deletable_opt v str = o ->
  red_expr S C (spec_env_record_create_set_mutable_binding L x deletable_opt v str) o.
Proof.
  introv IH HR. unfolds in HR.
  run red_spec_env_record_create_set_mutable_binding
    using env_record_create_mutable_binding_correct.
  forwards: env_record_set_mutable_binding_correct IH (rm HR).
  apply~ red_spec_env_record_create_set_mutable_binding_1.
Qed.

Lemma env_record_create_immutable_binding_correct : forall S C L x o,
  env_record_create_immutable_binding S L x = o ->
  red_expr S C (spec_env_record_create_immutable_binding L x) o.
Proof.
  introv HR. unfolds in HR.
  run_simpl. forwards B: @pick_option_correct (rm E).
  destruct x0; tryfalse. cases_if. run_inv.
  applys~ red_spec_env_record_create_immutable_binding B.
Qed.

Lemma env_record_initialize_immutable_binding_correct : forall S C L x v o,
  env_record_initialize_immutable_binding S L x v = o ->
  red_expr S C (spec_env_record_initialize_immutable_binding L x v) o.
Proof.
  introv HR. unfolds in HR.
  run_simpl. forwards B: @pick_option_correct (rm E). destruct x0; tryfalse.
  run_simpl. forwards B': @pick_option_correct (rm E). cases_if. let_simpl. run_inv. substs.
  applys~ red_spec_env_record_initialize_immutable_binding B B'.
Qed.

Lemma object_default_value_correct : forall runs S C l pref o,
  runs_type_correct runs ->
  object_default_value runs S C l pref = o ->
  red_expr S C (spec_object_default_value l pref) o.
Admitted. 


(** Conversions *)


Lemma to_primitive_correct : forall runs S C v o prefo,
  runs_type_correct runs ->
  to_primitive runs S C v prefo = o -> 
  red_expr S C (spec_to_primitive v prefo) o.
Proof.
  introv IH HR. unfolds in HR. destruct v.
  run_inv. applys* red_spec_to_primitive_pref_prim.
  applys* red_spec_to_primitive_pref_object.
  applys* object_default_value_correct.
Qed.

Lemma to_number_correct : forall runs S C v o,
  runs_type_correct runs ->
  to_number runs S C v = o -> 
  red_expr S C (spec_to_number v) o.
Proof.
  introv IH HR. unfolds in HR. destruct v.
  run_inv. applys* red_spec_to_number_prim.
  run red_spec_to_number_object using to_primitive_correct.
  applys* red_spec_to_number_1.
Qed.

Lemma to_string_correct : forall runs S C v o,
  runs_type_correct runs ->
  to_string runs S C v = o -> 
  red_expr S C (spec_to_string v) o.
Proof.
  introv IH HR. unfolds in HR. destruct v.
  run_inv. applys* red_spec_to_string_prim.
  run red_spec_to_string_object using to_primitive_correct.
  applys* red_spec_to_string_1.
Qed.

Lemma to_integer_correct : forall runs S C v o,
  runs_type_correct runs ->
  to_integer runs S C v = o -> 
  red_expr S C (spec_to_integer v) o.
Proof.
  introv IH HR. unfolds in HR.
  run red_spec_to_integer using to_number_correct.
  applys* red_spec_to_integer_1.
Qed.

Ltac run_select_proj_extra_conversions HT ::= 
  match HT with
  | to_primitive => constr:(to_primitive_correct)
  | to_number => constr:(to_number_correct)
  | to_string => constr:(to_string_correct)
  end.







(* TODO:  to_int32, to_uint32 *)



(*
Definition run_expr_get_value_post K o o1 :=
  (eqabort o1 o \/
    exists S1, exists (v1 : value), o1 = out_ter S1 v1 /\
      K S1 v1 = result_some o).
*)

(*
Lemma run_expr_get_value_correct : forall runs,
(*
 runs_type_correct runs -> forall S C e K o,
  run_expr_get_value runs S C e K = o -> exists o1,
    red_expr S C (spec_expr_get_value e) o1 /\
      run_expr_get_value_post K o o1. *)

 runs_type_correct runs -> forall S C e K o,
  run_expr_get_value runs S C e K = o -> exists o1,
    red_spec S C (spec_expr_get_value e) (ret S o1) /\
      run_expr_get_value_post K o o1. 

Admitted.
*)




(************************************************************)
(* Treatement of [spec_expr_get_value_conv] *)

Definition if_spec_ter_post_bool (K:state->bool->result) o (y:specret value) :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (b:bool), y = specret_val S (value_prim b)
       /\ K S b = o).

Ltac run_post_if_spec_ter_post_bool H := (* todo: integrate into run_post *)
  let Ab := fresh "Ab" in
  let Eq := fresh "Eq" in
  let S1 := fresh "S" in
  let b := fresh "b" in
  let O1 := fresh "O1" in
  destruct H as [(Er&Ab)|(S1&b&O1&H)];
  [ try abort | try subst_hyp O1 ].

Lemma if_spec_ter_post_to_bool : forall (K:state->bool->result) S C e o y1,
  red_spec S C (spec_expr_get_value e) y1 ->
  if_spec_ter_post 
   (fun S v => Let b := convert_value_to_boolean v in K S b) o y1 ->
  exists y2,
     red_spec S C (spec_expr_get_value_conv spec_to_boolean e) y2
  /\ if_spec_ter_post_bool K o y2.
Proof. 
  introv HR HP. run_post. 
  exists y1. splits.
    subst. apply* red_spec_expr_get_value_conv. abort.
    subst. left. splits~.
  exists (specret_val S1 (value_prim (convert_value_to_boolean a))). splits.
    applys* red_spec_expr_get_value_conv.
     applys* red_spec_expr_get_value_conv_1.
     applys* red_spec_to_boolean.
     applys* red_spec_expr_get_value_conv_2.
    right. exists S1 __. split. reflexivity. auto.
Qed.

(* LATER: avoid the copy-paste, and rename the tactic *)

Definition if_spec_ter_post_object (K:state->object_loc->result) o (y:specret value) :=
     (y = specret_out o /\ abort o)
  \/ (exists S, exists (l:object_loc), y = specret_val S (value_object l)
       /\ K S l = o).


Lemma if_spec_ter_post_to_object : forall (K:state->object_loc->result) S C e o y1,
  red_spec S C (spec_expr_get_value e) y1 ->
  if_spec_ter_post 
   (fun S v => if_object (to_object S v) K) o y1 ->
  exists y2,
     red_spec S C (spec_expr_get_value_conv spec_to_object e) y2
  /\ if_spec_ter_post_object K o y2.
Proof. 
  introv HR HP. run_post. 
  exists y1. splits.
    subst. apply* red_spec_expr_get_value_conv. abort.
    subst. left. splits~.
  run_pre. lets*: to_object_correct C (rm R1). run_post.
    subst. exists (specret_out (T:=value) o1). split.
      applys* red_spec_expr_get_value_conv. 
       applys* red_spec_expr_get_value_conv_1. abort. 
      left. splits~.
    exists (specret_val S0 (value_object l)). split.
      applys* red_spec_expr_get_value_conv. 
       applys* red_spec_expr_get_value_conv_1.
       applys* red_spec_expr_get_value_conv_2.
      right. exists___*.
Qed.




(**************************************************************)
(* Auxiliary results for [spec_expr_get_value_conv] *)



Hint Unfold eqabort. (* todo move *)



Lemma run_construct_prealloc_correct : forall runs S C B args o,
  runs_type_correct runs ->
  run_construct_prealloc runs S C B args = o ->
  red_expr S C (spec_construct_prealloc B args) o.
Admitted. 

Lemma run_construct_default_correct : forall runs S C l args o,
  runs_type_correct runs ->
  run_construct_default runs S C l args = o ->
  red_expr S C (spec_construct_default l args) o.
Admitted.

Lemma run_construct_correct : forall runs S C co l args o,
  runs_type_correct runs ->
  run_construct runs S C co l args = o ->
  red_expr S C (spec_construct_1 co l args) o.
Admitted.

Lemma entering_eval_code_correct : forall runs S C bdirect bd F K o,
  runs_type_correct runs ->
  entering_eval_code runs S C bdirect bd F = o ->
  (forall S' C' o', F S' C' = o' -> red_expr S' C' K o') ->
  red_expr S C (spec_entering_eval_code bdirect bd K) o.
Admitted.

Lemma run_eval_correct : forall runs S C (is_direct_call : bool) vs o,
  runs_type_correct runs ->
  run_eval runs S C is_direct_call vs = o ->
  red_expr S C (spec_call_global_eval is_direct_call vs) o.
Proof.
  introv IH HR. unfolds in HR.
  lets (v&H&E): arguments_from_spec_1 vs. rewrites (rm E) in *.
  applys* red_spec_call_global_eval (rm H). 
  destruct v; 
   [| run_inv; applys* red_spec_call_global_eval_1_not_string; simpl; congruence].
  destruct p; run_inv; 
     try (applys* red_spec_call_global_eval_1_not_string; simpl; congruence).
  forwards* H: (pick_spec (P:=parse s)). applys parse_exists. 
  destruct (pick (parse s)).
  applys* red_spec_call_global_eval_1_string_parse (rm H).
  applys* entering_eval_code_correct (rm HR). clear S C o.
  introv HR. run red_spec_call_global_eval_2.
  sets_eq RT: (res_type R). destruct RT; tryfalse.
    run. cases (res_value R); tryfalse; run_inv.
      applys* red_spec_call_global_eval_3_normal_empty.
      destruct R. simpls. subst.
       applys* red_spec_call_global_eval_3_normal_value.
    run_inv. applys* red_spec_call_global_eval_3_throw.
  applys* red_spec_call_global_eval_1_string_not_parse. run_hyp*.
Admitted. (*faster*)

Lemma run_list_expr_correct : forall runs S C es y,
  runs_type_correct runs ->
  run_list_expr runs S C nil es = result_some y ->
  red_spec S C (spec_list_expr es) y.
Proof.
  introv IH. cuts M: (forall es S C vs y, 
      run_list_expr runs S C vs es = result_some y ->
      red_spec S C (spec_list_expr_1 (rev vs) es) y).
    intros HR. apply red_spec_list_expr. applys* M (@nil value).
  clears S C es y. intros es. induction es; introv HR.
  simpls. run_inv. applys* red_spec_list_expr_1_nil.
  simpls. run red_spec_list_expr_1_cons. 
   applys red_spec_list_expr_2. forwards M: IHes HR.
   rew_list in M. auto.
Admitted. (*faster*)


Lemma run_call_default_correct : forall runs S C lf o,
  runs_type_correct runs ->
  run_call_default runs S C lf = o ->
  red_expr S C (spec_call_default_1 lf) o.
Proof.
  introv IH HR. unfolds in HR. let_simpl. 
  run. applys* red_spec_call_default_1.
    applys* run_object_method_correct. clear E.
  destruct x.
    case_if.
      applys* red_spec_call_default_2_empty_body.
       run_inv. applys* red_spec_call_default_3_normal.
      run* red_spec_call_default_2_body.
        destruct R as [RT RV RL]; simpls. subst. 
         applys red_spec_call_default_3_normal.
        destruct R as [RT RV RL]; simpls. subst. 
         applys red_spec_call_default_3_return.
        subst. abort.
    applys* red_spec_call_default_2_empty_body. 
     run_inv. applys* red_spec_call_default_3_normal.
Admitted. (* faster *)


Lemma type_of_prim_not_object : forall w,
  type_of w <> type_object.
Proof. destruct w; simpl; try congruence. Qed.


(* to merge to top *)
Axiom run_call_correct : forall runs S C l vthis vs o,
  (* l <> prealloc_global_eval *)
  runs_type_correct runs ->
  runs_type_call runs S C l vthis vs = o ->
  red_expr S C (spec_call l vthis vs) o.

(* todo: needed to be up here *)
Lemma env_record_implicit_this_value_correct : forall S C L v,
  env_record_implicit_this_value S L = Some v ->
  red_expr S C (spec_env_record_implicit_this_value L) (out_ter S v).
Proof.
  introv HR. unfolds in HR.
  run_simpl HR as H; tryfalse. inverts H. forwards B: @pick_option_correct (rm E).
  applys~ red_spec_env_record_implicit_this_value B. destruct n.
   applys~ red_spec_env_record_implicit_this_value_1_decl.
   applys~ red_spec_env_record_implicit_this_value_1_object.
Qed.

Lemma run_expr_call_correct : forall runs S C e1 e2s o,
  runs_type_correct runs ->
  run_expr_call runs S C e1 e2s = o ->
  red_expr S C (expr_call e1 e2s) o.
Proof.
  introv IH HR. unfolds in HR.
  let_name. run red_expr_call.
  run red_expr_call_1 using ref_get_value_correct.
  run red_expr_call_2 using run_list_expr_correct.
  destruct a.
    applys* red_expr_call_3. left. apply type_of_prim_not_object. run_hyp*.
  case_if.
  applys* red_expr_call_3_callable.
  rename o0 into l. rename a0 into vs.
  let_name as M. asserts M_correct: (forall S0 vthis o,
      M vthis = o ->
      red_expr S0 C (expr_call_5 l is_eval_direct vs (out_ter S3 vthis)) o).
    clear HR S o. introv HR. subst M.
    case_if.
      subst. applys red_expr_call_5_eval. applys* run_eval_correct.
      applys* red_expr_call_5_not_eval. applys* run_call_correct.
    clear EQM.
  subst. destruct rv; tryfalse.
    applys* red_expr_call_4_not_ref.
    cases (ref_base r).
      case_if. applys* red_expr_call_4_prop.
      run. applys* red_expr_call_4_env. 
       applys* env_record_implicit_this_value_correct.
  (* other branch *) 
  applys* red_expr_call_3. run_hyp*.
Admitted. (*faster*)



Lemma creating_function_object_proto_correct : forall runs S C l o,
  runs_type_correct runs ->
  creating_function_object_proto runs S C l = o ->
  red_expr S C (spec_creating_function_object_proto l) o.
Proof.
  introv IH HR. unfolds in HR.
  run red_spec_creating_function_object_proto 
    using run_construct_prealloc_correct.
  let_simpl. run red_spec_creating_function_object_proto_1.
  let_simpl. applys* red_spec_creating_function_object_proto_2. run_hyp*.
Admitted. (* faster *)


Lemma creating_function_object_correct : forall runs S C names bd X str o,
  runs_type_correct runs ->
  creating_function_object runs S C names bd X str = o ->
  red_expr S C (spec_creating_function_object names bd X str) o.
Proof.
  introv IH HR. unfolds in HR.  
  let_simpl. let_simpl. let_simpl. let_name. destruct p as [l S1].
  let_simpl. run* red_spec_creating_function_object. rewrite* EQp. 
    skip. (*one bug*)
  run red_spec_creating_function_object_1 
    using creating_function_object_proto_correct.
  case_if; destruct str; tryfalse.
    run_inv. applys* red_spec_creating_function_object_2_not_strict.
    let_simpl. let_simpl. 
     run* red_spec_creating_function_object_2_strict. clear EQp.
     run* red_spec_creating_function_object_3.
     applys* red_spec_creating_function_object_4.
Admitted. (* faster*)




Lemma execution_ctx_binding_inst_correct : forall runs S C ct funco p args o,
  runs_type_correct runs ->
  execution_ctx_binding_inst runs S C ct funco p args = o ->
  red_expr S C (spec_binding_inst ct funco p args) o.
Admitted.

Ltac run_select_proj_extra_construct HT ::= 
  match HT with
  | run_construct_prealloc => constr:(run_construct_prealloc_correct)
  | run_construct => constr:(run_construct_correct)
  | run_call_default => constr:(run_call_default_correct)
  | creating_function_object_proto => constr:(creating_function_object_proto_correct)
  | creating_function_object => constr:(creating_function_object_correct)
  | run_list_expr => constr:(run_list_expr_correct)
  | execution_ctx_binding_inst => constr:(execution_ctx_binding_inst_correct)
  end.




(**************************************************************)
(** ** Property descriptors *)


Lemma from_prop_descriptor_correct : forall runs S0 S C D o,
  runs_type_correct runs ->
  from_prop_descriptor runs S C D = o ->
  red_expr S0 C (spec_from_descriptor (ret S D)) o.
Proof.
  introv IH HR. unfolds in HR. destruct D.
  run_inv. applys* red_spec_from_descriptor_undef.
  run* red_spec_from_descriptor_some.
  rename a into A.
  let_name as M. asserts M_correct: (forall S0 S b o,
    M S b = o ->
    red_expr S0 C (spec_from_descriptor_4 l A (out_ter S b)) o).
   clear HR S o. introv HR. subst M.
    let_name. run* red_spec_from_descriptor_4. congruence.
    let_name. run* red_spec_from_descriptor_5. congruence.
    applys* red_spec_from_descriptor_6.
    clear EQM.
  destruct A.
    let_name. run* red_spec_from_descriptor_1_data. congruence.
     let_name. run red_spec_from_descriptor_2_data. congruence.
     applys* M_correct.
    let_name. run red_spec_from_descriptor_1_accessor. congruence.
     let_name. run red_spec_from_descriptor_3_accessor. congruence.
     applys* M_correct.
Admitted. (*faster*)



(**************************************************************)
(** ** Main theorem *)


Lemma run_elements_correct : forall runs,
  runs_type_correct runs -> forall rv,
  follow_elements rv (fun S C => run_elements runs S C rv).
Proof.
(* TODO: don't do it because the definition will need to change
  in order to first process all but the last elements. *)
(*
  introv IH. intros rv S C les o HR. induction les.
  simpls. run_inv. applys* red_prog_1_nil.
  unfold run_elements' in HR.
red_prog_1_cons_stat 
red_prog_2 
red_prog_3 
red_prog_1_cons_funcdecl
*)


Admitted. (* OLD
  intros runs [IHe IHs IHp IHc IHhi IHw IHowp IHop IHpo] rv S C es S' res R.
  gen rv S C S' res R. induction es; simpls; introv R.
   unmonad. apply~ red_prog_1_nil.
   destruct a.
    (* stat *)
    unmonad.
     (* Throw case *)
     forwards~ RC: IHs (rm E). applys~ red_prog_1_cons_stat RC. abort_prog.
     (* Other cases *)
     forwards~ RC: IHs (rm E). applys~ red_prog_1_cons_stat RC. apply~ red_prog_2.
     rewrite <- res_type_res_overwrite_value_if_empty in HE.
     tests N: (res_type R0 = restype_normal).
      rewrite N in HE. forwards~ (E1&E2): if_empty_label_out (rm HE).
       rewrite <- res_label_res_overwrite_value_if_empty in E1.
       destruct R0 as [rt0 rv0 rl0]. simpls. substs. fold (res_normal rv0) in *.
       forwards~ (rv'&Erv'&?): res_overwrite_value_if_empty_resvalue.
       rewrite <- Erv' in *. applys~ red_prog_3.
       rewrite res_overwrite_value_if_empty_empty in E2. forwards~: IHes E2.
      rewrite res_overwrite_value_if_empty_empty in *.
       asserts H: (out_ter S0 (res_overwrite_value_if_empty rv R0) = out_ter S' res).
         destruct R0 as [rt0 rv0 rl0]. destruct rt0; simpls; tryfalse; inverts~ HE.
       clear HE. inverts H. destruct R0 as [rt0 rv0 rl0]. simpls.
       unfold res_overwrite_value_if_empty in *. cases_if; simpls; substs;
        abort_prog; constructors; intro H; unfolds in H; simpls; false.
    (* func_decl *)
    forwards RC: IHes (rm R). apply~ red_prog_1_cons_funcdecl.
Qed. *)


Lemma create_new_function_in_correct : forall runs S C args bd o,
  runs_type_correct runs ->
  create_new_function_in runs S C args bd = o ->
  red_expr S C (spec_create_new_function_in C args bd) o.
Proof.
  introv IH HR. unfolds in HR. applys red_spec_create_new_function_in.
  applys* creating_function_object_correct. 
Qed.

Lemma init_object_correct : forall runs S C l (pds : propdefs) o,
  runs_type_correct runs ->
  init_object runs S C l pds = o ->
  red_expr S C (expr_object_1 l pds) o.
Proof.
  introv IH. gen S. induction pds as [|(pn&pb) pds]; introv HR.
  simpls. run_inv. applys red_expr_object_1_nil.
  simpls. let_name. let_name. 
  asserts follows_correct: (forall S A, follows S A = o ->
      red_expr S C (expr_object_4 l x A pds) o). 
    subst follows. clear HR. introv HR.
    run red_expr_object_4 using object_define_own_prop_correct. 
     applys* red_expr_object_5. 
    clear EQfollows.
  applys* red_expr_object_1_cons x.
  destruct pb.
  run red_expr_object_2_val.
   applys* red_expr_object_3_val. 
    run red_expr_object_2_get using create_new_function_in_correct.
     applys* red_expr_object_3_get.
    run red_expr_object_2_set using create_new_function_in_correct.
     applys* red_expr_object_3_set. 
Qed.


Lemma run_binary_op_correct : forall runs S C (op : binary_op) v1 v2 o,
  run_binary_op runs S C op v1 v2 = o ->
  red_expr S C (expr_binary_op_3 op v1 v2) o.
Admitted.

Lemma env_record_has_binding_correct : forall runs S C L x o,
  runs_type_correct runs ->
  env_record_has_binding runs S C L x = o ->
  red_expr S C (spec_env_record_has_binding L x) o.
Proof.
  introv IH HR. unfolds in HR. run_simpl. 
  forwards B: @pick_option_correct (rm E).
  applys~ red_spec_env_record_has_binding B. destruct x0; run_inv.
   apply~ red_spec_env_record_has_binding_1_decl. 
    rewrite decide_def; auto.
   apply~ red_spec_env_record_has_binding_1_object.
    apply* object_has_prop_correct.
Qed.

Lemma lexical_env_get_identifier_ref_correct : forall runs S C lexs x str y,
  runs_type_correct runs ->
  lexical_env_get_identifier_ref runs S C lexs x str = result_some y ->
  red_spec S C (spec_lexical_env_get_identifier_ref lexs x str) y.
Proof.
  introv IH. gen S C. induction lexs; introv HR.
  simpls. run_inv.
   applys* red_spec_lexical_env_get_identifier_ref_nil.
  simpls. 
  applys red_spec_lexical_env_get_identifier_ref_cons.
  run red_spec_lexical_env_get_identifier_ref_cons_1 using env_record_has_binding_correct.
  cases_if; run_inv.
   apply~ red_spec_lexical_env_get_identifier_ref_cons_2_true.
   apply~ red_spec_lexical_env_get_identifier_ref_cons_2_false.
Qed.

Lemma run_typeof_value_correct : forall S v,
  run_typeof_value S v = typeof_value S v.
Proof. intros. destruct v; simpl. auto. case_if; case_if*. Qed.

Ltac run_select_proj_extra_get_value HT ::= 
  match HT with
  | ref_get_value => constr:(ref_get_value_correct)
  end.


Hint Extern 1 (regular_unary_op _) =>
    intros ?; false_invert.

Lemma prepost_op_correct : forall u F ispre, 
  run_prepost_op u = Some (F,ispre) ->
  prepost_op u F ispre.
Proof.
  Hint Constructors prepost_op.
  introv HR. destruct u; simpls; inverts* HR.
Qed.


Axiom red_spec_object_get_own_prop : forall S C l x B (y:specret full_descriptor),
      object_method object_get_own_prop_ S l B ->
      red_spec S C (spec_object_get_own_prop_1 B l x) y ->
      red_spec S C (spec_object_get_own_prop l x) y
.
Axiom red_spec_object_get_own_prop_1_default : forall S C l x P Ao (y:specret full_descriptor), (* Beginning of steps 1 and 3 *)
      object_properties S l P -> (* TODO: combine this line and the next one using an auxiliary def *)
      Ao = Heap.read_option P x ->
      red_spec S C (spec_object_get_own_prop_2 l x Ao) y ->
      red_spec S C (spec_object_get_own_prop_1 builtin_get_own_prop_default l x) y  
.

(* TODO: move to the right place *)
Lemma run_object_get_own_prop_correct : forall runs S C l x y,
  runs_type_correct runs -> 
  run_object_get_own_prop runs S C l x = result_some y ->
  red_spec S C (spec_object_get_own_prop l x) y.
Proof.
  introv IH HR. unfolds in HR. run.
  applys* red_spec_object_get_own_prop.  
    applys* run_object_method_correct. clear E.
  let_name as M. asserts M_correct: (forall S y,
    M S = result_some y ->
    red_spec S C (spec_object_get_own_prop_1 builtin_get_own_prop_default l x) y).
    clears HR S. subst. introv HR. run.
     applys* red_spec_object_get_own_prop_1_default.
       applys* run_object_method_correct. clear E.
     destruct (Heap.read_option x1 x).
       applys* red_spec_object_get_own_prop_2_some_data.
       applys* red_spec_object_get_own_prop_2_none. 
    clear EQM.
  destruct x0.
  (* default *)
Focus 1.
  subst*.
  (* argument object *)
  skip. (*TODO*)
Admitted. (*faster*)

(*OLD
Lemma run_object_get_own_prop_correct : forall runs,
  runs_type_correct runs -> forall l,
  follow_object_get_own_prop l
    (fun S C => run_object_get_own_prop runs S C l).
Admitted. 
   introv E R. simpls. unfolds in E. unmonad_passing.
    applys_and red_spec_object_get_own_prop R0. name_passing_def.
    asserts Co: (forall K o,
        passing_output K red_expr C p0 o ->
        red_expr S C (spec_object_get_own_prop_1 builtin_get_own_prop_default l x K) o /\
          (p0 = passing_abort o -> abort o)).
      introv R1. unmonad_passing.
      applys_and red_spec_object_get_own_prop_1_default R2.
      rewrite <- E in R1. sets_eq Ao: (Heap.read_option x1 x). destruct Ao; inverts R1.
       splits. apply~ red_spec_object_get_own_prop_2_some_data. absurd_neg.
       splits. apply~ red_spec_object_get_own_prop_2_none. absurd_neg.
    destruct x0.
     inverts E0. apply* Co.
     applys_and red_spec_object_get_own_prop_args_obj. applys_and Co. clear EQp0.
      unmonad_passing. destruct x0.
       substs. inverts R. splits.
        constructors. apply~ red_spec_object_get_own_prop_args_obj_1_undef.
        absurd_neg.
       rewrite H. constructors_and. unmonad_passing.
        destruct x0; simpls; try solve [ substs; inverts R ].
        applys_and red_spec_object_get_own_prop_args_obj_1_attrs R1.
        unmonad_passing.
         applys_and RC. constructors_and. destruct x0.
          applys_and red_spec_object_get_own_prop_args_obj_2_undef.
           applys_and red_spec_object_get_own_prop_args_obj_4.
           inverts~ R; tryfalse. inverts~ H0. splits~. absurd_neg.
          unmonad_passing.
           forwards~ G: run_object_get_correct Eo. constructors~.
            applys_and red_spec_object_get_own_prop_args_obj_2_attrs G. destruct a.
             applys_and red_spec_object_get_own_prop_args_obj_3.
              applys_and red_spec_object_get_own_prop_args_obj_4.
              inverts~ R; tryfalse. splits. inverts~ H0. absurd_neg.
             subst p. inverts R.
           subst p. inverts R. symmetry in H3. rewrite H3 in H0. inverts H0.
            forwards~ G: run_object_get_correct H3. constructors~.
            applys_and red_spec_object_get_own_prop_args_obj_2_attrs G. splits~.
            apply~ red_expr_abort.
           subst p. inverts R. false* No.
         applys_and RC. rewrite H0 in R. inverts R. splits. constructors.
          forwards*: RC K. constructors.
       substs. inverts R. splits. constructors.
        forwards*: Co K. constructors.
*)


Lemma object_delete_correct : forall runs S C l x str o,
  runs_type_correct runs ->
  object_delete runs S C l x str = o ->
  red_expr S C (spec_object_delete l x str) o.
Proof.
  introv IH HR. unfolds in HR. run. rename x0 into B. 
  applys* red_spec_object_delete.
   applys* run_object_method_correct. clear E.
  destruct B; tryfalse.
  run red_spec_object_delete_1_default. destruct a.
    run_inv. applys red_spec_object_delete_2_undef. (* This rule is erroneous, the conclusion should contains [S0] instead [S]. *)
    case_if.
      run. forwards B: @pick_option_correct (rm E).
        applys_eq* red_spec_object_delete_2_some_configurable 1.
          skip. (* will go *)
          skip. (* even problem *)
          skip. (* even problem *)
          skip. (* even problem *)
      applys* red_spec_object_delete_3_some_non_configurable.
       applys* out_error_or_cst_correct.
Admitted.


Lemma env_record_delete_binding : forall runs S C L x o,
  runs_type_correct runs ->
  env_record_delete_binding runs S C L x = o ->
  red_expr S C (spec_env_record_delete_binding L x) o.
Proof.
  introv IH HR. unfolds in HR.
  run_simpl. forwards B: @pick_option_correct (rm E).
  applys~ red_spec_env_record_delete_binding B. destruct x0.
   sets_eq <- ero E: (Heap.read_option d x). destruct ero as [[mu ?]|].
    rewrite <- Heap.binds_equiv_read_option in E. destruct mu; run_inv;
     applys~ red_spec_env_record_delete_binding_1_decl_indom E; case_if*.
    rewrite <- Heap.not_indom_equiv_read_option in E. run_inv.
     applys~ red_spec_env_record_delete_binding_1_decl_not_indom E.
   applys~ red_spec_env_record_delete_binding_1_object.
    applys~ object_delete_correct HR.
Qed.



Lemma identifier_resolution_correct : forall runs S C x y,
  runs_type_correct runs ->
  identifier_resolution runs S C x = result_some y ->
  red_spec S C (spec_identifier_resolution C x) y.
Proof.
  introv IH HR. 
  unfolds spec_identifier_resolution, identifier_resolution.
  applys* lexical_env_get_identifier_ref_correct. 
Qed.

Lemma run_expr_correct : forall runs,
  runs_type_correct runs ->
   follow_expr (run_expr runs).
Proof.
  introv IH. intros S C e o R. unfolds in R.  
  destruct e as [ | | | pds | | |  | | | | | | ].
  (* this *)
  run_inv. apply~ red_expr_this.
  (* identifier *)
  run_inv. run red_expr_identifier using identifier_resolution_correct.
  applys* red_expr_identifier_1.
  (* literal *)
  run_inv. apply~ red_expr_literal.
  (* object *)
  run red_expr_object using run_construct_prealloc_correct.
  applys red_expr_object_0.
  applys* init_object_correct.
  (* function *)
  unfolds in R. destruct o0.
    let_name. destruct p as (lex'&S').
     destruct lex' as [|L lex']; simpls; tryfalse.
     run_simpl. forwards: @pick_option_correct (rm E).
     run* red_expr_function_named using env_record_create_immutable_binding_correct.
     run red_expr_function_named_1 using creating_function_object_correct.
     run red_expr_function_named_2 using env_record_initialize_immutable_binding_correct.
     apply~ red_expr_function_named_3.
    apply~ red_expr_function_unnamed. applys~ creating_function_object_correct IH.
  (* Access *)
  unfolds in R. run red_expr_access.
  run red_expr_access_1. cases_if.
    run. applys red_expr_access_2.
      applys* red_spec_check_object_coercible_undef_or_null.
      skip. (* TODO: exploiter le fait que o est un abort / changer le code si besoin*)
    applys red_expr_access_2.
      applys* red_spec_check_object_coercible_return.
     run red_expr_access_3.
     applys* red_expr_access_4.
  (* member *)
  run_hyp R. apply~ red_expr_member.
  (* new *)
  unfolds in R. run red_expr_new.
  run red_expr_new_1.
  destruct a; tryfalse.
    applys* red_expr_new_2_type_error. 
     left. applys type_of_prim_not_object. run_hyp*.
    run. lets M: run_object_method_correct (rm E).
    destruct x; tryfalse.
      applys red_expr_new_2_construct. 
       applys* red_spec_constructor.
       applys* run_construct_correct.
      applys* red_expr_new_2_type_error. run_hyp*.
  (* call *)
(*
  unfolds in R.
  Focus 1.
  let_simpl.
  run red_expr_call.
  run red_expr_call_1 using ref_get_value_correct. 
  run red_expr_call_2 using run_list_expr_correct.
  destruct a.
  applys* red_expr_call_3. left.
  destruct p; intros H; inversion H. 
  applys* run_error_correct_2.
  case_if.
  applys* red_expr_call_3.
  applys* run_error_correct_2.
  applys* red_expr_call_3_callable.
  let_name.
  asserts follows_correct: (forall vthis, follow vthis = o ->
      red_expr S3 C (expr_call_5 o0 (is_syntactic_eval e) a0 (out_ter S3 vthis)) o). 
    subst follow. clear R. introv HR. 
    case_if. subst.
    applys* red_expr_call_5_eval.
    skip. (* Need a lemma about run_eval correctness*)
    applys* red_expr_call_5_not_eval.
    apply runs_type_correct_call in HR; trivial.
    clear EQfollow.
  destruct rv; tryfalse.
  applys* red_expr_call_4_not_ref.
  assert (exists x, ref_base r = x).
     exists (ref_base r). trivial.
  destruct H. rewrite H in *.
  destruct x. 
  case_if.
  applys* red_expr_call_4_prop.
  applys* red_expr_call_4_env.
  skip. (* lemma about implicit this *)
  applys* follows_correct.
  skip.
  (* TODO *)
*)
skip.
  (* unary operators *)
  unfolds in R. case_if as N. (*todo: other branch *)
    run* red_expr_prepost. run red_expr_prepost_1_valid.
     run red_expr_prepost_2. run. destruct x as [F ispre].
     let_simpl. let_name. lets: prepost_op_correct (rm E).
     run* red_expr_prepost_3. subst. applys* red_expr_prepost_4.
    destruct u; try solve [ false n; constructors ].
    (* delete *) 
    run red_expr_delete. destruct rv; run_inv.
      applys* red_expr_delete_1_not_ref. intro; false_invert. 
      applys* red_expr_delete_1_not_ref. intro; false_invert. 
      case_if; run_inv.
        applys* red_expr_delete_1_ref_unresolvable.
         unfolds ref_is_unresolvable, ref_kind_of. 
         (* BUG in spec on  "ref_base r = null"
         sets_eq ba: (ref_base r). destruct ba.
          run red_expr_delete_1_ref_property.
          applys* red_expr_delete_1_ref_property.
           unfolds. unfold ref_kind_of. rewrite <- EQba.
           destruct v; [destruct p|]; tryfalse; eauto.
         *) (* TODO:bug if ref_base r = null: nothing applies *) skip.
    (* void *)
    run* red_expr_unary_op. applys red_expr_unary_op_1.  
     applys* red_expr_unary_op_void.
    (* typeof *)
    run red_expr_typeof. destruct rv; tryfalse.
      applys* red_expr_typeof_1_value. run_inv. applys* red_expr_typeof_2.
        applys run_typeof_value_correct.
      case_if.
        run_inv. applys* red_expr_typeof_1_ref_unresolvable.
        run* red_expr_typeof_1_ref_resolvable.
         applys* red_expr_typeof_2. 
         applys* run_typeof_value_correct.
   (* add *)
   run* red_expr_unary_op. applys red_expr_unary_op_1.  
    applys red_expr_unary_op_add. run_hyp*.
   (* neg *)
   run* red_expr_unary_op. applys red_expr_unary_op_1.  
    run red_expr_unary_op_neg. applys* red_expr_unary_op_neg_1.
   (* bitwise not *)
   run* red_expr_unary_op. applys red_expr_unary_op_1.  
    run red_expr_unary_op_bitwise_not. 
     (* TODO: spec_to_int32_correct. 
    applys* red_expr_unary_op_bitwise_not_1.*)
    skip. skip.
   (* not *)
   run* red_expr_unary_op. applys red_expr_unary_op_1.  
   forwards* M: red_spec_to_boolean a.
    applys* red_expr_unary_op_not. applys* red_expr_unary_op_not_1.
  (* binary operators *)
  skip. (* TODO : first need to fix the conversion functions *)
  (* conditionnal *)
  unfolds in R. 
  run_pre. lets (y1&R2&K): if_spec_ter_post_to_bool (rm R1) (rm R).
   applys* red_expr_conditional (rm R2). run_post_if_spec_ter_post_bool K.
  let_name. run red_expr_conditional_1. case_if in EQe; case_if*.
  applys* red_expr_conditional_2.
  (* assign *)
  unfolds in R. run red_expr_assign. let_name. rename rv into rv1.
  asserts follow_correct: (forall S0 S rv o, follow S rv = o ->
     exists v, rv = resvalue_value v /\ red_expr S0 C (expr_assign_4 rv1 (ret S v)) o). 
    subst follow. clear R. introv HR.
    destruct rv; tryfalse. exists v. split~.
    run red_expr_assign_4_put_value.
    applys* red_expr_assign_5_return.
    clear EQfollow.
  destruct o0. 
    run red_expr_assign_1_compound using ref_get_value_correct.
      run red_expr_assign_2_compound_get_value. 
        run red_expr_assign_3_compound_op using run_binary_op_correct.
        forwards (v&?&?): follow_correct (rm R). subst.
        applys* red_expr_assign_3'.
    run red_expr_assign_1_simple.
    forwards (v&?&?): follow_correct (rm R). run_inv. auto*.

Admitted. 
(* TODO: for binary op:
     (* In *)
     skip. (* TODO *)
     (* Equal *)
     skip. (* TODO *)

     (* Disequal *)
     skip. (* TODO *)
     (* Strict equal *)
     skip. (* TODO *)
     (* Strict disequal *)
     skip. (* TODO *)
     (* Bitwise and *)
     skip. (* TODO *)
     (* Bitwise or *)
     skip. (* TODO *)
     (* Bitwise xor *)
     skip. (* TODO *)
     (* And *)
     skip. (* TODO *)
     (* Or *)
     skip. (* TODO *)
     (* Comma *)
     skip. (* TODO *)
    (* conditionnal *)
    skip. (* TODO *)
    (* assign *)
    skip. (* TODO *)
*)

(* Hints for automatically applying "run_hyp" in obvious cases *) 
Hint Extern 1 (red_stat ?S ?C ?s ?o) =>
  match goal with H: _ = result_some o |- _ => run_hyp H end.
Hint Extern 1 (red_expr ?S ?C ?s ?o) =>
  match goal with H: _ = result_some o |- _ => run_hyp H end.


Lemma run_var_decl_item_correct : forall runs S C x eo o,
  runs_type_correct runs ->
  run_var_decl_item runs S C x eo = o ->
  red_stat S C (stat_var_decl_item (x,eo)) o.
Proof.
  introv IH HR. unfolds in HR. destruct eo.
  run red_stat_var_decl_item_some using identifier_resolution_correct.
   run red_stat_var_decl_item_1. run red_stat_var_decl_item_2.
   applys* red_stat_var_decl_item_3.
  run_inv. applys* red_stat_var_decl_item_none.
Qed.

Lemma run_var_decl_correct : forall runs S C ls o,
  runs_type_correct runs ->
  run_var_decl runs S C ls = o ->
  red_stat S C (stat_var_decl ls) o.
Proof.
  introv IH. gen S. induction ls as [|[x eo]]; introv HR.
  simpls. run_inv. applys* red_stat_var_decl_nil.
  simpls. run red_stat_var_decl_cons using run_var_decl_item_correct.
   applys* red_stat_var_decl_1. 
Qed.


Lemma run_stat_correct : forall runs,
  runs_type_correct runs ->
   follow_stat (run_stat runs).
Proof.
  introv RC. intros S C t o R. unfolds in R. 
  destruct t as [ | | ls | ls | e t1 t2o | labs t e | labs e t | e t 
     | e | eo | labo | labo | t co fo | | | eo | ]. 
  (* Expression *)
  run red_stat_expr. apply red_stat_expr_1. 
  (* Label *)
  unfolds in R. run red_stat_label. 
    tests HC: (res_is_normal R0).
      inverts HC. run_inv. subst. applys* red_stat_label_1_normal.
      subst. applys* red_stat_abort. intro M. inverts M. simpls. false.
    case_if.
      applys* red_stat_label_1_break_eq. destruct R0; simpls. fequal*.
      applys* red_stat_abort. constructors. intro N. inverts N. false.
       intro M. inverts M. simpls. false.
      (* LATER: change interpreter to make it more faithful *)
  (* Block *)
  skip. (* TODO : wait for changes to the rules *)
  (* Variable declaration *)
  applys* run_var_decl_correct.
  (* If *)
  unfolds in R.
  run_pre. lets (y1&R2&K): if_spec_ter_post_to_bool (rm R1) (rm R).
   applys* red_stat_if (rm R2). run_post_if_spec_ter_post_bool K.
   case_if.
     applys~ red_stat_if_1_true. apply~ RC.
     destruct t2o.
       applys~ red_stat_if_1_false.  apply~ RC.
       run_inv. applys* red_stat_if_1_false_implicit.
  (* Do-while *)
  skip. (* TODO: wait until fixed.*)
  (* While *)
  apply~ red_stat_while. applys* runs_type_correct_stat_while.
  (* With *)
  unfolds in R.
  run_pre. lets (y1&R2&K): if_spec_ter_post_to_object (rm R1) (rm R).
   applys* red_stat_with (rm R2). run_post_if_spec_ter_post_bool K.
  let_name. let_name. destruct p as [lex' S3]. let_name.
  subst lex. applys* red_stat_with_1. subst C'. run_inv. run_hyp*.
  (* Throw *)
  unfolds in R.
  run red_stat_throw. applys* red_stat_throw_1.
  (* Return *)
  unfolds in R. destruct eo.   
    run red_stat_return_some. apply* red_stat_return_1.
    inverts* R. applys red_stat_return_none.
  (* Break *)
  run_inv. applys* red_stat_break.
  (* Continue *)
  run_inv. applys* red_stat_continue.
  (* Try *)
  unfolds in R. let_name.
  asserts finally_correct: (forall S (R:res), 
      finally S R = o ->
      red_stat S C (stat_try_4 R fo) o). 
    subst finally. clear R. introv HR.
    destruct fo.
      simpls. run red_stat_try_4_finally.
       applys* red_stat_try_5_finally_result.
      run_inv. applys* red_stat_try_4_no_finally.
    clear EQfinally.
  run red_stat_try. abort.
    applys* red_stat_try_1_no_throw. 
    destruct co as [c|].
      destruct c as [x t2]. let_name. let_name.
       destruct p as [lex' S']. destruct lex'; tryfalse.
       subst lex. run* red_stat_try_1_throw_catch 
        using env_record_create_set_mutable_binding_correct.
       run red_stat_try_2_catch. 
        applys~ red_stat_try_3_catch_result finally_correct.
      applys~ red_stat_try_1_throw_no_catch. applys~ finally_correct.
      rewrite <- R. fequal. destruct R0; simpls; substs~.
  (* For-in *)
  skip. (* TODO *)
  (* For-in-var *)
  skip. (* TODO *)
  (* Debugger *)
  run_inv. apply red_stat_debugger.
  (* switch *)
  skip. (* TODO: wait for switch semantics to be double check *)
Admitted.

Lemma run_prog_correct : forall runs,
  runs_type_correct runs ->
   follow_prog (run_prog runs).
Proof.
  introv RC. intros S C p o R. unfolds in R. destruct p.
  apply~ red_prog_prog. applys~ run_elements_correct R.
Qed.

(*
Lemma run_call_correct : forall runs,
  runs_type_correct runs ->
  follow_call (run_call runs).
Proof.
   intros runs RC lthis vs S' C v o R. unfolds in R.
Admitted. (* OLD:
   intros l vs S C v S' res R. simpls. unfolds in R. unmonad.
   name_object_method. do 2 (destruct B as [B|]; tryfalse). destruct B; tryfalse.
    (* Call Default *)
    skip. (* TODO *)
    (* Call Prealloc *)
    splits.
     apply~ red_spec_call. applys run_object_method_correct EQB.
      apply~ red_spec_call_1_prealloc. unmonad.
      skip. (* TODO *)
     skip. (* TODO *)
*)
*)

Lemma run_function_has_instance_correct : forall runs,
  runs_type_correct runs ->
  follow_function_has_instance (run_function_has_instance runs).
Proof.
  intros runs IH lo S C lv o HR. unfolds in HR. run_simpl.
  forwards~ M: run_object_method_correct (rm E).
  applys~ red_spec_function_has_instance_2 M.
  destruct x as [()|lproto]; tryfalse; run_inv.
   apply~ red_spec_function_has_instance_3_null.
   cases_if; run_inv.
    apply~ red_spec_function_has_instance_3_eq.
    apply~ red_spec_function_has_instance_3_neq.
     applys~ runs_type_correct_function_has_instance HR.
Qed.

Lemma run_stat_while_correct : forall runs,
  runs_type_correct runs ->
  follow_stat_while (run_stat_while runs).
Proof.
  intros runs IH ls e t S C rv o R. unfolds in R.
  run_pre. lets (y1&R2&K): if_spec_ter_post_to_bool (rm R1) (rm R).
   applys~ red_stat_while_1 (rm R2). run_post_if_spec_ter_post_bool K.
    case_if.
    run red_stat_while_2_true.
     let_name. let_simpl. applys red_stat_while_3 rv'. case_if; case_if*.
     case_if in K.
       applys red_stat_while_4_not_continue. rew_logic*. case_if in K.
         run_inv. applys* red_stat_while_5_break.
         applys* red_stat_while_5_not_break. case_if in K; run_inv.
           applys* red_stat_while_6_abort.
           applys* red_stat_while_6_normal. run_hyp*.
       rew_logic in *. applys* red_stat_while_4_continue. run_hyp*.
   run_inv. applys red_stat_while_2_false.
Admitted. (*faster*)

Lemma run_stat_do_while_correct : forall runs,
  runs_type_correct runs ->
  follow_stat_do_while (run_stat_do_while runs).
Proof.
  intros runs IH ls e t S C rv o R. unfolds in R.
  run red_stat_do_while_1. do 2 let_name.
  applys~ red_stat_do_while_2 rv'.
    repeat cases_if~. clear EQrv'.
  asserts loop_correct: (forall o, loop tt = o ->
      red_stat S0 C (stat_do_while_6 ls t e rv') o).
    clear R. introv H. subst loop.
     run_pre. lets (y1&R2&K): if_spec_ter_post_to_bool (rm R1) (rm H).
     applys~ red_stat_do_while_6 (rm R2). run_post_if_spec_ter_post_bool K.
     cases_if.
      apply~ red_stat_do_while_7_true. apply* IH.
      run_inv. apply* red_stat_do_while_7_false.
  clear EQloop. cases_if in R.
   apply~ red_stat_do_while_3_continue. rewrite decide_def in H. cases_if~ in H.
   apply~ red_stat_do_while_3_not_continue.
     rewrite decide_def in H. cases_if~ in H. clear H. cases_if.
    run_inv. apply~ red_stat_do_while_4_break.
    apply~ red_stat_do_while_4_not_break. cases_if; run_inv.
     apply~ red_stat_do_while_5_abort.
     apply~ red_stat_do_while_5_normal.
Qed.

Lemma object_proto_is_prototype_of_correct : forall runs,
  runs_type_correct runs ->
  follow_object_proto_is_prototype_of
    (object_proto_is_prototype_of runs).
Admitted.

Lemma run_equal_correct : forall runs,
  runs_type_correct runs ->
  follow_equal (run_equal runs).
Admitted.


Theorem runs_correct : forall num,
  runs_type_correct (runs num).
Proof.
  induction num.
   constructors; try solve [unfolds~ (* Temporary, to remove [True] properties *)];
     introv H; inverts H; introv P; inverts P.
   (* lets [IHe IHs IHp IHc IHhi IHw IHowp IHop IHpo IHeq]: (rm IHnum). *)
   constructors.
     apply~ run_expr_correct.
     apply~ run_stat_correct.
     apply~ run_prog_correct.
     skip. (* apply~ run_call_correct.*)
     apply~ run_function_has_instance_correct.
     apply~ run_stat_while_correct.
     apply~ run_stat_do_while_correct.
     skip. (* TODO:  Use run_object_get_own_prop_correct *)
     skip. (* Todo:  Use run_object_get_prop_correct. *)
     apply~ object_proto_is_prototype_of_correct.
     apply~ run_equal_correct.
Qed.

Theorem run_javascript_correct : forall runs p o,
  runs_type_correct runs ->
  run_javascript runs p = o ->
  red_javascript p o.
Proof.
  introv IH HR. unfolds in HR. run_pre as o1 R1.
(*
  forwards R: execution_ctx_binding_inst_correct IH (rm R1). (* Need more information there:  it should return a result_void. *)
*)
skip.
  (* applys~ red_javascript_intro R. *)
Admitted.


