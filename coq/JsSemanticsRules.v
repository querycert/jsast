Require Import JsSemanticsDefs.

(**************************************************************)
(** ** Implicit Types, same as in JsSemanticsDefs *)

Implicit Type b : bool.
Implicit Type n : number.
Implicit Type s : string.
Implicit Type i : literal.
Implicit Type l : object_loc.
Implicit Type w : prim.
Implicit Type v : value.
Implicit Type r : ref.
Implicit Type T : type.

Implicit Type x : prop_name.
Implicit Type m : mutability. 
Implicit Type A : prop_attributes.
Implicit Type An : prop_descriptor.
Implicit Type L : env_loc. 
Implicit Type E : env_record. 
Implicit Type D : decl_env_record.
Implicit Type X : lexical_env. 
Implicit Type O : object.
Implicit Type S : state.
Implicit Type C : execution_ctx.
Implicit Type P : object_properties_type.

Implicit Type e : expr.
Implicit Type p : prog.
Implicit Type t : stat.


(* added *)
Implicit Type re : res.
Implicit Type rt : ret.
Implicit Type o : out.


(**************************************************************)
(**************************************************************)
(**************************************************************)
(** ** TODO *)

Parameter alloc_primitive_value :
  state -> value -> state -> object_loc -> Prop.
Parameter basic_value_convertible_to_object : value -> Prop.



(**************************************************************)
(** ** Reduction rules for programs *)

Inductive red_prog : state -> execution_ctx -> ext_prog -> out -> Prop :=

  (** Generic abort rule *)

  | red_prog_abort : forall S C p o,
      out_of_ext_prog p = Some o ->
      abort o ->
      red_prog S C p o

  (** Statements *)

  | red_prog_stat : forall S C t o,
      red_stat S C t o ->
      red_prog S C (prog_stat t) o

  (** Sequence *)

  | red_prog_seq : forall S C p1 p2 o1 o,
      red_prog S C p1 o1 ->
      red_prog S C (prog_seq_1 o1 p2) o ->
      red_prog S C (prog_seq p1 p2) o

  | red_prog_seq_1 : forall S0 S re C p2 o,
      red_prog S C p2 o ->
      red_prog S C (prog_seq_1 (out_ter S re) p2) o

  (* TODO: red_prog_function_decl ? *)


(**************************************************************)
(** ** Reduction rules for statements *)

with red_stat : state -> execution_ctx -> ext_stat -> out -> Prop :=

  (** Generic abort rule *)

  | red_stat_abort : forall S C text o,
      out_of_ext_stat text = Some o ->
      ~ abort_intercepted text o ->
      abort o ->
      red_stat S C text o

  (** Expression *)

  | red_stat_expr : forall S C e o,
      red_expr S C (spec_expr_get_value e) o ->
      red_stat S C (stat_expr e) o

  (** Sequence *)

  | red_stat_seq : forall S C t1 t2 o1 o,
      red_stat S C t1 o1 ->
      red_stat S C (stat_seq_1 o1 t2) o ->
      red_stat S C (stat_seq t1 t2) o

  | red_stat_seq_1 : forall S0 S r C t2 o,
      red_stat S C (stat_basic t2) o ->
      red_stat S0 C (stat_seq_1 (out_ter S r) t2) o

  (** Variable declaration *)

  | red_stat_var_decl_none : forall S C x,
      red_stat S C (stat_var_decl x None) (out_ter S undef)

    (* TODO: red_stat_var_decl_some: can we justify that this is equivalent to the spec ?*)
  | red_stat_var_decl_some : forall S C x e o1 o,
      red_expr S C (expr_assign (expr_variable x) None e) o1 ->
      red_stat S C (stat_var_decl_1 o1) o ->
      red_stat S C (stat_var_decl x (Some e)) o

  | red_stat_var_decl_1 : forall S0 S r1 C,
      red_stat S0 C (stat_var_decl_1 (out_ter S r1)) (out_ter S undef)

  (** If statement *)

  | red_stat_if : forall S C e1 t2 t3opt o,
      red_stat S C (spec_expr_get_value_conv e1 spec_to_boolean (fun v => stat_if_1 v t2 t3opt)) o ->
      red_stat S C (stat_if e1 t2 t3opt) o

  | red_stat_if_1_true : forall S C t2 t3opt o,
      red_stat S C t2 o ->
      red_stat S C (stat_if_1 true t2 t3opt) o

  | red_stat_if_1_false : forall S C t2 t3 o,
      red_stat S C t3 o ->
      red_stat S C (stat_if_1 false t2 (Some t3)) o

  | red_stat_if_1_false_implicit : forall S C t2,
      red_stat S C (stat_if_1 false t2 None) (out_ter S undef) 

  (** While statement *)

  | red_stat_while : forall S C e1 t2 o o1,
      red_stat S C (spec_expr_get_value_conv e1 spec_to_boolean (stat_while_1 e1 t2)) o ->
      red_stat S C (stat_while e1 t2) o

  | red_stat_while_1_false : forall S C e1 t2,
      red_stat S C (stat_while_1 e1 t2 false) (out_ter S undef)

  | red_stat_while_1_true : forall S0 S C e1 t2 o o1,
      red_stat S C t2 o1 ->
      red_stat S C (stat_while_2 e1 t2 o1) o ->
      red_stat S0 C (stat_while_1 e1 t2 true) o

  | red_stat_while_2 : forall S0 S C e1 t2 re o,
      red_stat S C (stat_while e1 t2) o ->
      red_stat S0 C (stat_while_2 e1 t2 (out_ter S re)) o
    (* TODO: handle break and continue in while loops *)
    
  (** For-in statement *)
  
  | red_stat_for_in_1 : forall o1 S C e1 e2 t o,
      red_expr S C e2 o1 ->
      red_stat S C (stat_for_in_1 e1 t o1) o ->
      red_stat S C (stat_for_in e1 e2 t) o
      
  | red_stat_for_in_2 : forall o1 S0 S C e1 t exprRef o,
      red_expr S C (spec_ref_get_value exprRef) o1 ->
      red_stat S C (stat_for_in_2 e1 t o1) o ->
      red_stat S0 C (stat_for_in_1 e1 t (out_ter S exprRef)) o
      
  | red_stat_for_in_3_null_undef : forall S0 S C e1 t exprValue o,
      exprValue = null \/ exprValue = undef ->
      red_stat S0 C (stat_for_in_2 e1 t (out_ter S exprValue)) (out_void S)
      
  | red_stat_for_in_4 : forall o1 S0 S C e1 t exprValue o,
      exprValue <> null /\ exprValue <> undef ->
      red_expr S C (spec_to_object exprValue) o1 ->
      red_stat S C (stat_for_in_3 e1 t o1) o ->
      red_stat S0 C (stat_for_in_2 e1 t (out_ter S exprValue)) o  
      
  | red_stat_for_in_6a_start : forall S0 S C e1 t l initProps o,
      object_all_enumerable_properties S (value_object l) initProps ->
      red_stat S C (stat_for_in_4 e1 t l None None initProps (@empty_impl prop_name)) o ->
      red_stat S0 C (stat_for_in_3 e1 t (out_ter S l)) o

  | red_stat_for_in_6a_done : forall S C e1 t l vret lhsRef initProps visitedProps currentProps,
      object_all_enumerable_properties S (value_object l) currentProps ->
      incl_impl currentProps visitedProps ->
      red_stat S C (stat_for_in_4 e1 t l (Some vret) lhsRef initProps visitedProps) (out_ter S vret)

  (* allow possibility to skip new added property in for-in loop *)
  | red_stat_for_in_6a_skip_added_property : forall S C e1 t l vret lhsRef initProps visitedProps currentProps x o,
      object_all_enumerable_properties S (value_object l) currentProps ->
      in_impl x (remove_impl (remove_impl currentProps visitedProps) initProps) ->
      let newVisitedProps := union_impl (single_impl x) visitedProps in
      red_stat S C (stat_for_in_4 e1 t l vret lhsRef initProps newVisitedProps) o ->
      red_stat S C (stat_for_in_4 e1 t l vret lhsRef initProps visitedProps) o

  | red_stat_for_in_6a_select_x : forall S C e1 t l vret lhsRef initProps visitedProps currentProps x o,
      object_all_enumerable_properties S (value_object l) currentProps ->
      in_impl x (remove_impl currentProps visitedProps) ->
      let newVisitedProps := union_impl (single_impl x) visitedProps in
      red_stat S C (stat_for_in_5 e1 t l vret lhsRef initProps newVisitedProps x) o ->
      red_stat S C (stat_for_in_4 e1 t l vret lhsRef initProps visitedProps) o
      
  (* evaluate new lhdRef *)
  | red_stat_for_in_6b_evaluate : forall S C e1 t l vret lhdRef initProps visitedProps x o1 o,
      red_expr S C e1 o1 ->
      red_stat S C (stat_for_in_6 e1 t l vret (Some o1) initProps visitedProps x) o ->
      red_stat S C (stat_for_in_5 e1 t l vret lhdRef initProps visitedProps x) o

  (* reuse earlier lhdRef *)
  | red_stat_for_in_6b_reuse_old : forall S C e1 t l vret lhdRef initProps visitedProps x o,
      red_stat S C (stat_for_in_6 e1 t l vret (Some lhdRef) initProps visitedProps x) o ->
      red_stat S C (stat_for_in_5 e1 t l vret (Some lhdRef) initProps visitedProps x) o

  | red_stat_for_in_6c : forall S0 S C e1 t l vret lhdRef initProps visitedProps x o1 o,
      red_expr S C (spec_ref_put_value lhdRef x) o1 ->
      red_stat S C (stat_for_in_7 e1 t l vret (Some (out_ter S lhdRef)) initProps visitedProps o1) o ->
      red_stat S0 C (stat_for_in_6 e1 t l vret (Some (out_ter S lhdRef)) initProps visitedProps x) o

  | red_stat_for_in_6d : forall S0 S C e1 t l vret lhdRef initProps visitedProps o1 o,
      red_stat S C t o1 ->
      red_stat S C (stat_for_in_8 e1 t l vret lhdRef initProps visitedProps o1) o ->
      red_stat S0 C (stat_for_in_7 e1 t l vret lhdRef initProps visitedProps (out_void S)) o

  | red_stat_for_in_6e : forall S0 S C e1 t l vret lhdRef initProps visitedProps res o,
      let vnew := match res with
        | res_normal ret => Some ret
        | _ => vret end
      in 
      red_stat S C (stat_for_in_9 e1 t l vnew lhdRef initProps visitedProps res) o ->
      red_stat S0 C (stat_for_in_8 e1 t l vret lhdRef initProps visitedProps (out_ter S res)) o

  | red_stat_for_in_6f_break : forall S C e1 t l vret lhdRef initProps visitedProps label,
      (* TODO: check break label is in current label set *)
      red_stat S C (stat_for_in_9 e1 t l (Some vret) lhdRef initProps visitedProps (res_break label)) (out_ter S vret)

  | red_stat_for_in_6g_exit : forall S C e1 t l vret lhdRef initProps visitedProps res,
      (* TODO: check continue label is in current label set *)
      ~ (is_res_break res) /\ ~ (is_res_continue res) /\ ~ (is_res_normal res) ->
      red_stat S C (stat_for_in_9 e1 t l vret lhdRef initProps visitedProps res) (out_ter S res)

  | red_stat_for_in_6g_continue : forall o1 S C e1 t l vret lhdRef initProps visitedProps res o,
     (* TODO: check continue label is in current label set *)
      ~ (is_res_break res) /\ ((is_res_continue res) \/ (is_res_normal res)) ->
      red_stat S C (stat_for_in_4 e1 t l vret lhdRef initProps visitedProps) o ->
      red_stat S C (stat_for_in_9 e1 t l vret lhdRef initProps visitedProps res) o  

  (** With statement *)

  | red_stat_with : forall S C e1 t2 o,
      red_stat S C (spec_expr_get_value_conv e1 spec_to_object (stat_with_1 t2)) o ->
      red_stat S C (stat_with e1 t2) o

  | red_stat_with_1 : forall S S' C t2 l o lex lex' s' C',
      lex = execution_ctx_lexical_env C ->
      (lex',S') = lexical_env_alloc_object S lex l provide_this_true ->
      C' = execution_ctx_with_lex_this C lex' l ->
      red_stat S' C' t2 o ->
      red_stat S C (stat_with_1 t2 l) o

  (** TODO:  Rules for the return,  break and continue statements *)

 (** Throw statement *)

  | red_stat_throw : forall S C e o o1,
      red_expr S C (spec_expr_get_value e) o1 ->
      red_stat S C (stat_throw_1 o1) o ->
      red_stat S C (stat_throw e) o
  
  | red_stat_throw_1 : forall S0 S C v,
      red_stat S0 C (stat_throw_1 (out_ter S v)) (out_ter S (res_throw v))

  (** Try statement *)

  | red_stat_try : forall S C t co fio o o1, (* TODO: rename co and fio *)
      red_stat S C t o1 ->
      red_stat S C (stat_try_1 o1 co fio) o ->
      red_stat S C (stat_try t co fio) o

  | red_stat_try_1_no_catch : forall S0 S C re fio o,
      red_stat S0 C (stat_try_3 (out_ter S re) fio) o ->
      red_stat S0 C (stat_try_1 (out_ter S re) None fio) o

  | red_stat_try_1_catch_no_throw : forall S0 S C re x t1 fio o,
      ~ is_res_throw re ->
      red_stat S0 C (stat_try_3 (out_ter S re) fio) o ->
      red_stat S0 C (stat_try_1 (out_ter S re) (Some (x,t1)) fio) o

  | red_stat_try_1_catch_throw : forall S0 S S' C lex lex' oldlex L x v t1 fio o1 o,
      lex = execution_ctx_lexical_env C ->
      (lex',S') = lexical_env_alloc_decl S lex ->
      lex' = L::oldlex -> (* Note: oldlex in fact equal to lex *)
      (* TODO: we would be closer to the spec in red_stat_try_1_catch_throw
         if lexical environments were not lists, but instead objects with a parent field *)
      red_expr S' C (spec_env_record_create_set_mutable_binding L x None v throw_irrelevant) o1 ->
      red_stat S' C (stat_try_2 o1 lex' t1 fio) o -> 
      red_stat S0 C (stat_try_1 (out_ter S (res_throw v)) (Some (x,t1)) fio) o 

  | red_stat_try_2_after_catch_throw : forall C C' S0 S lex' t1 fio o o1,
      C' = execution_ctx_with_lex C lex' ->
      red_stat S C' t1 o1 ->
      red_stat S C' (stat_try_3 o1 fio) o ->
      red_stat S0 C (stat_try_2 (out_void S) lex' t1 fio) o

  | red_stat_try_3_no_finally : forall S C o,
      red_stat S C (stat_try_3 o None) o

  | red_stat_try_3_finally : forall S0 S1 C t1 re o o1,
      red_stat S1 C t1 o1 ->
      red_stat S1 C (stat_try_4 re o1) o ->
      red_stat S0 C (stat_try_3 (out_ter S1 re) (Some t1)) o

  | red_stat_try_4_after_finally : forall S0 S C re rt,
      red_stat S0 C (stat_try_4 re (out_ter S (res_normal rt))) (out_ter S re)

  (** Skip statement *)

  | red_stat_skip : forall S C,
      red_stat S C stat_skip (out_ter S undef)

  (* Auxiliary forms *)

  | red_spec_expr_get_value_conv : forall S C r e sc K o o1, 
      red_expr S C (spec_expr_get_value e) o1 ->
      red_stat S C (spec_expr_get_value_conv_1 o1 sc K) o ->
      red_stat S C (spec_expr_get_value_conv e sc K) o

  | red_spec_expr_get_value_conv_1 : forall S0 S C sc K v o o1,
      red_expr S C (sc v) o1 ->
      red_stat S C (spec_expr_get_value_conv_2 o1 K) o ->
      red_stat S0 C (spec_expr_get_value_conv_1 (out_ter S v) sc K) o

  | red_spec_expr_get_value_conv_2 : forall S0 S C K v o,
      red_stat S C (K v) o ->
      red_stat S0 C (spec_expr_get_value_conv_2 (out_ter S v) K) o


(**************************************************************)
(** ** Reduction rules for expressions *)

with red_expr : state -> execution_ctx -> ext_expr -> out -> Prop :=

  (** Generic abort rule *)

  | red_expr_abort : forall S C eext o,
      out_of_ext_expr eext = Some o ->
      abort o ->
      red_expr S C eext o
  
  (** Reduction of lists of expressions *)

  | red_expr_list_then : forall S C K es o,
      red_expr S C (expr_list_then_1 K nil es) o ->
      red_expr S C (expr_list_then K es) o

  | red_expr_list_then_1_nil : forall S C K vs o,
      red_expr S C (K vs) o ->
      red_expr S C (expr_list_then_1 K vs nil) o

  | red_expr_list_then_1_cons : forall S C K vs es e o o1,
      red_expr S C (spec_expr_get_value e) o1 ->
      red_expr S C (expr_list_then_2 K vs o1 es) o ->
      red_expr S C (expr_list_then_1 K vs (e::es)) o

  | red_expr_list_then_2 : forall S0 S C k r v vs es o,
      red_expr S C (expr_list_then_1 k (vs&v) es) o ->
      red_expr S0 C (expr_list_then_2 k vs (out_ter S v) es) o

  (** This construct *)

  | red_expr_this : forall S C v,
      v = execution_ctx_this_binding C ->
      red_expr S C expr_this (out_ter S v)

  (** Identifier *)

  | red_expr_variable : forall S C x o,  
      red_expr S C (identifier_resolution C x) o -> 
      red_expr S C (expr_variable x) o

  (** Literal *)

  | red_expr_literal : forall S C s i v,
      v = convert_literal_to_prim i ->
      red_expr S C (expr_literal i) (out_ter S v)

(*----- TOCLEAN

  (** Array initializer [TODO] *)

  (** Object initializer *)

  (*| red_expr_object : forall S0 S1 C l lx le lxe o,
      object_fresh S0 l ->
      S1 = alloc_obj S0 l loc_obj_proto ->
      (lx,le) = LibList.split lxe ->
      red_expr S1 C (expr_list_then (expr_object_1 l lx) le) o ->
      red_expr S0 C (expr_object lxe) o *)

  (*| red_expr_object_1 : forall S0 S1 C l lx lv lfv,
      Forall3 (fun x v xv => xv = (field_normal x,v)) lx lv lfv ->
      S1 = write_fields S0 l lfv ->
      red_expr S0 C (expr_object_1 l lx lv) (out_ter S1 l) *)

  (** Function declaration [TODO] *)

  (*| red_expr_function_unnamed : forall l l' S0 S1 S2 C lx P,
      object_fresh S0 l ->
      S1 = alloc_obj S0 l loc_obj_proto ->
      object_fresh S1 l' ->
      S2 = alloc_fun S1 l' s lx P l ->
      red_expr S0 C (expr_function None lx P) (out_ter S2 l') *)

  (*| red_expr_function_named : forall l l' l1 S0 S1 S2 S3 S4 C y lx P,
      object_fresh S0 l ->
      S1 = alloc_obj S0 l loc_obj_proto ->
      object_fresh S1 l1 ->
      S2 = alloc_obj S1 l1 loc_obj_proto ->
      object_fresh S2 l' ->
      S3 = alloc_fun S2 l' (l1::s) lx P l ->
      S4 = write S3 l1 (field_normal y) (value_loc l') ->
      red_expr S0 C (expr_function (Some y) lx P) (out_ter S4 l') *)

  (** Access *)

  | red_expr_access : forall S0 C e1 e2 o o1,
      red_expr S0 C e1 o1 ->
      red_expr S0 C (expr_access_1 o1 e2) o ->
      red_expr S0 C (expr_access e1 e2) o

  (*| red_expr_access_1 : forall S0 S1 C o o2 e2 v1 r l,
      getvalue S1 r v1 ->
      red_expr S1 C e2 o2 ->
      red_expr S1 C (expr_access_2 v1 o2) o ->
      red_expr S0 C (expr_access_1 (out_ter S1 r) e2) o*)

  (*| red_expr_access_2 : forall S0 S1 C r v1 v2 o,
      getvalue S1 r v2 ->
      red_expr S1 C (spec_convert_twice (spec_to_object v1) (spec_to_string v2) expr_access_3) o ->
      red_expr S0 C (expr_access_2 v1 (out_ter S1 r)) o*)

  (*| red_expr_ext_expr_access_3 :
     v1 = value_loc l ->  (* todo: generalize when references can take value as first argument *)
     x = convert_prim_to_string v2 ->
     red_expr S C (expr_access_3 v1 v2) (out_ter S (Ref l x))*)

  (** Member *)

  | red_expr_member : forall x S0 C e1 o,
      red_expr S0 C (expr_access e1 (expr_literal (literal_string x))) o ->
      red_expr S0 C (expr_member e1 x) o

  (** New *)

  (* todo : add exceptions and conversions for new and call *)

  | red_expr_new : forall S0 C e1 le2 o o1,
      red_expr S0 C (expr_basic e1) o1 -> 
      red_expr S0 C (expr_new_1 o1 le2) o ->
      red_expr S0 C (expr_new e1 le2) o


  (* Daniele: we need to throw a 'TypeError' if l1 doesn't have type Object,
     and if it doesn't implement internal method ((Construct)) - ? *)
  (* Martin:  Do you then think that we should define a new extended expression
     ext_expr_new_<something> to just do the getvalue step and then match on
     its result?  I think it would be closer to the `great step' guidelines. *)
  (*| red_expr_ext_expr_new_1 : forall S0 S1 C l1 l2 s3 lx P3 le2 r1 v1 o,
      getvalue S1 r1 l1 ->
      l1 <> loc_null -> (* Martin:  This condition seems to be yielded by the next three. *)
        (* Arthur: agreed, we should be able to remove it;
           maybe it was there to insist on the fact that "new null" should raise an exn *)
      binds S1 l1 field_scope (value_scope s3) ->
      binds S1 l1 field_body (value_body lx P3) ->
      binds S1 l1 field_normal_prototype v1 ->
      l2 = obj_or_glob_of_value v1 ->
      red_expr S1 C (expr_list_then (expr_new_2 l2 (normal_body s3 lx P3)) le2) o ->
      red_expr S0 C (expr_new_1 (out_ter S1 r1) le2) o*)

  (*| red_expr_ext_expr_new_2 : forall S0 S1 S2 S3 S4 S5 C s3 l2 l3 l4 lx vs lfv ys P3 o1 o,
      object_fresh S0 l3 ->
      S1 = alloc_obj S0 l3 l2 ->
      object_fresh S1 l4 ->
      S2 = write_proto S1 l4 loc_null ->
      S3 = write S2 l4 field_this l3 ->
      arguments lx vs lfv ->
      S4 = write_fields S3 l4 lfv ->
      ys = defs_prog lx P3 ->
      S5 = reserve_local_vars S4 l4 ys ->
      red_expr S5 (l4::s3) (ext_expr_prog P3) o1 ->
      red_expr S5 C (expr_new_3 l3 o1) o ->
      red_expr S0 C (expr_new_2 l2 (normal_body s3 lx P3) vs) o*)

  (*| red_expr_ext_expr_new_3 : forall S0 S1 C r v l l0,
      getvalue S1 r v ->
      l = obj_of_value v l0 ->
      red_expr S0 C (expr_new_3 l0 (out_ter S1 r)) (out_ter S1 l)*)


  (** Call *)

(*
  | red_expr_call : forall S0 C e1 e2s o1 o2,
      red_expr S0 C (expr_basic e1) o1 ->
      red_expr S0 C (expr_call_1 o1 e2s) o2 ->
      red_expr S0 C (expr_call e1 e2s) o2
*)
  (*| red_expr_call_1 : forall S0 S1 C l1 l2 o r1 e2s,
      getvalue S1 r1 l1 ->
      l2 = get_this S1 r1 ->
      red_expr S1 C (expr_call_2 l1 l2 e2s) o ->
      red_expr S0 C (expr_call_1 (out_ter S1 r1) e2s) o*)

  (*| red_expr_call_2 : forall S0 C l1 l2 s3 P3 xs e2s o,
      l1 <> loc_eval ->
      binds S0 l1 field_scope (value_scope s3) ->
      binds S0 l1 field_body (value_body xs P3) ->
      red_expr S0 C (expr_list_then (expr_call_3 l2 (normal_body s3 xs P3)) e2s) o ->
      red_expr S0 C (expr_call_2 l1 l2 e2s) o*)

  | red_expr_call_2_eval : forall S0 C e2s l2 o,
      red_expr S0 C (expr_list_then (expr_call_3 l2 primitive_eval) e2s) o ->
      red_expr S0 C (expr_call_2 loc_eval l2 e2s) o

  (*| red_expr_call_3 : forall S0 S1 S2 S3 S4 l0 l1 o3 o ys vs xs fvs C s3 P3,
      ys = defs_prog xs P3 ->
      object_fresh S0 l1 ->
      S1 = alloc_obj S0 l1 loc_null ->
      S2 = write S1 l1 field_this l0 ->
      arguments xs vs fvs ->
      S3 = write_fields S2 l1 fvs ->
      S4 = reserve_local_vars S3 l1 ys ->
      red_expr S4 (l1::s3) (ext_expr_prog P3) o3 ->
      red_expr S4 C (expr_call_4 o3) o ->
      red_expr S0 C (expr_call_3 l0 (normal_body s3 xs P3) vs) o*)

  (*| red_expr_call_3_eval : forall S0 C vs g e3 l0 o o3,
      parse g e3 ->
      red_expr S0 C e3 o3 ->
      red_expr S0 C (expr_call_4 o3) o ->
      red_expr S0 C (expr_call_3 l0 primitive_eval (g::vs)) o*)

  (*| red_expr_call_4 : forall S0 S1 C r v,
      getvalue S1 r v ->
      red_expr S0 C (expr_call_4 (out_ter S1 r)) (out_ter S1 v)*)


  (** Unary op *)

  | red_expr_unary_op : forall S0 C op e o1 o,
      red_expr S0 C (expr_basic e) o1 ->
      red_expr S0 C (expr_unary_op_1 op o1) o ->
      red_expr S0 C (expr_unary_op op e) o

  (*| red_expr_unary_op_1 : forall S0 S1 C op r1 v1 v,
      getvalue S1 r1 v1 ->
      unary_op_red op S1 v1 v ->
      red_expr S0 C (expr_unary_op_1 op (out_ter S1 r1)) (out_ter S1 v)*)

  | red_expr_unary_op_2_void_1 : forall S C v,
      red_expr S C (expr_unary_op_2 unary_op_void v) (out_ter S undef)

  (*| red_expr_unary_op_2_void_2 : forall S C op v,
      red_expr S C (expr_unary_op_2 unary_op_not v) (out_ter S (prim_bool (neg (convert_prim_to_boolean v))))*)
  
  (*| red_expr_unary_op_1_typeof_value : forall S0 S1 C r v str,
      getvalue S1 r v ->
      typeof_red S1 v str ->
      red_expr S0 C (expr_unary_op_1 unary_op_typeof (out_ter S1 r)) (out_ter S1 str)*)


   (* ---todo merge::
   typeof_prim

  | typeof_red_function : forall S l,
      indom_scope_or_body S l -> 
      (* TODO: change to test [binds S l O] /\ [object_function O <> None],
         which should be named as a predicate [is_function S l] *)
      typeof_red S (value_loc l) "function"

  | typeof_red_object : forall S l,
      ~ indom_scope_or_body S l ->
        (* TODO: change to test [binds S l O] /\ [object_function O = None],
           which should be named as a predicate [is_not_function S l] *)
      typeof_red S (value_loc l) "object"
      *).




  (*| red_expr_unary_op_1_typeof_undef : forall S0 S1 s x,
      red_expr S0 C (expr_unary_op_1 unary_op_typeof (out_ter S1 (Ref loc_null x))) (out_ter S1 (prim_string "undefined"))*)

  (* todo: handle ++ and -- pre and post *)
  (* Martin:  You mean the errors they can throw if they are not given a reference? *)

  (*| red_expr_unary_op_1_pre_incr : forall S0 S1 S2 s l x v va,
      getvalue S1 (Ref l x) v ->
      binary_op_red binary_op_add S1 (number_of_int 1) v va ->
      S2 = update S1 l x va ->
      red_expr S0 C (expr_unary_op_1 unary_op_pre_incr (out_ter S1 (Ref l x))) (out_ter S2 va)*)

  (*| red_expr_unary_op_1_pre_decr : forall S0 S1 S2 s l x v va,
      getvalue S1 (Ref l x) v ->
      binary_op_red binary_op_add S1 (number_of_int (-1)%Z) v va ->
      S2 = update S1 l x va ->
      red_expr S0 C (expr_unary_op_1 unary_op_pre_decr (out_ter S1 (Ref l x))) (out_ter S2 va)*)
 
  (*| red_expr_unary_op_1_post_incr : forall S0 S1 S2 s l x v va,
      getvalue S1 (Ref l x) v ->
      binary_op_red binary_op_add S1 (number_of_int 1) v va ->
      S2 = update S1 l x va ->
      red_expr S0 C (expr_unary_op_1 unary_op_post_incr (out_ter S1 (Ref l x))) (out_ter S2 v)*)
  
  (*| red_expr_unary_op_1_post_decr : forall S0 S1 S2 s l x v va,
      getvalue S1 (Ref l x) v ->
      binary_op_red binary_op_add S1 (number_of_int (-1)%Z) v va ->
      S2 = update S1 l x va ->
      red_expr S0 C (expr_unary_op_1 unary_op_post_decr (out_ter S1 (Ref l x))) (out_ter S2 v)*)

  (*| red_expr_unary_op_1_delete_true : forall S0 S1 S2 C r,
      ~ dont_delete r ->
      S2 = dealloc S1 r ->
      (* LATER: will raise an exception if r is loc_null *)
      red_expr S0 C (expr_unary_op_1 unary_op_delete (out_ter S1 r)) (out_ter S2 (prim_bool true))*)

  (*| red_expr_unary_op_1_delete_false : forall S0 S1 C r,
      dont_delete r ->
      red_expr S0 C (expr_unary_op_1 unary_op_delete (out_ter S1 r)) (out_ter S1 (prim_bool false))*)


  (** Binary op *)

  | red_expr_binary_op : forall S0 C op e1 e2 o o1,
      red_expr S0 C (expr_basic e1) o1 ->
      red_expr S0 C (expr_binary_op_1 o1 op e2) o ->
      red_expr S0 C (expr_binary_op e1 op e2) o

  (*| red_expr_binary_op_1 : forall S0 S1 C op r1 v1 e2 o,
      getvalue S1 r1 v1 ->
      red_expr S1 C (expr_binary_op_2 v1 op e2) o ->
      red_expr S0 C (expr_binary_op_1 (out_ter S1 r1) op e2) o*)

  (*| red_expr_binary_op_2_general : forall S C v1 op e2 o,
      (op = binary_op_and -> convert_prim_to_boolean v1 <> false) ->
      (op = binary_op_or -> convert_prim_to_boolean v1 <> true) ->
      red_expr S C (expr_binary_op_3 v1 op e2) o ->
      red_expr S C (expr_binary_op_2 v1 op e2) o *)

  (*| red_expr_binary_op_2_and_false : forall S C v1 e2 o,
      convert_prim_to_boolean v1 = value_bool false ->
      red_expr S C (expr_binary_op_2 v1 binary_op_and e2) (Some (out_ter S v1))*)

  (*| red_expr_binary_op_2_or_true : forall S C v1 e2 o,
      convert_prim_to_boolean v1 = value_bool true ->
      red_expr S C (expr_binary_op_2 v1 binary_op_and e2) (Some (out_ter S v1))*)

  | red_expr_binary_op_3 : forall S C op e2 v1 o o2,
      red_expr S C e2 o2 ->
      red_expr S C (expr_binary_op_4 v1 op o2) o ->
      red_expr S C (expr_binary_op_3 v1 op e2) o

  (*| red_expr_binary_op_4 : forall S0 S1 C op r v1 v2 o,
      getvalue S1 r v2 ->
      red_expr S1 C (expr_binary_op_5 v1 op v2) o ->
      red_expr S0 C (expr_binary_op_4 v1 op (out_ter S1 r)) o*)

  (* todo: could factorize the next two rules *)

  | red_expr_binary_op_5_and : forall S C v1 v2,
      (* not needed: convert_prim_to_boolean v1 = value_bool true -> *)
      red_expr S C (expr_binary_op_5 v1 binary_op_and v2) (out_ter S v2)

  | red_expr_binary_op_5_or : forall S C v1 v2,
      (* not needed: convert_prim_to_boolean v1 = value_bool false -> *)
      red_expr S C (expr_binary_op_5 v1 binary_op_or v2) (out_ter S v2)

  | red_expr_binary_op_5_instanceof_basic : forall S C v1 v2,
      red_expr S C (expr_binary_op_5 (value_prim v1) binary_op_instanceof v2) (out_type_error S)

  (*| red_expr_binary_op_5_instanceof_object : forall S C l v2 v o,
      (* later: test hasInstance *)
      instanceof_red S l v2 v ->
      red_expr S C (expr_binary_op_5 (value_object l) binary_op_instanceof v2) (out_ter S v)*)

    (* TODO: merge these rules in there 
       Inductive instanceof_red : heap -> loc -> value -> value -> Prop :=

      | instanceof_red_value : forall l w S,
          instanceof_red S l w false

      | instanceof_red_true : forall l l1 l2 S,
          binds S l field_normal_prototype l2 ->
          binds S l1 field_proto l2 ->
          instanceof_red S l l1 true

      | instanceof_red_trans : forall l l1 l2 l3 S v',
          binds S l1 field_proto l3 ->
          binds S l field_normal_prototype l2 ->
          l2 <> l3 ->
          instanceof_red S l l3 v' ->
          instanceof_red S l l1 v'.*)


  | red_expr_binary_op_5_in_basic : forall S C v1 v2,
      red_expr S C (expr_binary_op_5 v1 binary_op_in (value_prim v2)) (out_type_error S)

  (*| red_expr_binary_op_5_in : forall S C v1 l b,
      l <> loc_null ->
      b = isTrue (object_indom S l (field_normal (convert_prim_to_string v1))) ->
      red_expr S C (expr_binary_op_5 v1 binary_op_in (value_object l)) (out_ter S b)*)

  (*| red_expr_binary_op_5_add : forall S C v1 v2 o,
      red_expr S C (spec_convert_twice (spec_to_primitive v1) (spec_to_primitive v2) expr_binary_op_add_1) o ->
      red_expr S C (expr_binary_op_5 v1 binary_op_add v2) o*)

  (* Daniele: can we factorize the rules for mult and div? ('multiplicative operators' on the spec*)
  (* Daniele: mult *)
  (*| red_expr_binary_op_5_mult : forall S C v1 v2 m,
      ~ value_is_string v1 ->
      ~ value_is_string v2 ->
      m = JsNumber.mult (convert_prim_to_number v1) (convert_prim_to_number v2) ->
      red_expr S C (expr_binary_op_5 v1 binary_op_mult v2) (out_ter S m)*)

  (* Daniele: div *)
  (*| red_expr_binary_op_5_div : forall S C v1 v2 m,
      ~ value_is_string v1 ->
      ~ value_is_string v2 ->
      m = JsNumber.div (convert_prim_to_number v1) (convert_prim_to_number v2) ->
      red_expr S C (expr_binary_op_5 v1 binary_op_div v2) (out_ter S m)*)

  (* Daniele: equality , TODO: check*)
  (*| red_expr_binary_op_5_equals : forall S v v' b,
      red_expr S C (spec_eq v1 v2) (out_ter S' b)
      red_expr S C (expr_binary_op_5 v1 binary_op_equals v2) (out_ter S' b)*)

 (* Daniele: does-not-equals , TODO: check*)
  (*| red_expr_binary_op_5_not_equals : forall S v v' b,
      red_expr S C (spec_eq v1 v2) (out_ter S' b) ->
      b' = if (b = true) false else true
      red_expr S C (expr_binary_op_5 v1 binary_op_not_equals v2) (out_ter S' b')*)

  (* Daniele: strict equality , TODO: check*)
  (*| red_expr_binary_op_5_strict_equals : forall S v v' b,
      b = value_strict_eqiality_test v1 v2 ->
      red_expr S C (expr_binary_op_5 v1 binary_op_strict_equals v2) (out_ter S b)*)

(* Daniele: strict does-not-equals , TODO: check*)
  (*| red_expr_binary_op_5_not_equals : forall S v v' b,
      red_expr S C (spec_strict_eq v1 v2) (out_ter S' b) ->
      b' = if (b = true) false else true
      red_expr S C (expr_binary_op_5 v1 binary_op_strict_not_equals v2) (out_ter S' b')*)

  (*| red_expr_binary_op_add_1_string : forall S C v1 v2 g,
      (value_is_string v1 \/ value_is_string v2) ->
      g = string_concat (convert_prim_to_string v1) (convert_prim_to_string v2) ->
      red_expr S C (expr_binary_op_add_1 v1 v2) (out_ter S g)*)

  (*| red_expr_binary_op_add_1_number : forall S C v1 v2 o m,
      ~ value_is_string v1 ->
      ~ value_is_string v2 ->
      m = number_add (convert_prim_to_number v1) (convert_prim_to_number v2) ->
      red_expr S C (expr_binary_op_add_1 v1 v2) (out_ter S m)*)


(* TODO : translate these rules into the new scheme, following the template for [add] *)

(* Daniele: updaed (type conversion)
  | binary_op_red_add_str : forall S g g',
      binary_op_red binary_op_add S (value_string g) (value_string g')
        (value_string (String.append g g')) *)

(* Daniele: updaed (type conversion)
  | binary_op_red_mult_number : forall S m m',
      binary_op_red binary_op_mult S m m' (number_mult m m') *)

(* Daniele: updated (type conversion)
  | binary_op_red_div_number : forall S m m',
      binary_op_red binary_op_div S m m' (number_div m m') *)

(* Daniele: updated (type conversion)
  | binary_op_red_equal : forall S v v',
      basic_value v ->
      basic_value v' ->
      binary_op_red binary_op_equal S v v' (value_bool (isTrue (v=v')))
*)


  (** Assignment *)

  | red_expr_assign : forall S0 C op e1 e2 o o1,
      red_expr S0 C (expr_basic e1) o1 ->
      red_expr S0 C (ext_expr_assign_1 o1 op e2) o ->
      red_expr S0 C (expr_assign e1 op e2) o

  | red_expr_ext_expr_assign_1 : forall S0 S1 C e2 re o o2,
      red_expr S1 C (expr_basic e2) o2 ->
      red_expr S1 C (ext_expr_assign_2 re o2) o ->
      red_expr S0 C (ext_expr_assign_1 (out_ter S1 re) None e2) o

  (* Daniele *)
  (*| red_expr_ext_expr_assign_2 : forall v S0 C re S1 r o,
      getvalue S1 r v ->
      red_expr S1 C (ext_expr_assign_3 re v) o ->
      red_expr S0 C (ext_expr_assign_2 re (out_ter S1 r)) o*)

  (* Daniele: assign_ok *)
  (*| red_expr_ext_expr_assign_3_ok : forall S0 S1 S2 s r l x v,
      S2 = update S1 l x v ->
      red_expr S0 C (ext_expr_assign_3 (Ref l x) v) (out_ter S2 v)*)

  (* Daniele: assign_error, see 11.13.1 ECMA 5 *)
  (*| red_expr_ext_expr_assign_3_error : forall S0 C re l x v,
      (ERROR_CONDITIONS re) -> (* TODO *)
      red_expr S0 C (ext_expr_assign_3 re v) (out_basic_error S0)*)

  (*| red_expr_ext_expr_assign_1_op : forall S0 S1 C op (r : reference) v e2 o o2,
      getvalue S1 r v ->
      red_expr S1 C e2 o2 ->
      red_expr S1 C (ext_expr_assign_2_op r v op o2) o ->
      red_expr S0 C (ext_expr_assign_1 (out_ter S1 r) (Some op) e2) o*)

  (*| red_expr_ext_expr_assign_2_op : forall S0 S1 S2 s op r2 l x v1 v2 v,
      getvalue S1 r2 v2 ->
      binary_op_red op S1 v1 v2 v ->
      S2 = update S1 l x v ->
      red_expr S0 C (ext_expr_assign_2_op (Ref l x) v1 op (out_ter S1 r2)) (out_ter S2 v)*)

END OF TO CLEAN----*)

(**************************************************************)
(** ** Reduction rules for comparisons *)

  (*------------------------------------------------------------*)
  (** ** Abstract equality comparison *)
(*
 | spec_eq_same_type : 
     (type_of v1 = type_of v2) ->
     T = type_of v1 ->
     red_expr S C (spec_eq v1 v2) (out_ter (value_equality_test_same_type T v1 v2))

 | spec_eq_diff_type : 
     (type_of v1 != type_of v2) ->
     red_expr S C (spec_eq0 v1 v2) o -> 
     red_expr S C (spec_eq v1 v2) o

 | spec_eq0 : forall v1 v2 S C r o,  
     r = symCases v1 v2 (= type_null) (= type_undef) spec_eq1  
        (symCases v1 v2 (= type_number) (= type_string) (spec_eq2 spec_to_number)
        (symCases v1 v2 (= type_boolean) ( fun _ => True ) (spec_eq2 spec_to_number)
        (symCases v1 v2 (= type_string \/ = type_number ) ( fun _ => True ) (spec_eq2 spec_to_primitive)
        spec_eq_3 v1 v2 ))) ->
        red_expr r o ->
        red_expr S C (spec_eq0 v1 v2) o
  (* 1 *)
  | spec_eq1: forall S c v1 v2, 
      red_expr S C (spec_eq1 v1 v2) (out_ter S true)
  (* 2 *)
  | spec_eq2: forall S C v1 v2 o o', 
      red_expr S C (Conv v1) o
      red_expr S C (spec_eq2_1 v2 o) o' ->
      red_expr S C (spec_eq2 Conv v1 v2) o' 
  | spec_eq2_1: forall S C v n o, 
      red_expr S C (spec_eq v n) o ->
      red_expr S C (spec_eq2_1 v (out_ter S n)) o 
  (* 5 *)
  | spec_eq3: 
      red_expr S C (spec_eq3 v1 v2) (out_ter S false)
*)

 (*------------------------------------------------------------*)
  (** ** Strict equality comparison *)

 (* Daniele: I think we don't need this one, as it can be done directly
    in the reduction rule for strict_equality (see red_expr_binary_op_5_strict_equals)  *)
(*
  | spec_strict_eq : 
     b = value_strict_equality_test v1 v2 ->
     red_expr S C (spec_strict_eq v1 v2) (out_ter S b)
*)

(**************************************************************)
(** ** Reduction rules for specification functions *)

  (*------------------------------------------------------------*)
  (** ** Conversions *)

  (** Conversion to bool *)

  | red_spec_to_boolean : forall S C v b,
      b = convert_value_to_boolean v ->
      red_expr S C (spec_to_boolean v) (out_ter S b)

  (** Conversion to number *)

  | red_spec_to_number_prim : forall S C w n,
      n = convert_prim_to_number w ->
      red_expr S C (spec_to_number (value_prim w)) (out_ter S n)

  | red_spec_to_number_object : forall S C l o1 o,
      red_expr S C (spec_to_primitive (value_object l) preftype_number) o1 ->
      red_expr S C (spec_to_number_1 o1) o ->
      red_expr S C (spec_to_number (value_object l)) o

  | red_spec_to_number_1 : forall S0 S C w n,
      n = convert_prim_to_number w ->
      red_expr S0 C (spec_to_number_1 (out_ter S w)) (out_ter S n)
      (* TODO--Note: [w] above stands for [res_normal (ret_value (value_prim w))] *)

  (** Conversion to integer *)

  | red_spec_to_integer : forall S C v o1 o,
      red_expr S C (spec_to_number v) o1 ->
      red_expr S C (spec_to_integer_1 o1) o ->
      red_expr S C (spec_to_integer v) o

  | red_spec_to_integer_1 : forall S0 S C n n',
      n' = convert_number_to_integer n ->
      red_expr S0 C (spec_to_integer_1 (out_ter S n)) (out_ter S n')

  (** Conversion to string *)

  | red_spec_to_string_prim : forall S C w s,
      s = convert_prim_to_string w ->
      red_expr S C (spec_to_string (value_prim w)) (out_ter S s)

  | red_spec_to_string_object : forall S C l o1 o,
      red_expr S C (spec_to_primitive (value_object l) preftype_string) o1 ->
      red_expr S C (spec_to_string_1 o1) o ->
      red_expr S C (spec_to_string (value_object l)) o

  | red_spec_to_string_1 : forall S0 S C w s,
      s = convert_prim_to_string w ->
      red_expr S0 C (spec_to_string_1 (out_ter S w)) (out_ter S s)
      (* TODO: note w stand for (res_normal (ret_value (value_prim w)) *)

  (** Conversion to object *)

  | red_spec_to_object_undef_or_null : forall S C v,
      v = prim_null \/ v = prim_undef ->
      red_expr S C (spec_to_object v) (out_type_error S)

  | red_spec_to_object_primitive_value : forall S C v l S',
      basic_value_convertible_to_object v -> (* TODO: define this *)
      alloc_primitive_value S v S' l -> (* TODO: define this *)
      red_expr S C (spec_to_object v) (out_ter S' l)

  | red_spec_to_object_object : forall S C l,
      red_expr S C (spec_to_object (value_object l)) (out_ter S l)

  (** Check object coercible *)

  | red_spec_check_object_coercible_undef_or_null : forall S C v,
      v = prim_null \/ v = prim_undef ->
      red_expr S C (spec_check_object_coercible v) (out_type_error S)

  | red_spec_check_object_basic : forall S C v o,
      (* TODO: add a premise to alloc a primitive object Boolean or Number or String *)
      red_expr S C (spec_check_object_coercible v) o

  | red_spec_check_object_object : forall S C l,
      red_expr S C (spec_check_object_coercible (value_object l)) (out_ter S l)

  (** Conversion to primitive *)

  | red_spec_to_primitive_prim : forall S C w gpref,
      red_expr S C (spec_to_primitive (value_prim w) gpref) (out_ter S w)

  | red_spec_to_primitive_obj : forall S C l gpref o,
      red_expr S C (spec_to_default l gpref) o ->
      red_expr S C (spec_to_primitive (value_object l) gpref) o

  (** Conversion to default value *)

  | red_spec_to_default : forall S C l pref o,
      red_expr S C (spec_to_default_1 l pref (other_preftypes pref)) o ->
      red_expr S C (spec_to_default l pref) o

  | red_spec_to_default_1 : forall S C l pref1 pref2 o,
      red_expr S C (spec_to_default_sub_1 l (method_of_preftype pref1) (spec_to_default_2 l pref2)) o ->
      red_expr S C (spec_to_default_1 l pref1 pref2) o

  | red_spec_to_default_2 : forall S C l pref2 o,
      red_expr S C (spec_to_default_sub_1 l (method_of_preftype pref2) spec_to_default_3) o ->
      red_expr S C (spec_to_default_2 l pref2) o 

  | red_spec_to_default_3 : forall S C,
      red_expr S C spec_to_default_3 (out_type_error S)

  | red_spec_to_default_sub_1 : forall o1 S C l x K o,
      red_expr S C (spec_object_get l x) o1 ->
      red_expr S C (spec_to_default_sub_2 l o1 K) o ->
      red_expr S C (spec_to_default_sub_1 l x K) o

  | red_spec_to_default_sub_2_not_callable : forall S0 S C l lf K o,
      is_callable S lf None ->
      red_expr S C (expr_basic K) o ->
      red_expr S0 C (spec_to_default_sub_2 l (out_ter S lf) K) o

  | red_spec_to_default_sub_2_callable : forall S C l lf K o fc o1,
      is_callable S lf (Some fc) ->
      red_call S C lf nil l o1 ->
      red_expr S C (spec_to_default_sub_3 o1 (expr_basic K)) o ->
      red_expr S C (spec_to_default_sub_2 l (out_ter S lf) K) o

  | red_spec_to_default_sub_3 : forall S S0 C r v K o,
      (* TODO: do we need to perform a [get_value S r v] at this point? *)
      red_expr S C (spec_to_default_sub_4 v K) o ->
      red_expr S0 C (spec_to_default_sub_3 (out_ter S r) K) o

  | red_spec_to_default_sub_4_prim : forall S C K w,
      red_expr S C (spec_to_default_sub_4 (value_prim w) K) (out_ter S w)

  | red_spec_to_default_sub_4_object : forall S C l K o,
      red_expr S C K o ->
      red_expr S C (spec_to_default_sub_4 (value_object l) K) o

  (** Auxiliary: Conversion of two values *)

  | red_expr_conv_two : forall S C ex1 ex2 o1 K o,
      red_expr S C ex1 o1 ->
      red_expr S C (spec_convert_twice_1 o1 ex2 K) o ->
      red_expr S C (spec_convert_twice ex1 ex2 K) o

  | red_expr_conv_two_1 : forall S0 S C v1 ex2 o2 K o,
      red_expr S C ex2 o2 ->
      red_expr S C (spec_convert_twice_2 o2 (K v1)) o ->
      red_expr S0 C (spec_convert_twice_1 (out_ter S v1) ex2 K) o

  | red_expr_conv_two_2 : forall S0 S C v2 K o,
      red_expr S C (K v2) o ->
      red_expr S0 C (spec_convert_twice_2 (out_ter S v2) K) o

  (*------------------------------------------------------------*)
  (** ** Operations on objects *)

  (** Get *)

  | red_expr_object_get : forall An S C l x o, 
      object_get_property S (value_object l) x An ->
      red_expr S C (spec_object_get_1 l An) o ->
      red_expr S C (spec_object_get l x) o

  | red_expr_object_get_1_undef : forall S C l, 
      red_expr S C (spec_object_get_1 l prop_descriptor_undef) (out_ter S undef)

  | red_expr_object_get_1_some_data : forall S C l A v, 
      prop_attributes_is_data A ->
      prop_attributes_value A = Some v ->
      red_expr S C (spec_object_get_1 l (prop_descriptor_some A)) (out_ter S v)

  | red_expr_object_get_1_some_accessor : forall S C l A o, 
      prop_attributes_is_accessor A ->
      red_expr S C (spec_object_get_2 l (prop_attributes_get A)) o ->
      red_expr S C (spec_object_get_1 l (prop_descriptor_some A)) o

  | red_expr_object_get_2_undef : forall S C l,
      red_expr S C (spec_object_get_2 l (Some undef)) (out_ter S undef) 

  | red_expr_object_get_2_getter : forall S C l f o,
      f <> undef ->
      red_call S C f nil (value_object l) o ->
      red_expr S C (spec_object_get_2 l (Some f)) o
 
      (* TODO: what should we do for [spec_object_get_2 l None] ? *)

  (** Can put *)

  | red_expr_object_can_put : forall An S C l x o, 
      object_get_own_property S l x An ->
      red_expr S C (spec_object_can_put_1 l x An) o ->
      red_expr S C (spec_object_can_put l x) o

  | red_expr_object_can_put_1_some : forall b An S C l x A o, 
      b = isTrue (prop_attributes_is_accessor A) ->
      red_expr S C (spec_object_can_put_2 l x b) o ->
      red_expr S C (spec_object_can_put_1 l x (prop_descriptor_some A)) o

  | red_expr_object_can_put_2_true : forall b An S C l x A o, 
      (b = If (prop_attributes_set A = Some undef \/ prop_attributes_set A = None) then false else true) ->
        (* TODO: need to check in a real implementation whether the line above is correct *)
      red_expr S C (spec_object_can_put_2 l x true) (out_ter S b)

  | red_expr_object_can_put_2_false : forall b S C l x A o, 
      prop_attributes_is_data A -> (* Note: spec says this hypothesis is optional *)
      b = unsome_default false (prop_attributes_writable A) -> 
        (* TODO: need to check in a real implementation whether the line above is correct *)
      red_expr S C (spec_object_can_put_2 l x false) (out_ter S b)

  | red_expr_object_can_put_1_undef : forall S C l x o lproto, 
      object_proto S l lproto ->
      red_expr S C (spec_object_can_put_3 l x lproto) o ->
      red_expr S C (spec_object_can_put_1 l x prop_descriptor_undef) o

  | red_expr_object_can_put_3_null : forall S C l x o b, 
      object_extensible S l b ->
      red_expr S C (spec_object_can_put_3 l x null) (out_ter S b)

  | red_expr_object_can_put_3_not_null : forall S C l x o lproto Anproto, 
      object_get_property S lproto x Anproto ->
      red_expr S C (spec_object_can_put_4 l Anproto) o ->
      (* Note: semantics is stuck if proto is not a location nor null *)
      red_expr S C (spec_object_can_put_3 l x lproto) o

  | red_expr_object_can_put_4_undef : forall S C l x o b, 
      object_extensible S l b ->
      red_expr S C (spec_object_can_put_4 l prop_descriptor_undef) (out_ter S b)

  | red_expr_object_can_put_4_some_accessor : forall S C l A b, 
      prop_attributes_is_accessor A ->
      (b = If (prop_attributes_set A = Some undef \/ prop_attributes_set A = None) then false else true) ->
        (* TODO: need to check in a real implementation whether the line above is correct *)
        (* TODO: factorize with above *)
      red_expr S C (spec_object_can_put_4 l (prop_descriptor_some A)) (out_ter S b)

  | red_expr_object_can_put_4_some_data : forall S C l x o A bext b, 
      prop_attributes_is_data A ->
      object_extensible S l bext ->
      b = (If bext = false 
            then false 
            else unsome_default false (prop_attributes_writable A)) ->
        (* TODO: need to check in a real implementation whether the line above is correct *)
      red_expr S C (spec_object_can_put_4 l (prop_descriptor_some A)) (out_ter S b)

  (** Put *)

  | red_expr_object_put : forall o1 S C l x v throw o, 
      red_expr S C (spec_object_can_put l x) o1 ->
      red_expr S C (spec_object_put_1 l x v throw o1) o ->
      red_expr S C (spec_object_put l x v throw) o

  | red_expr_object_put_1_false : forall S C l x v throw, 
      red_expr S C (spec_object_put_1 l x v throw (out_ter S false)) (out_reject S throw)

  | red_expr_object_put_1_true : forall AnOwn S C l x v throw o, 
      object_get_own_property S l x AnOwn ->
      red_expr S C (spec_object_put_2 l x v throw AnOwn) o ->
      red_expr S C (spec_object_put_1 l x v throw (out_ter S true)) o

  | red_expr_object_put_2_data : forall A' S C l x v throw AnOwn o,
      prop_attributes_is_data AnOwn ->
      A' = prop_attributes_create_value v ->
      red_expr S C (spec_object_define_own_prop l x A' throw) o ->
      red_expr S C (spec_object_put_2 l x v throw AnOwn) o
  
  | red_expr_object_put_2_not_data : forall AnOwn An S C l x v throw o, 
      ~ prop_attributes_is_data AnOwn ->
      object_get_property S (value_object l) x An ->
      red_expr S C (spec_object_put_3 l x v throw An) o -> 
      red_expr S C (spec_object_put_2 l x v throw AnOwn) o

  | red_expr_object_put_3_accessor : forall fsetter S C l x v throw A o,
      prop_attributes_is_accessor A ->
      Some fsetter = prop_attributes_set A -> 
      (* optional thanks to the canput test: fsetter <> undef --- Arthur: I don't understand... *) 
      red_call S C fsetter (v::nil) (value_object l) o ->
      red_expr S C (spec_object_put_3 l x v throw A) o
  
  | red_expr_object_put_3_not_accessor : forall A' S C l x v throw A o,
      ~ prop_attributes_is_accessor A ->
      A' = prop_attributes_create_data v true true true ->
      red_expr S C (spec_object_define_own_prop l x A' throw) o ->
      red_expr S C (spec_object_put_3 l x v throw A) o

  (** Has property *)

  | red_expr_object_has_property : forall An S C l x b,
      object_get_property S (value_object l) x An ->
      b = isTrue (An <> prop_descriptor_undef) ->
      red_expr S C (spec_object_has_prop l x) (out_ter S b)

  (** Delete *)
      
  | red_expr_object_delete : forall An S C l x throw o,
      object_get_own_property S l x An ->
      red_expr S C (spec_object_delete_1 l x throw An) o ->
      red_expr S C (spec_object_delete l x throw) o

  | red_expr_object_delete_1_undef : forall S C l x throw,
      red_expr S C (spec_object_delete_1 l x throw prop_descriptor_undef) (out_ter S true)

  | red_expr_object_delete_1_some : forall b A S C l x throw o,
      b = isTrue (prop_attributes_configurable A = Some true) ->
      red_expr S C (spec_object_delete_2 l x throw b) o ->
      red_expr S C (spec_object_delete_1 l x throw (prop_descriptor_some A)) o

  | red_expr_object_delete_2_true : forall S C l x throw S', 
      object_rem_property S l x S' ->
      red_expr S C (spec_object_delete_2 l x throw true) (out_ter S' true)

  | red_expr_object_delete_2_false : forall A S C l x throw S', 
      red_expr S C (spec_object_delete_2 l x throw false) (out_reject S throw)

  (** Define own property *)

  | red_expr_object_define_own_property : forall oldpd extensible h' S C l x newpf throw o,(* Steps 1, 2. *)
      object_get_own_property S l x oldpd ->
      object_extensible S l extensible ->
      red_expr h' C (spec_object_define_own_prop_1 l x oldpd newpf throw extensible) o ->
      red_expr S C (spec_object_define_own_prop l x newpf throw) o
      
  | red_expr_object_define_own_prop_1_undef_false : forall S C l x newpf throw, (* Step 3. *)
      red_expr S C (spec_object_define_own_prop_1 l x prop_descriptor_undef newpf throw false) (out_reject S throw)
      
  | red_expr_object_define_own_prop_1_undef_true : forall A' S C l x newpf throw S', (* Step 4. *)
      A' = (If (prop_attributes_is_generic newpf \/ prop_attributes_is_data newpf) 
        then prop_attributes_convert_to_data newpf
        else prop_attributes_convert_to_accessor newpf) ->
      object_set_property S l x A' S' ->
      red_expr S C (spec_object_define_own_prop_1 l x prop_descriptor_undef newpf throw true) (out_ter S' true)
      
  | red_expr_object_define_own_prop_1_includes : forall S C l x oldpf newpf throw, (* Step 6 (subsumes 5). *)
      prop_attributes_contains oldpf newpf ->
      red_expr S C (spec_object_define_own_prop_1 l x (prop_descriptor_some oldpf) newpf throw true) (out_ter S true)
  
  | red_expr_object_define_own_prop_1_not_include : forall S C l x oldpf newpf throw o, (* Steps 6 else branch. *)   
      ~ prop_attributes_contains oldpf newpf ->
      red_expr S C (spec_object_define_own_prop_2 l x oldpf newpf throw) o ->
      red_expr S C (spec_object_define_own_prop_1 l x (prop_descriptor_some oldpf) newpf throw true) o
      
  | red_expr_object_define_own_prop_2_reject : forall S C l x oldpf newpf throw, (* Step 7. *)  
      change_enumerable_attributes_on_non_configurable oldpf newpf ->
      red_expr S C (spec_object_define_own_prop_2 l x oldpf newpf throw) (out_reject S throw)
    
  | red_expr_object_define_own_prop_2_not_reject : forall S C l x oldpf newpf throw o, (* Step 7 else branch. *)   
      ~ change_enumerable_attributes_on_non_configurable oldpf newpf ->
      red_expr S C (spec_object_define_own_prop_3 l x oldpf newpf throw) o ->
      red_expr S C (spec_object_define_own_prop_2 l x oldpf newpf throw) o
      
  | red_expr_object_define_own_prop_3_generic : forall S C l x oldpf newpf throw o,(* Step 8. *)   
      prop_attributes_is_generic newpf ->
      red_expr S C (spec_object_define_own_prop_5 l x oldpf newpf throw) o ->
      red_expr S C (spec_object_define_own_prop_3 l x oldpf newpf throw) o
      
  | red_expr_object_define_own_prop_3_a : forall S C l x oldpf newpf throw o,(* Step 9. *)   
      (prop_attributes_is_data oldpf) <> (prop_attributes_is_data newpf) ->
      red_expr S C (spec_object_define_own_prop_4a l x oldpf newpf throw) o ->
      red_expr S C (spec_object_define_own_prop_3 l x oldpf newpf throw) o
      
  | red_expr_object_define_own_prop_4a_1 : forall S C l x oldpf newpf throw, (* Step 9a. *)   
      prop_attributes_configurable oldpf = Some false ->
      red_expr S C (spec_object_define_own_prop_4a l x oldpf newpf throw) (out_reject S throw)
      
  | red_expr_object_define_own_prop_4a_2 : forall changedpf S' S C l x oldpf newpf throw o, (* Step 9b, 9c. *)   
      changedpf = (If (prop_attributes_is_data oldpf) 
        then prop_attributes_convert_to_accessor oldpf
        else prop_attributes_convert_to_data oldpf) -> 
      object_set_property S l x changedpf S' ->
      red_expr S' C (spec_object_define_own_prop_5 l x oldpf newpf throw) o ->
      red_expr S C (spec_object_define_own_prop_4a l x oldpf newpf throw) o
      
  | red_expr_object_define_own_prop_3_b : forall S C l x oldpf newpf throw o, (* Step 10. *)   
      prop_attributes_is_data oldpf -> 
      prop_attributes_is_data newpf ->
      red_expr S C (spec_object_define_own_prop_4b l x oldpf newpf throw) o -> 
      red_expr S C (spec_object_define_own_prop_3 l x oldpf newpf throw) o 
      
  | red_expr_object_define_own_prop_4b_1 : forall S C l x oldpf newpf throw, (* Step 10a. *)   
      prop_attributes_configurable oldpf = Some false ->
      change_data_attributes_on_non_configurable oldpf newpf ->      
      red_expr S C (spec_object_define_own_prop_4b l x oldpf newpf throw) (out_reject S throw)   
      
  | red_expr_object_define_own_prop_4b_2 : forall S C l x oldpf newpf throw o, (* Step 10a else branch. *)   
      (   (   prop_attributes_configurable oldpf = Some false
           /\ ~ change_data_attributes_on_non_configurable oldpf newpf) 
      \/ (prop_attributes_configurable oldpf = Some true)) ->    
      red_expr S C (spec_object_define_own_prop_5 l x oldpf newpf throw) o -> 
      red_expr S C (spec_object_define_own_prop_4b l x oldpf newpf throw) o  
      
  | red_expr_object_define_own_prop_3_c : forall S C l x oldpf newpf throw o, (* Step 11. *)   
      prop_attributes_is_accessor oldpf -> 
      prop_attributes_is_accessor newpf ->
      red_expr S C (spec_object_define_own_prop_4c l x oldpf newpf throw) o ->
      red_expr S C (spec_object_define_own_prop_3 l x oldpf newpf throw) o    
      
  | red_expr_object_define_own_prop_4c_1 : forall S C l x oldpf newpf throw, (* Step 11a. *)   
      prop_attributes_configurable oldpf = Some false ->
      change_accessor_on_non_configurable oldpf newpf ->      
      red_expr S C (spec_object_define_own_prop_4c l x oldpf newpf throw) (out_reject S throw)    
      
   | red_expr_object_define_own_prop_4c_2 : forall S C l x oldpf newpf throw o, (* Step 11a else branch. *)   
      prop_attributes_configurable oldpf = Some false ->
      ~ change_accessor_on_non_configurable oldpf newpf ->      
      red_expr S C (spec_object_define_own_prop_5 l x oldpf newpf throw) o -> 
      red_expr S C (spec_object_define_own_prop_4c l x oldpf newpf throw) o
      
  | red_expr_object_define_own_prop_5 : forall changedpf S C l x oldpf newpf throw h', (* Step 12, 13. *)
      changedpf = prop_attributes_transfer oldpf newpf ->
      object_set_property S l x changedpf h' ->
      red_expr S C (spec_object_define_own_prop_5 l x oldpf newpf throw) (out_ter h' true)

  (*------------------------------------------------------------*)
  (** ** Operations on references *)

  (** Get value on a reference *)

  | red_expr_ref_get_value_value : forall S C v, (* Step 1. *)
      red_expr S C (spec_ref_get_value (ret_value v)) (out_ter S v)

  | red_expr_ref_get_value_ref_a : forall S C r, (* Steps 2 and 3. *)
      ref_is_unresolvable r ->
      red_expr S C (spec_ref_get_value (ret_ref r)) (out_ref_error S)

  | red_expr_ref_get_value_ref_b: forall ext_get v S C r o, (* Step 4. *)  
      ref_is_property r ->
      ref_base r = ref_base_type_value v ->
      ext_get = (If ref_has_primitive_base r
        then spec_object_get_special
        else spec_object_get) ->
      red_expr S C (ext_get v (ref_name r)) o ->
      red_expr S C (spec_ref_get_value (ret_ref r)) o

  | red_expr_ref_get_value_ref_c : forall L S C r o, (* Step 5. *)     
      ref_base r = ref_base_type_env_loc L ->
      red_expr S C (spec_env_record_get_binding_value L (ref_name r) (ref_strict r)) o ->
      red_expr S C (spec_ref_get_value (ret_ref r)) o

  | red_expr_object_get_special : forall o1 S C v x o, 
      red_expr S C (spec_to_object v) o1 ->
      red_expr S C (spec_object_get_special_1 x o1) o ->
      red_expr S C (spec_object_get_special v x) o       
      
  | red_expr_object_get_special1 : forall S0 C x S l o,
      red_expr S C (spec_object_get l x) o ->
      red_expr S0 C (spec_object_get_special_1 x (out_ter S (value_object l))) o   
 
  (** Auxiliary: combine  functions for combining [red_expr] and [get_value] *)

  | red_spec_expr_get_value : forall S C e o o1, 
      red_expr S C e o1 ->
      red_expr S C (spec_expr_get_value_1 o1) o ->
      red_expr S C (spec_expr_get_value e) o

  | red_spec_expr_get_value_1 : forall S0 S C r o,
      red_expr S C (spec_ref_get_value r) o ->
      red_expr S0 C (spec_expr_get_value_1 (out_ter S r)) o

  (** Put value on a reference *)

  | red_expr_ref_put_value_value : forall S C v vnew, (* Step 1. *)
      red_expr S C (spec_ref_put_value (ret_value v) vnew) (out_ref_error S) 
    
  | red_expr_ref_put_value_ref_a_1 : forall S C r vnew, (* Steps 2 and 3a. *)
      ref_is_unresolvable r ->
      ref_strict r = true ->
      red_expr S C (spec_ref_put_value (ret_ref r) vnew) (out_ref_error S) 
      
  | red_expr_ref_put_value_ref_a_2 : forall o S C r vnew, (* Steps 2 and 3b. *)
      ref_is_unresolvable r ->
      ref_strict r = false ->
      red_expr S C (spec_object_put builtin_global (ref_name r) vnew throw_false) o ->
      red_expr S C (spec_ref_put_value (ret_ref r) vnew) o 
   
  (* ARTHUR::
  | red_expr_ref_put_value_ref_b : forall v ext_put S C r vnew o, (* Step 4. *)     
      ref_is_property r ->
      ref_base r = ref_base_type_value v -> 
      ext_put = (If ref_has_primitive_base r 
        then spec_object_put_special 
        else spec_object_put) ->
      red_expr S C (ext_put v (ref_name r) vnew (ref_strict r)) o ->
      red_expr S C (spec_ref_put_value (ret_ref r) vnew) o
  *)

  (* Can we do with just one rule? *)
  | red_expr_ref_put_value_ref_b_special : forall v S C r vnew o, (* Step 4. *)     
      ref_is_property r ->
      ref_base r = ref_base_type_value v -> 
      ref_has_primitive_base r  ->
      red_expr S C (spec_object_put_special v (ref_name r) vnew (ref_strict r)) o ->
      red_expr S C (spec_ref_put_value (ret_ref r) vnew) o

  | red_expr_ref_put_value_ref_b : forall l S C r vnew o, (* Step 4. *)     
      ref_is_property r ->
      ref_base r = ref_base_type_value (value_object l) -> 
      ~ ref_has_primitive_base r ->
      red_expr S C (spec_object_put l (ref_name r) vnew (ref_strict r)) o ->
      red_expr S C (spec_ref_put_value (ret_ref r) vnew) o
      
  | red_expr_ref_put_value_ref_c : forall L S C r vnew o, (* Step 5. *)     
      ref_base r = ref_base_type_env_loc L ->
      red_expr S C (spec_env_record_set_binding_value L (ref_name r) vnew (ref_strict r)) o ->
      red_expr S C (spec_ref_put_value (ret_ref r) vnew) o  
  
  (*------------------------------------------------------------*)
  (** ** Operations on environment records *)

  (** Has binding *)

  | red_expr_env_record_has_binding : forall S C L x o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_has_binding_1 L x E) o ->
      red_expr S C (spec_env_record_has_binding L x) o 

  | red_expr_env_record_has_binding_1_decl : forall S C L x D b,
      b = isTrue (decl_env_record_indom D x) ->
      red_expr S C (spec_env_record_has_binding_1 L x (env_record_decl D)) (out_ter S b)

  | red_expr_env_record_has_binding_1_obj : forall S C L x l pt o,
      red_expr S C (spec_object_has_prop l x) o ->
      red_expr S C (spec_env_record_has_binding_1 L x (env_record_object l pt)) o

  (** Create immutable binding *)

  | red_expr_env_record_create_immutable_binding : forall D S C L x h',
      env_record_binds S L (env_record_decl D) -> (* Note: the spec asserts that there is a binding *)
      ~ decl_env_record_indom D x -> 
      h' = env_record_write_decl_env S L x mutability_uninitialized_immutable undef ->
      red_expr S C (spec_env_record_create_immutable_binding L x) (out_void h')

  (** Initialize immutable binding *)

  | red_expr_env_record_initialize_immutable_binding : forall D v_old S C L x v h',  
      env_record_binds S L (env_record_decl D) ->
      decl_env_record_binds D x mutability_uninitialized_immutable v_old -> (* Note: v_old is always undef *)
      h' = env_record_write_decl_env S L x mutability_immutable v ->
      red_expr S C (spec_env_record_initialize_immutable_binding L x v) (out_void h')

  (** Create mutable binding *)

  | red_expr_env_record_create_mutable_binding : forall S C L x deletable_opt deletable o E,
      deletable = unsome_default false deletable_opt ->
      env_record_binds S L E ->
      red_expr S C (spec_env_record_create_mutable_binding_1 L x deletable E) o ->
      red_expr S C (spec_env_record_create_mutable_binding L x deletable_opt) o 

  | red_expr_env_record_create_mutable_binding_1_decl_indom : forall S C L x deletable D S',
      ~ decl_env_record_indom D x ->
      S' = env_record_write_decl_env S L x (mutability_of_bool deletable) undef ->
      red_expr S C (spec_env_record_create_mutable_binding_1 L x deletable (env_record_decl D)) (out_void S')

  | red_expr_env_record_create_mutable_binding_1_obj : forall o1 S C L x deletable l pt o,
      red_expr S C (spec_object_has_prop l x) o1 ->
      red_expr S C (spec_env_record_create_mutable_binding_2 L x deletable l o1) o ->
      red_expr S C (spec_env_record_create_mutable_binding_1 L x deletable (env_record_object l pt)) o 

  | red_expr_env_record_create_mutable_binding_obj_2 : forall A S0 C L x deletable l S o,
      A = prop_attributes_create_data undef true true deletable ->
      red_expr S C (spec_object_define_own_prop l x A throw_true) o ->
      red_expr S0 C (spec_env_record_create_mutable_binding_2 L x deletable l (out_ter S false)) o 

  (** Set mutable binding *)

  | red_expr_env_record_set_mutable_binding : forall S C L x v strict o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_set_mutable_binding_1 L x v strict E) o ->
      red_expr S C (spec_env_record_set_mutable_binding L x v strict) o 

  | red_expr_env_record_set_mutable_binding_1_decl : forall v_old mu S C L x v (strict : bool) D o,
      decl_env_record_binds D x mu v_old ->  (* Note: spec says that there is a binding *)
      o = (If mutability_is_mutable mu
            then out_void (env_record_write_decl_env S L x mu v)
            else (if strict then (out_type_error S) else (out_void S))) ->
      red_expr S C (spec_env_record_set_mutable_binding_1 L x v strict (env_record_decl D)) o

  | red_expr_env_record_set_mutable_binding_1_obj : forall S C L x v strict l pt o,
      red_expr S C (spec_object_put l x v strict) o ->
      red_expr S C (spec_env_record_set_mutable_binding_1 L x v strict (env_record_object l pt)) o 

  (** Auxiliary: combined create and set mutable binding *)

  | red_expr_env_record_create_set_mutable_binding : forall S C L x deletable_opt v strict o o1,
      red_expr S C (spec_env_record_create_mutable_binding L x deletable_opt) o1 ->
      red_expr S C (spec_env_record_create_set_mutable_binding_1 o1 L x v strict) o ->
      red_expr S C (spec_env_record_create_set_mutable_binding L x deletable_opt v strict) o 

  | red_expr_env_record_create_set_mutable_binding_1 : forall S S0 C L x v strict o,
      red_expr S C (spec_env_record_set_mutable_binding L x v strict) o ->
      red_expr S0 C (spec_env_record_create_set_mutable_binding_1 (out_void S) L x v strict) o 

  (** Get binding *)

  | red_expr_env_record_get_binding_value : forall E S C L x strict o,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_get_binding_value_1 L x strict E) o ->
      red_expr S C (spec_env_record_get_binding_value L x strict) o 
 
  | red_expr_env_record_get_binding_value_1_decl : forall mu v S C L x strict D o,
      decl_env_record_binds D x mu v -> (* spec says: assert there is a binding *)
      o = (If mu = mutability_uninitialized_immutable
              then (out_ref_error_or_undef S strict)
              else (out_ter S v)) ->
      red_expr S C (spec_env_record_get_binding_value_1 L x strict (env_record_decl D)) o 

  | red_expr_env_record_get_binding_value_1_obj : forall o1 S C L x strict l pt o,
      red_expr S C (spec_object_has_prop l x) o1 ->
      red_expr S C (spec_env_record_get_binding_value_2 x strict l o1) o ->
      red_expr S C (spec_env_record_get_binding_value_1 L x strict (env_record_object l pt)) o 

  | red_expr_env_record_get_binding_value_obj_2_true : forall S0 C x strict l S o,
      red_expr S C (spec_object_get l x) o ->
      red_expr S0 C (spec_env_record_get_binding_value_2 x strict l (out_ter S true)) o 

  | red_expr_env_record_get_binding_value_2_false : forall S0 C x strict l S,
      red_expr S0 C (spec_env_record_get_binding_value_2 x strict l (out_ter S false)) (out_ref_error_or_undef S strict)

  (** Delete binding *)

  | red_expr_env_record_delete_binding : forall S C L x o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_delete_binding_1 L x E) o ->
      red_expr S C (spec_env_record_delete_binding L x) o 

  | red_expr_env_record_delete_binding_1_decl_indom : forall mu v S C L x D S' b,
      decl_env_record_binds D x mu v ->
      (If (mu = mutability_deletable)
          then (S' = env_record_write S L (decl_env_record_rem D x) /\ b = true) 
          else (S' = S /\ b = false))  ->
      red_expr S C (spec_env_record_delete_binding_1 L x (env_record_decl D)) (out_ter S' b)

  | red_expr_env_record_delete_binding_1_decl_not_indom : forall S C L x D,
      ~ decl_env_record_indom D x ->
      red_expr S C (spec_env_record_delete_binding_1 L x (env_record_decl D)) (out_ter S true)

  | red_expr_env_record_delete_binding_1_obj : forall S C L x l pt o,
      red_expr S C (spec_object_delete l x throw_false) o ->
      red_expr S C (spec_env_record_delete_binding_1 L x (env_record_object l pt)) o 

  (** Record implicit this value *)

  | red_expr_env_record_implicit_this_value : forall S C L x o E,
      env_record_binds S L E ->
      red_expr S C (spec_env_record_implicit_this_value_1 L x E) o ->
      red_expr S C (spec_env_record_implicit_this_value L x) o 

  | red_expr_env_record_implicit_this_value_1_decl : forall S C L x D,
      red_expr S C (spec_env_record_implicit_this_value_1 L x (env_record_decl D)) (out_ter S undef)

  | red_expr_env_record_implicit_this_value_1_obj : forall S C L x l (provide_this : bool) v,
      v = (if provide_this then (value_object l) else undef) ->
      red_expr S C (spec_env_record_implicit_this_value_1 L x (env_record_object l provide_this)) (out_ter S v)

  (*------------------------------------------------------------*)
  (** ** Operations on lexical environments *)

  (** Get identifier reference *)

  | red_expr_lexical_env_get_identifier_ref_nil : forall S C x strict r,
      r = ref_create_value undef x strict ->
      red_expr S C (spec_lexical_env_get_identifier_ref nil x strict) (out_ter S r)

  | red_expr_lexical_env_get_identifier_ref_cons : forall S C L lexs x strict o,
      red_expr S C (spec_lexical_env_get_identifier_ref_1 L lexs x strict) o ->     
      red_expr S C (spec_lexical_env_get_identifier_ref (L::lexs) x strict) o 

  | red_expr_lexical_env_get_identifier_ref_cons_1 : forall o1 S C L lexs x strict o,
      red_expr S C (spec_env_record_has_binding L x) o1 ->
      red_expr S C (spec_lexical_env_get_identifier_ref_2 L lexs x strict o1) o ->
      red_expr S C (spec_lexical_env_get_identifier_ref_1 L lexs x strict) o 

  | red_expr_lexical_env_get_identifier_ref_cons_2_true : forall S0 C L lexs x strict S r,
      r = ref_create_env_loc L x strict ->
      red_expr S0 C (spec_lexical_env_get_identifier_ref_2 L lexs x strict (out_ter S true)) (out_ter S r) 

  | red_expr_lexical_env_get_identifier_ref_cons_2_false : forall S0 C L lexs x strict S o,
      red_expr S C (spec_lexical_env_get_identifier_ref lexs x strict) o ->
      red_expr S0 C (spec_lexical_env_get_identifier_ref_2 L lexs x strict (out_ter S false)) o

  (** Function call --- TODO: check this section*)

  | red_expr_execution_ctx_function_call_direct : forall strict newthis S C K func this args o,
      (If (strict = true) then newthis = this 
      else If this = null \/ this = undef then newthis = builtin_global
      else If type_of this = type_object then newthis = this
      else False) (* ~ function_call_should_call_to_object this strict *)
      ->
      red_expr S C (spec_execution_ctx_function_call_1 K func args (out_ter S newthis)) o ->
      red_expr S C (spec_execution_ctx_function_call K func this args) o

  | red_expr_execution_ctx_function_call_convert : forall strict o1 S C K func this args o,
      (~ (strict = true) /\ this <> null /\ this <> undef /\ type_of this <> type_object) ->
      red_expr S C (spec_to_object this) o1 ->      
      red_expr S C (spec_execution_ctx_function_call_1 K func args o1) o ->
      red_expr S C (spec_execution_ctx_function_call K func this args) o

  (*| red_expr_execution_ctx_function_call_1 : forall h' lex' c' strict' S0 C K func args S this o,
      (lex',h') = lexical_env_alloc_decl S (function_scope func) ->
      strict' = (function_code_is_strict (function_code func) || execution_ctx_strict C) ->
        (* todo this line may change; note that in the spec this is in done in binding instantiation *)
      c' = execution_ctx_intro_same lex' this strict' ->
      red_expr h' c' (spec_execution_ctx_binding_instantiation K func (function_code func) args) o ->
      red_expr S0 C (spec_execution_ctx_function_call_1 K func args (out_ter S this)) o *)

  (** Binding instantiation --- TODO: check this section *)

  | red_expr_execution_ctx_binding_instantiation : forall L tail S C K func code args o, (* Step 1 *)
      (* todo: handle eval case -- step 2 *)
      (* todo: [func] needs to contain all the function declarations and the variable declarations *)

      (* --> need an extended form for:  4.d. entry point, with argument "args" (a list that decreases at every loop) *)
      (* todo: step 5b ? *)
      execution_ctx_variable_env C = L :: tail ->
      red_expr S C (spec_execution_ctx_binding_instantiation_1 K func code args L) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation K func code args) o
      
  | red_expr_execution_ctx_binding_instantiation_function : forall names_option S C K func code args L o, (* Step 4a *)
      object_formal_parameters S func names_option ->   
      let names := unsome_default nil names_option in
      red_expr S C (spec_execution_ctx_binding_instantiation_2 K func code args L names) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_1 K (Some func) code args L) o
      
  | red_expr_execution_ctx_binding_instantiation_function_names_empty : forall S C K func code args L o,  (* Loop ends in Step 4d *)  
      red_expr S C (spec_execution_ctx_binding_instantiation_6 K (Some func) code args L) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_2 K func code args L nil) o
      
  | red_expr_execution_ctx_binding_instantiation_function_names_non_empty : forall o1 S C K func code args L argname names o, (* Steps 4d i - iii *)
      let v := hd undef args in
      red_expr S C (spec_env_record_has_binding L argname) o1 ->   
      red_expr S C (spec_execution_ctx_binding_instantiation_3 K func code (tl args) L argname names v o1) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_2 K func code args L (argname::names)) o
              
  | red_expr_execution_ctx_binding_instantiation_function_names_declared : forall S S0 C K func code args L argname names v o,  (* Step 4d iv *)
      red_expr S C (spec_execution_ctx_binding_instantiation_4 K func code args L argname names v (out_void S)) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_3 K func code args L argname names v (out_ter S true)) o
      
  | red_expr_execution_ctx_binding_instantiation_function_names_not_declared : forall o1 S S0 C K func code args L argname names v o, (* Step 4d iv *) 
      red_expr S C (spec_env_record_create_mutable_binding L argname None) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_4 K func code args L argname names v o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_3 K func code args L argname names v (out_ter S false)) o     
      
  | red_expr_execution_ctx_binding_instantiation_function_names_set : forall o1 S S0 C K func code args L argname names v o,  (* Step 4d v *)
      red_expr S C (spec_env_record_set_mutable_binding L argname v (function_code_strict code)) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_5 K func code args L names o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_4 K func code args L argname names v (out_void S)) o 
      
  | red_expr_execution_ctx_binding_instantiation_function_names_loop : forall o1 S S0 C K func code args L names o, (* Step 4d loop *) 
      red_expr S C (spec_execution_ctx_binding_instantiation_2 K func code args L names) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_5 K func code args L names (out_void S)) o 
      
  | red_expr_execution_ctx_binding_instantiation_not_function : forall L S C K code args o, (* Step 4 *)
      red_expr S C (spec_execution_ctx_binding_instantiation_6 K None code args L) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_1 K None code args L) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls : forall L S C K func code args o, (* Step 5 *)
      let fds := function_declarations code in
      red_expr S C (spec_execution_ctx_binding_instantiation_7 K func code args L fds (out_void S)) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_6 K func code args L) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_nil : forall o1 L S0 S C K func code args o, (* Step 5b *)
      red_expr S C (spec_execution_ctx_binding_instantiation_12 K func code args L) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_7 K func code args L nil (out_void S)) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_cons : forall o1 L S0 S C K func code args fd fds o, (* Step 5b *)
      let p := fd_code fd in
      let strict := (function_code_strict code) || (function_body_is_strict p) in
      red_expr S C (spec_creating_function_object (fd_parameters fd) (fd_code fd) (execution_ctx_variable_env C) strict) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_8 K func code args L fd fds strict o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_7 K func code args L (fd::fds) (out_void S)) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_cons_has_bindings : forall o1 L S0 S C K func code args fd fds strict fo o, (* Step 5c *)
      red_expr S C (spec_env_record_has_binding L (fd_name fd)) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_9 K func code args L fd fds strict fo o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_8 K func code args L fd fds strict (out_ter S fo)) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_5d : forall o1 L S0 S C K func code args fd fds strict fo o, (* Step 5d *)
      red_expr S C (spec_env_record_create_mutable_binding L (fd_name fd) (Some false)) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_11 K func code args L fd fds strict fo o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_9 K func code args L fd fds strict fo (out_ter S false)) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_5eii : forall A o1 L S0 S C K func code args fd fds strict fo o, (* Step 5e ii *)
      object_get_property S builtin_global (fd_name fd) (prop_descriptor_some A) ->
      red_expr S C (spec_execution_ctx_binding_instantiation_10 K func code args fd fds strict fo A (prop_attributes_configurable A)) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_9 K func code args env_loc_global_env_record fd fds strict fo (out_ter S true)) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_5eiii : forall o1 L S C K func code args fd fds strict fo o, (* Step 5e iii *)
      let A := prop_attributes_create_data undef true true false in
      red_expr S C (spec_object_define_own_prop builtin_global (fd_name fd) A true) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_11 K func code args env_loc_global_env_record fd fds strict fo o1) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_10 K func code args fd fds strict fo A (Some true)) o
             
  | red_expr_execution_ctx_binding_instantiation_function_decls_5eiv_type_error : forall o1 L S C K func code args fd fds strict fo A configurable o, (* Step 5e iv *)
      configurable <> Some true ->
      prop_descriptor_is_accessor A \/ (prop_attributes_writable A <> Some true \/ prop_attributes_enumerable A <> Some true) ->
      red_expr S C (spec_execution_ctx_binding_instantiation_10 K func code args fd fds strict fo A configurable) (out_type_error S)
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_5eiv : forall o1 L S C K func code args fd fds strict fo A configurable o, (* Step 5e iv *)
     configurable <> Some true ->
      ~ (prop_descriptor_is_accessor A) /\ prop_attributes_writable A = Some true /\ prop_attributes_enumerable A = Some true ->
      red_expr S C (spec_execution_ctx_binding_instantiation_11 K func code args env_loc_global_env_record fd fds strict fo (out_void S)) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_10 K func code args fd fds strict fo A configurable) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_5e_false : forall o1 L S0 S C K func code args fd fds strict fo o, (* Step 5e *)
      L <> env_loc_global_env_record ->
      red_expr S C (spec_execution_ctx_binding_instantiation_11 K func code args L fd fds strict fo (out_void S)) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_9 K func code args L fd fds strict fo (out_ter S true)) o
      
  | red_expr_execution_ctx_binding_instantiation_function_decls_5f : forall o1 L S0 S C K func code args fd fds strict fo o, (* Step 5f *)
      red_expr S C (spec_env_record_set_mutable_binding L (fd_name fd) (value_object fo) strict) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_7 K func code args L fds o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_11 K func code args L fd fds strict fo (out_void S)) o
      
  (* TODO steps 6-7 *)
  
  | red_expr_execution_ctx_binding_instantiation_8 : forall o1 L S C K func code args o, (* Step 8 *)
      let vds := variable_declarations code in
      red_expr S C (spec_execution_ctx_binding_instantiation_13 K func code args L vds (out_void S)) o ->
      red_expr S C (spec_execution_ctx_binding_instantiation_12 K func code args L) o
      
  | red_expr_execution_ctx_binding_instantiation_8b : forall o1 L S0 S C K func code args vd vds o, (* Step 8b *)
      red_expr S C (spec_env_record_has_binding L vd) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_14 K func code args L vd vds o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_13 K func code args L (vd::vds) (out_void S)) o
      
  | red_expr_execution_ctx_binding_instantiation_8c_true : forall o1 L S0 S C K func code args vd vds o, (* Step 8c *)
      red_expr S C (spec_execution_ctx_binding_instantiation_13 K func code args L vds (out_void S)) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_14 K func code args L vd vds (out_ter S true)) o
      
  | red_expr_execution_ctx_binding_instantiation_8c_false : forall o1 L S0 S C K func code args vd vds o, (* Step 8c *)
      red_expr S C (spec_env_record_create_set_mutable_binding L vd (Some false) undef (function_code_strict code)) o1 ->
      red_expr S C (spec_execution_ctx_binding_instantiation_13 K func code args L vds o1) o ->
      red_expr S0 C (spec_execution_ctx_binding_instantiation_14 K func code args L vd vds (out_ter S false)) o
      
  | red_expr_execution_ctx_binding_instantiation_8_nil : forall o1 L S0 S C K func code args o, (* Step 8 *)
      red_expr S0 C (spec_execution_ctx_binding_instantiation_13 K func code args L nil (out_void S)) (out_void S)
      
  (* TODO 13.2 *)    
  | red_expr_creating_function_object : forall S C names p X strict o,
     red_expr S C (spec_creating_function_object names p X strict) o

  

(**************************************************************)
(** ** TODO (?) ===>  probably a red_expr with extended form *)

(* Martin:  If I understand well, this new reduction is for all the `special functions',
   such as `eval', and all the other `native code' function.  Is that it? *)
with red_call : state -> execution_ctx -> value -> list value -> value -> out -> Prop :=
  (* TODO *) 
  | red_call_fake : forall S C f ls v o, red_call S C f ls v o
.


(** ** Semantics of abstract equality comparison --> see old def in bin.v *)

(* TODO: spec_object_put_special *)
