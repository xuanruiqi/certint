(***************************************************************************
* Preservation and Progress for mini-ML (CBV) - Proofs                     *
* Arthur Charguéraud, March 2007, Coq v8.1                                 *
***************************************************************************)

Set Implicit Arguments.
Require Import Arith List Metatheory 
  ML_SP_Definitions
  ML_SP_Infrastructure.

Module MkSound(Cstr:CstrIntf)(Const:CstIntf).

Module Infra := MkInfra(Cstr)(Const).
Import Infra.
Import Defs.

Module Mk2(Delta:DeltaIntf).
Module JudgInfra := MkJudgInfra(Delta).
Import JudgInfra.
Import Judge.

(* ********************************************************************** *)
(** Typing is preserved by weakening *)

Lemma typing_weaken : forall gc G E F K t T,
   K ; (E & G) |gc|= t ~: T -> 
   ok (E & F & G) ->
   K ; (E & F & G) |gc|= t ~: T.
Proof.
  introv Typ. gen_eq (E & G) as H. gen G.
  induction Typ; introv EQ Ok; subst.
  apply* typing_var. apply* binds_weaken.
  apply_fresh* (@typing_abs gc) as y. apply_ih_bind* H1.
  apply_fresh* (@typing_let gc M L1) as y. apply_ih_bind* H2.
  auto*.
  auto.
  apply_fresh* (@typing_gc true Ks) as y.
Qed.

Lemma proper_instance_weaken : forall K K' K'' M Us,
  ok (K & K' & K'') ->
  proper_instance (K & K'') M Us ->
  proper_instance (K & K' & K'') M Us.
Proof.
  intros.
  destruct* H0 as [TM [SM FM]]; split3*.
  rewrite <- list_map_id.
  rewrite <- (list_map_id (kinds_open (sch_kinds M) Us)).
  apply (For_all2_map _ (well_kinded (K&K'&K'')) _ _ _ _
                        (well_kinded_weaken K K' K'' H) FM).
Qed.

Lemma typing_weaken_kinds : forall gc K K' K'' E t T,
  K & K''; E |gc|= t ~: T ->
  kenv_ok (K & K' & K'') ->
  K & K' & K''; E |gc|= t ~: T.
Proof.
  introv Typ. gen_eq (K & K'') as H. gen K''.
  induction Typ; introv EQ Ok; subst.
  apply* typing_var. apply* proper_instance_weaken.
  apply_fresh* (@typing_abs gc) as y.
  apply_fresh* (@typing_let gc M (L1 \u dom(K&K'&K''))) as y.
    intros. clear H1 H2.
    unfold concat. rewrite <- app_ass. unfold concat in H0.
    apply* H0; clear H0. rewrite* app_ass.
    rewrite app_ass. fold ((K'' ++ K' ++ K) & kinds_open_vars (sch_kinds M) Xs).
    unfold kinds_open_vars.
    split. apply* disjoint_ok.
      apply* ok_combine_fresh.
      rewrite mkset_dom.
      apply disjoint_comm.
      apply* fresh_disjoint.
      destruct* (fresh_union_r _ _ _ _ H3).
      unfold kinds_open. rewrite map_length.
      rewrite* <- (fresh_length _ _ _ H3).
    intro; intros.
    destruct Ok as [_ Ok].
    destruct (binds_concat_inv H0) as [[Fr B]|B]; clear H0.
      apply* (Ok x).
    use (typing_regular (H Xs (proj1 (fresh_union_r _ _ _ _ H3)))).
    apply* (proj2 (proj41 H0) x).
  auto*.
  apply* typing_cst. apply* proper_instance_weaken.
  apply_fresh* (@typing_gc true Ks) as y.
  intros.
  rewrite concat_assoc.
  apply* (H1 Xs); clear H1.
    rewrite* concat_assoc.
  rewrite* <- concat_assoc.
  forward~ (H0 Xs) as Typ; clear H0.
  split.
    apply* disjoint_ok. destruct* (typing_regular Typ). destruct* H0.
      destruct* (ok_concat_inv _ _ H0).
    unfold kinds_open_vars.
    apply disjoint_comm.
    rewrite mkset_dom.
    apply (fresh_disjoint (length Ks)).
    repeat rewrite dom_concat. auto*.
    unfold kinds_open. rewrite map_length.
    rewrite* (fresh_length _ _ _ H).
  intros x a B.
  elim (binds_concat_inv B).
    intros [Hx Ha]. apply* (proj2 Ok x).
  intro. destruct (typing_regular Typ).
  apply* (proj2 H1 x).
Qed.

Lemma typing_weaken_kinds' : forall gc K K' E t T,
  kenv_ok (K & K') ->
  K ; E |gc|= t ~: T -> K & K' ; E |gc|= t ~: T.
Proof.
  intros.
  replace (K & K') with (K & K' & empty) by simpl*.
  apply* typing_weaken_kinds.
Qed.

Definition well_subst K K' S :=
  forall Z k,
    binds Z k K ->
    well_kinded K' (kind_subst S k) (typ_subst S (typ_fvar Z)).

Lemma well_kinded_subst: forall S K K' k T,
  well_subst K K' S ->
  well_kinded K k T ->
  well_kinded K' (kind_subst S k) (typ_subst S T).
Proof.
  intros.
  induction H0.
    constructor.
  generalize (H x _ H0); intro HW.
  inversions HW.
  simpl typ_subst.
  case_eq (get x S); intros; rewrite H2 in H3.
    subst.
    simpl. apply* wk_kind.
    apply* entails_trans.
    apply* kind_subst_entails.
  simpl.
  inversions H3.
  apply* wk_kind.
  apply* entails_trans.
  apply* kind_subst_entails.
Qed.

Lemma proper_instance_subst : forall K K' K'' M Us S,
  env_prop type S ->
  proper_instance (K & K' & K'') M Us ->
  well_subst (K & K' & K'') (K & map (kind_subst S) K'') S ->
  proper_instance (K & map (kind_subst S) K'') (sch_subst S M)
    (List.map (typ_subst S) Us).
Proof.
  introv TS PI WS.
  destruct* PI.
  split. rewrite sch_subst_arity. apply* typ_subst_type_list.
  split*.
  destruct H0.
  destruct M as [Ma Mt Mk]; simpl in *.
  rewrite* <- kinds_subst_open.
  apply* (For_all2_map (well_kinded (K&K'&K''))); intros.
  apply* well_kinded_subst.
Qed.

Lemma well_subst_fresh : forall K K' K'' S Ys Ks,
  well_subst (K & K' & K'') (K & map (kind_subst S) K'') S ->
  fresh (dom S \u dom K \u dom K'') (length Ks) Ys ->
  well_subst (K & K' & K'' & kinds_open_vars Ks Ys)
    (K & map (kind_subst S) (K'' & kinds_open_vars Ks Ys)) S.
Proof.
  introv WS Fr.
  assert (KxYs: disjoint (dom K \u dom K'')
                         (dom (kinds_open_vars Ks Ys))).
    unfold kinds_open_vars.
    intro v.
    destruct* (in_vars_dec v (dom K \u dom K'')).
    right; intro.
    elim (fresh_rev _ _ Fr (x:=v)).
    rewrite <- union_assoc.
    auto with sets.
    apply (in_dom_combine _ _ H0).
  intro x; intros.
  rewrite map_concat. rewrite <- concat_assoc.
  destruct* (binds_concat_inv H) as [[N B]|B]; clear H.
    apply* well_kinded_extend.
    rewrite dom_map. rewrite dom_concat; rewrite* dom_map.
  destruct k; try constructor.
  simpl. rewrite get_notin_dom.
    apply* wk_kind. apply* binds_prepend.
      use (binds_map (kind_subst S) B).
      simpl in H; apply H.
    apply entails_refl.
  intro; elim (binds_fresh B); clear B.
  unfold kinds_open_vars.
  intro. use (in_dom_combine _ _ H0).
  elim (fresh_disjoint _ _ _ Fr x).
    intro. elim (H2 (in_mkset _ _ H1)).
  intro. elim H2. apply S.union_2. apply* S.union_2.
Qed.

Lemma kenv_ok_subst : forall K K' K'' S,
  env_prop type S ->
  kenv_ok (K & K' & K'') -> kenv_ok (K & map (kind_subst S) K'').
Proof.
  introv HS H. split*.
  intro; intros. destruct H.
  binds_cases H0. apply* (H1 x).
    apply* binds_concat_ok.
    apply* binds_concat_ok. destruct* (ok_concat_inv _ _ H).
  case_eq (get x K''); intros.
    use (binds_map (kind_subst S) H0).
    rewrite (binds_inj B0 H2).
    clear B0 a.
    destruct* (H1 x k); clear H1 H0.
    destruct k; simpl*.
    destruct c as [kc kr].
    split*.
    clear H2 H4.
    unfold All_kind_types in *; simpl in *.
    rewrite map_map; simpl.
    induction kr; simpl. auto.
    simpl in H3.
    split*.
    unfold kind_ok in H4. auto*.
  elim (binds_fresh B0). apply get_none_notin. apply* map_get_none.
Qed.

(* ********************************************************************** *)
(** Type substitution preserves typing *)

Lemma typing_typ_subst : forall gc F K'' S K K' E t T,
  disjoint (dom S) (env_fv E \u fv_in kind_fv K) ->
  env_prop type S ->
  well_subst (K & K' & K'') (K & map (kind_subst S) K'') S ->
  K & K' & K''; E & F |gc|= t ~: T -> 
  K & map (kind_subst S) K''; E & (map (sch_subst S) F) |gc|=
    t ~: (typ_subst S T).
Proof.
  introv. intros Dis TS WS Typ.
  gen_eq (K & K' & K'') as GK; gen_eq (E & F) as G; gen K''; gen F.
  induction Typ; introv WS EQ EQ'; subst; simpls typ_subst.
  (* Var *)
  rewrite~ sch_subst_open. apply* typing_var.
    apply* kenv_ok_subst.
    binds_cases H1.
      apply* binds_concat_fresh.
       rewrite* sch_subst_fresh. use (fv_in_spec sch_fv B).
       intro v. destruct* (Dis v).
       destruct* (proj1 (notin_union _ _ _) H3).
      auto*.
    apply* proper_instance_subst.
  (* Abs *)
  apply_fresh* (@typing_abs gc) as y.
   replace (Sch (typ_subst S U) nil) with (sch_subst S (Sch U nil)) by auto.
   apply_ih_map_bind* H1.
  (* Let *)
  apply_fresh* (@typing_let gc (sch_subst S M)
                            (L1 \u dom S \u dom K \u dom K'')) as y.
   clear H H1 H2. clear L2 T2 t2 Dis.
   simpl. intros Ys Fr. 
   rewrite* <- sch_subst_open_vars.
   rewrite* <- kinds_subst_open_vars.
   rewrite concat_assoc. rewrite <- map_concat.
   unfold sch_arity in Fr; simpl in Fr; rewrite map_length in Fr.
   apply* H0; clear H0.
     apply* well_subst_fresh.
   rewrite* concat_assoc.
   apply_ih_map_bind* H2.
  (* App *)
  auto*.
  (* Cst *)
  rewrite* sch_subst_open.
  assert (disjoint (dom S) (sch_fv (Delta.type c))).
    intro x. rewrite* Delta.closed.
  rewrite* sch_subst_fresh.
  apply* typing_cst.
    apply* kenv_ok_subst.
  rewrite* <- (sch_subst_fresh S H2).
  apply* proper_instance_subst.
  (* GC *)
  apply* (@typing_gc true (List.map (kind_subst S) Ks)
                     (L \u dom S \u dom K \u dom K'')).
   rewrite map_length; intros.
   rewrite* <- kinds_subst_open_vars.
   rewrite concat_assoc. rewrite <- map_concat.
   apply* (H1 Xs); clear H1.
     apply* well_subst_fresh.
   rewrite* concat_assoc.
Qed.

Lemma typing_typ_substs : forall gc K' S K E t T,
  disjoint (dom S) (env_fv E \u fv_in kind_fv K \u dom K) -> 
  env_prop type S ->
  well_subst (K & K') K S ->
  K & K'; E |gc|= t ~: T -> 
  K ; E |gc|= t ~: (typ_subst S T).
Proof.
  intros.
  generalize (@typing_typ_subst gc empty empty); intro TTS.
  simpl in TTS.
  apply* TTS; clear TTS.
    intro v; destruct* (H v).
Qed.
  
(* ********************************************************************** *)
(** Typing schemes for expressions *)

Definition has_scheme_vars gc L (K:kenv) E t M := forall Xs,
  fresh L (sch_arity M) Xs ->
  K & kinds_open_vars (sch_kinds M) Xs; E |gc|= t ~: (M ^ Xs).

Definition has_scheme gc K E t M := forall Vs,
  types (sch_arity M) Vs ->
  For_all2 (well_kinded K) (kinds_open (sch_kinds M) Vs) Vs ->
  K ; E |gc|= t ~: (M ^^ Vs).

(* ********************************************************************** *)
(** Type schemes of terms can be instanciated *)

Lemma kind_subst_open_combine : forall Xs Vs Ks,
  fresh (typ_fv_list Vs \u kind_fv_list Ks) (length Ks) Xs ->
  types (length Xs) Vs ->
  forall k : kind,
    In k Ks ->
    kind_open k Vs = kind_subst (combine Xs Vs) (kind_open k (typ_fvars Xs)).
Proof.
  introv Fr TV. intros.
  destruct TV.
  rewrite* kind_subst_open.
    rewrite* kind_subst_fresh.
      rewrite* (fresh_subst {}).
      rewrite* <- H0.
    rewrite* mkset_dom.
    apply (fresh_disjoint (length Ks)).
    apply* (kind_fv_fresh k Ks).
  apply* list_forall_env_prop.
Qed.

Lemma well_subst_open_vars : forall (K:kenv) Vs (Ks:list kind) Xs,
  fresh (fv_in kind_fv K) (length Ks) Xs ->
  fresh (typ_fv_list Vs \u kind_fv_list Ks) (length Ks) Xs ->
  types (length Xs) Vs ->
  For_all2 (well_kinded K) (kinds_open Ks Vs) Vs ->
  well_subst (K & kinds_open_vars Ks Xs) K (combine Xs Vs).
Proof.
  introv Fr Fr' TV WK.
  intro x; intros.
  destruct* (binds_concat_inv H) as [[N B]|B]; clear H.
    unfold kinds_open_vars in N.
    rewrite* kind_map_fresh.
     simpl.
     rewrite* get_notin_dom.
      destruct k; try constructor.
      eapply wk_kind. apply B.
      apply entails_refl.
     rewrite mkset_dom in N.
      rewrite* mkset_dom.
     unfold kinds_open, typ_fvars. rewrite* map_length.
     rewrite* (fresh_length _ _ _ Fr).
    rewrite* mkset_dom.
    apply* (fresh_disjoint (length Ks)).
    apply (fresh_sub (length Ks) Xs Fr (fv_in_spec kind_fv B)).
   unfold kinds_open_vars, kinds_open in *.
   case_eq (get x (combine Xs Vs)); intros.
    case_eq (get x (combine Xs Ks)); intros.
     fold (binds x k (combine Xs Ks)) in H0.
     generalize (binds_map (fun k : kind => kind_open k (typ_fvars Xs)) H0);
       simpl; rewrite map_combine; intro.
     generalize (binds_func B H1); intro. subst k.
     apply* (For_all2_get (well_kinded K) Xs).
      use (binds_map (kind_subst (combine Xs Vs)) B).
      clear Fr WK H H0 H1 B.
      simpl in H2; rewrite map_combine in H2.
      rewrite list_map_comp in H2.
      rewrite*
        (list_map_ext Ks _ _ (kind_subst_open_combine Xs Ks (Vs:=Vs) Fr' TV)).
     rewrite* H.
    elim (get_contradicts _ _ _ _ H H0); auto.
    rewrite* <- (fresh_length _ _ _ Fr).
  elim (get_contradicts _ _ _ _ B H); auto.
Qed.

Lemma has_scheme_from_vars : forall gc L K E t M,
  has_scheme_vars gc L K E t M ->
  has_scheme gc K E t M.
Proof.
  intros gc L K E t [T Ks] H Vs TV. unfold sch_open. simpls.
  fold kind in K. fold kenv in K.
  pick_freshes (length Ks) Xs.
  unfold sch_arity in TV; simpl in TV.
  rewrite (fresh_length _ _ _ Fr) in TV.
  rewrite~ (@typ_subst_intro Xs Vs T).
  unfolds has_scheme_vars sch_open_vars. simpls.
  intro WK.
  apply* (@typing_typ_substs gc (kinds_open_vars Ks Xs)).
      rewrite* mkset_dom.
      apply* (fresh_disjoint (length Ks)).
    apply list_forall_env_prop. destruct* TV.
  apply* well_subst_open_vars.
Qed.

(* ********************************************************************** *)
(** Typing is preserved by term substitution *)

Lemma typing_trm_subst : forall gc F M K E t T z u, 
  K ; E & z ~ M & F |gc|= t ~: T ->
  (exists L:vars, has_scheme_vars gc L K E u M) -> 
  term u ->
  K ; E & F |gc|= (trm_subst z u t) ~: T.
Proof.
  introv Typt. intros Typu Wu. 
  gen_eq (E & z ~ M & F) as G. gen F.
  induction Typt; introv EQ; subst; simpl trm_subst; destruct Typu as [Lu Typu].
  case_var.
    binds_get H1. apply_empty* (@typing_weaken gc).
      destruct H2; apply* (has_scheme_from_vars Typu).
    binds_cases H1; apply* typing_var.
  apply_fresh* (@typing_abs gc) as y. 
   rewrite* trm_subst_open_var. 
   apply_ih_bind* H1. 
  apply_fresh* (@typing_let gc M0 L1) as y. 
   intros; apply* H0.
     exists (Lu \u mkset Xs); intros Ys TypM.
     assert (fresh Lu (sch_arity M) Ys). auto*.
     generalize (Typu Ys H4); intro; clear H4.
     apply* typing_weaken_kinds.
     clear H0 H1 H2 L2 t2 T2 Wu Typu.
     split.
       apply* disjoint_ok.
       destruct* (typing_regular (H Xs H3)).
       unfold kinds_open_vars.
       apply* ok_combine_fresh.
       rewrite dom_concat.
       apply disjoint_union.
         apply ok_disjoint. destruct* (typing_regular H5).
       apply disjoint_comm.
       unfold kinds_open_vars.
       rewrite mkset_dom. rewrite mkset_dom.
         apply* (fresh_disjoint (sch_arity M)).
         unfold kinds_open. rewrite map_length.
           rewrite* <- (fresh_length _ _ _ H3).
         unfold kinds_open. rewrite map_length.
       rewrite* <- (fresh_length _ _ _ TypM).
     intro; intros.
     destruct (binds_concat_inv H0) as [[Fr B]|B]; clear H0.
       apply* (proj2 (proj41 (typing_regular (H Xs H3))) x).
     apply* (proj2 (proj41 (typing_regular H5))).
   rewrite* trm_subst_open_var. 
   apply_ih_bind* H2.
  assert (exists L : vars, has_scheme_vars gc L K E u M). exists* Lu.
  auto*.
  auto.
  apply_fresh* (@typing_gc true Ks) as y.
   intros Xs Fr.
   apply* H1; clear H1.
   exists (Lu \u dom K \u mkset Xs); intros Ys Fr'.
   forward~ (Typu Ys) as Typu'.
   apply* typing_weaken_kinds.
   use (proj1 (typing_regular Typu')).
   forward~ (H0 Xs) as Typx.
   use (proj1 (typing_regular Typx)).
   clear Typu Typu' Typx H0.
   split*. apply* disjoint_ok.
     unfold kinds_open_vars. apply* ok_combine_fresh.
     unfold kinds_open_vars.
     rewrite dom_concat; repeat rewrite* mkset_dom.
     apply disjoint_comm.
     apply* (fresh_disjoint (sch_arity M)).
     unfold sch_arity in Fr'.
     unfold kinds_open. rewrite map_length. rewrite* (fresh_length _ _ _ Fr').
     unfold kinds_open. rewrite map_length. rewrite* (fresh_length _ _ _ Fr).
   intros x a B.
   destruct (binds_concat_inv B); clear B.
     apply* (proj2 H1 x).
   apply* (proj2 H x).
Qed.

(* ********************************************************************** *)
(** Adding and removing typing_gc *)

Lemma typing_add_gc : forall K E t T,
  K ; E |false|= t ~: T -> K ; E |true|= t ~: T.
Proof.
  induction 1; auto*.
Qed.

(*
Inductive strengthen_kenv (P:kenv->Prop) : kenv -> Prop :=
  | strengthen_in : forall K, P K -> strengthen_kenv P K
  | strengthen_gc : forall K Ks L,
      (forall Xs, fresh L (length Ks) Xs ->
        strengthen_kenv P (K & kinds_open_vars Ks Xs)) ->
      strengthen_kenv P K.
*)

Inductive typing_nrm : kenv -> env -> trm -> typ -> Prop :=
  | typing_nrm_in : forall K E t T,
      typing false K E t T ->
      typing_nrm K E t T
  | typing_nrm_gc : forall Ks L K E t T,
      (forall Xs, fresh L (length Ks) Xs ->
        typing_nrm (K & kinds_open_vars Ks Xs) E t T) ->
      typing_nrm K E t T.

Hint Constructors typing_nrm.
Hint Resolve typing_add_gc.

Lemma typing_nrm_typing : forall K E t T,
  typing_nrm K E t T -> K; E |true|= t ~: T.
Proof.
  induction 1; intros; auto*.
Qed.

(*
Theorem typing_remove_gc_abs : forall K E t U T,
  K ; E |true|= trm_abs t ~: typ_arrow U T ->
  forall t' T',
    (forall K' x,
      K & K' ; E & x ~ Sch U nil |false|= t ~: T ->
      K & K' ; E |false|= t' ~: T') ->
  K 
  
Proof.
  remember true as gc.
  induction 1.
  (* Var *)
  exists (nil(A:=kind)). exists {}.
  intros. destruct Xs. simpl. apply* typing_var.
  use (fresh_length _ _ _ H3).
  (* Abs *)
*)

Lemma kenv_ok_open_fresh : forall K Ks Xs,
  kenv_ok K ->
  kenv_ok (kinds_open_vars Ks Xs) -> 
  fresh (dom K) (length Ks) Xs ->
  kenv_ok (K & kinds_open_vars Ks Xs).
Proof.
  intros.
  split*.
    unfold kinds_open_vars.
    apply* disjoint_ok.
    rewrite mkset_dom. apply disjoint_comm.
    apply* (fresh_disjoint (length Ks)).
    unfold kinds_open. rewrite map_length.
    rewrite* (fresh_length _ _ _ H1).
  intros x a B.
  binds_cases B.
    apply* (proj2 H x).
  apply* (proj2 H0 x).
Qed.

Lemma trm_fv_open : forall t' t n,
  trm_fv (trm_open_rec n t' t) << trm_fv t \u trm_fv t'.
Proof.
  induction t; simpl; intros; intros x Hx; auto*.
  destruct (n0 === n). rewrite* union_empty_l.
    elim (in_empty Hx).
  apply* S.union_2.
  apply* (IHt (S n)).
  destruct (S.union_1 Hx).
    destruct* (S.union_1 (IHt1 n x H)); auto with sets.
    destruct* (S.union_1 (IHt2 (S n) x H)); auto with sets.
  destruct (S.union_1 Hx).
    destruct* (S.union_1 (IHt1 n x H)); auto with sets.
    destruct* (S.union_1 (IHt2 n x H)); auto with sets.
  elim (in_empty Hx).
  Qed.

Lemma typing_strengthen : forall gc y s t K E E' T,
  K ; E & y ~ s & E' |gc|= t ~: T ->
  y \notin trm_fv t ->
  K ; E & E' |gc|= t ~: T.
Proof.
  introv Typ. gen_eq (E & y ~ s & E') as E0. gen E E'.
  induction Typ; intros; subst; auto*.
        binds_cases H1.
          apply* typing_var.
          simpl in H4. elim H4. apply* (proj2 (in_singleton x x)).
        apply* typing_var.
      apply* typing_abs.
      intros.
      rewrite concat_assoc.
      apply* H1.
      intro.
      destruct (S.union_1 (trm_fv_open _ _ _ H4)).
        elim (H3 H5).
      use (proj42 (typing_regular (H0 _ H2))).
      use (ok_remove _ _ _ H6); clear H6.
      inversions H7.
      elim H11.
      rewrite* (proj1 (in_singleton _ _) H5).
      simpl. auto with sets.
    apply* typing_let.
      intros. apply* H0. simpl in H4. auto*.
      intros. rewrite concat_assoc. apply* H2.
    intro.
    destruct (S.union_1 (trm_fv_open _ _ _ H5)).
      elim H4. simpl. auto with sets.
    use (proj42 (typing_regular (H1 _ H3))).
    use (ok_remove _ _ _ H7); clear H7.
    inversions H8.
    elim H12; simpl.
    rewrite (proj1 (in_singleton _ _) H6). auto with sets.
  simpl in H0.
  apply* typing_app.
Qed.

Lemma trm_fv_open' : forall x t' t n,
  x \in trm_fv t -> x \in trm_fv ({n~>t'}t).
Proof.
  induction t; simpl; intros; auto.
  elim (in_empty H).
  destruct (proj1 (in_union _ _ _) H); auto with sets.
  destruct (proj1 (in_union _ _ _) H); auto with sets.
Qed.

Lemma typing_env_scheme : forall gc K E t T x M,
  K; E |gc|= t ~: T ->
  binds x M E ->
  x \in trm_fv t ->
  scheme M.
Proof.
  induction 1; intros.
  (* Var *)
  simpl in H4.
  rewrite (proj1 (in_singleton _ _) H4) in H3.
  rewrite (binds_func H1 H3) in H2.
  destruct H2. intuition.
  (* Abs *)
  destruct (var_fresh (L \u dom E \u {{x}})).
  apply* (H1 x0).
  simpl in H3.
  unfold trm_open.
  apply* trm_fv_open'.
  (* Let *)
  simpl in H4; destruct (S.union_1 H4).
    destruct (var_freshes L1 (sch_arity M0)).
    apply* (H0 x0).
  destruct (var_fresh (L2 \u dom E \u {{x}})).
  apply* (H2 x0).
  unfold trm_open.
  apply* trm_fv_open'.
  (* App *)
  simpl in H2.
  destruct* (S.union_1 H2).
  (* Const *)
  elim (in_empty H3).
  (* GC *)
  destruct (var_freshes L (length Ks)).
  apply* (H1 x0).
Qed.

Lemma list_forall_and : forall (A:Set) (P1 P2:A->Prop) l,
  list_forall P1 l -> list_forall P2 l ->
  list_forall (fun x => P1 x /\ P2 x) l.
Proof.
  induction l; intros; auto.
  inversions H.
  inversions H0.
  auto*.
Qed.

Lemma scheme_ok : forall M,
  scheme M ->
  exists L, forall Xs,
    fresh L (sch_arity M) Xs ->
    kenv_ok (kinds_open_vars (sch_kinds M) Xs).
Proof.
  intros.
  unfold scheme, typ_body in H.
  destruct H as [[L Typ] Kok].
  exists L; intros.
  destruct (Typ Xs H); clear Typ.
  split.
    unfold kinds_open_vars.
    apply* ok_combine_fresh.
  unfold kinds_open_vars.
  apply list_forall_env_prop.
  unfold kinds_open, kind_open.
  unfold typ_open_vars in H1.
  use (list_forall_and Kok H1).
  apply* list_forall_map.
  clear; simpl; intros.
  destruct H0; split.
    unfold All_kind_types in *.
    unfold kind_types in *.
    destruct x; simpl; auto.
    destruct c as [kc kr].
    clear -H1; induction kr; simpl in *; auto*.
  unfold kind_ok in *.
  destruct x; simpl; auto.
  simpl in *; split*.
  destruct c; auto*.
Qed.

Lemma For_all2_build : forall (A B:Set) (P:A->B->Prop) l1 l2,
  length l1 = length l2 ->
  (forall x y, In (x,y) (combine l1 l2) -> P x y) ->
  For_all2 P l1 l2.
Proof.
  induction l1; destruct l2; simpl; intros; try discriminate.
    auto.
  inversion H; auto.
Qed.

Lemma binds_in : forall (A:Set) Xs (Ks : list A) L x k,
  fresh L (length Ks) Xs ->
  In (x, k) (combine Xs Ks) ->
  binds x k (combine Xs Ks).
Proof.
  induction Xs; destruct Ks; intros;
    use (fresh_length _ _ _ H); try discriminate.
    elim H0.
  simpl in *.
  destruct H0.
    inversion H0; subst.
    apply (binds_head x k (combine Xs Ks)).
  destruct (x == a).
    subst.
    use (in_combine_l _ _ _ _ H0).
    destruct H.
    elim (fresh_rev (x:=a) _ _ H3). auto with sets. auto.
  apply (binds_tail (a:=k) (E:=combine Xs Ks) a0 n).
  auto*.
Qed.

Lemma typing_rename : forall gc K E x M E' t T,
  K ; E & x ~ M & E' |gc|= t ~: T ->
  forall y,
    y \notin (dom E \u dom E' \u {{x}} \u trm_fv t) ->
    K ; E & y ~ M & E' |gc|= trm_subst x (trm_fvar y) t ~: T.
Proof.
  introv Typ y Fr.
  case_eq (S.mem x (trm_fv t)); intro.
  use (S.mem_2 H). clear H.
  apply (@typing_trm_subst gc E' M).
      rewrite concat_assoc.
      rewrite concat_assoc in Typ.
      apply* typing_weaken.
      destruct (ok_concat_inv _ _ (proj42 (typing_regular Typ))).
      apply* disjoint_ok.
      intro.
      rewrite <- concat_assoc in Typ.
      destruct (x0 == y).
        subst. right*.
      destruct (x0 == x).
        subst; left. simpl.
        apply (proj2 (notin_union x {{y}} (dom E))).
        split. apply (proj2 (notin_singleton _ _) n).
        apply (fresh_mid E _ _ (proj42 (typing_regular Typ))).
      use (ok_disjoint _ _ (ok_remove _ _ _ (proj42 (typing_regular Typ)))).
      destruct* (H2 x0).
    assert (scheme M).
      apply* typing_env_scheme.
    destruct (scheme_ok H) as [L Sok].
    exists (L \u dom K \u fv_in kind_fv K \u env_fv E \u sch_fv M).
    intro; intros.
    unfold sch_open_vars, typ_open_vars.
    fold (sch_open M (typ_fvars Xs)).
    apply* typing_var.
      apply* kenv_ok_open_fresh.
      apply* ok_push.
      destruct (ok_concat_inv _ _ (proj42 (typing_regular Typ))).
      destruct* (ok_concat_inv _ _ H2).
      split.
        unfold typ_fvars.
        split.
          rewrite (fresh_length _ _ _ H1).
          rewrite* map_length.
        clear; induction Xs; simpl; auto.
      split*.
      clear -H1.
      set (Ks := kinds_open (sch_kinds M) (typ_fvars Xs)) in *.
      unfold typ_fvars in *.
      assert (length Ks = length Xs).
        unfold Ks, kinds_open. repeat rewrite map_length.
        unfold sch_arity in H1. apply* fresh_length.
      apply For_all2_build.
        rewrite* map_length.
      intros.
      assert (exists z, y = typ_fvar z /\ In z Xs).
        use (in_combine_r _ _ _ _ H0).
        destruct (proj1 (in_map_iff _ _ _) H2).
        exists* x0.
      destruct H2 as [z [A Hz]]. subst.
      destruct x.
        apply* wk_kind; try apply entails_refl.
          apply binds_prepend.
          unfold kinds_open_vars.
          unfold typ_fvars; fold Ks.
          clearbody Ks.
          apply* binds_in. rewrite H. rewrite <- (fresh_length _ _ _ H1).
            apply H1.
          clear -H0.
          gen Ks; induction Xs; destruct Ks; simpl; intros; try contradiction.
          destruct H0. inversion H; subst. auto.
          auto.
        apply wk_any.
      auto.
  rewrite trm_subst_fresh.
    apply typing_weaken.
      apply (typing_strengthen _ _ _ Typ).
      intro.
      use (S.mem_1 H0). rewrite H in H1. discriminate.
    destruct (ok_concat_inv _ _ (proj42 (typing_regular Typ))).
    apply *disjoint_ok.
      destruct (ok_concat_inv _ _ H0).
      apply* ok_push.
    simpl.
    apply disjoint_union.
      intro. destruct (x0 == y). subst; right*.
      left. apply (proj2 (notin_singleton _ _) n).
    use (ok_disjoint _ _ (proj42 (typing_regular Typ))).
    intro. destruct* (H2 x0).
  intro. use (S.mem_1 H0). rewrite H in H1. discriminate.
Qed.

Lemma fv_in_concat : forall (A:Set) (fv:A->vars) E1 E2,
  fv_in fv (E1 & E2) = fv_in fv E2 \u fv_in fv E1.
Proof.
  induction E2; simpl.
    rewrite* union_empty_l.
  destruct a. rewrite IHE2. rewrite* union_assoc.
Qed.

Lemma fv_in_combine : forall Xs Ks,
  length Xs = length Ks ->
  fv_in kind_fv (combine Xs Ks) = kind_fv_list Ks.
Proof.
  induction Xs; destruct Ks; simpl; intros; try discriminate.
    auto.
  inversion H; rewrite* IHXs.
Qed.

Definition subset_union_l2 E F G H1 H2 :=
  proj2 (subset_union_l E F G) (conj H1 H2).

Hint Resolve subset_empty_l subset_union_weak_l subset_union_weak_r : sets.
Hint Resolve subset_refl subset_union_l2 : sets.

Lemma typ_fv_open : forall Xs T,
  typ_fv (typ_open T (typ_fvars Xs)) << typ_fv T \u mkset Xs.
Proof.
  induction T; simpl; intros.
      gen Xs; induction n; destruct Xs; simpl; intros; auto with sets.
        rewrite union_empty_l. auto with sets.
      apply* subset_trans.
      repeat rewrite union_empty_l. auto with sets.
    auto with sets.
  apply subset_union_l2; apply* subset_trans;
    apply subset_union_l2; auto with sets;
      rewrite <- union_assoc; auto with sets.
  rewrite <- union_comm_assoc. auto with sets.
Qed.

Lemma kind_fv_open : forall Xs k,
  kind_fv (kind_open k (typ_fvars Xs)) << kind_fv k \u mkset Xs.
Proof.
  destruct k as [[kc kr]|].
    unfold kind_fv. simpl.
    rewrite map_map. simpl.
    induction kr; simpl. auto with sets.
    apply subset_union_l2.
      apply* subset_trans.
        apply typ_fv_open.
      apply subset_union_l2. rewrite <- union_assoc. auto with sets.
      auto with sets.
    apply* subset_trans. rewrite <- union_assoc. auto with sets.
  unfold kind_fv; simpl. auto with sets.
Qed.

Lemma fv_in_kinds_open_vars : forall Ks Xs,
  length Ks = length Xs ->
  fv_in kind_fv (kinds_open_vars Ks Xs) << kind_fv_list Ks \u mkset Xs.
Proof.
  unfold kinds_open_vars.
  intros; rewrite fv_in_combine.
    unfold kinds_open.
    clear; induction Ks; simpl. auto with sets.
    apply subset_union_l2.
      apply* subset_trans.
        apply kind_fv_open.
        apply subset_union_l2; auto with sets.
        unfold kind_fv.
        rewrite <- union_assoc; rewrite union_comm_assoc.
        destruct a as [[kc kr]|]; simpl.
        intro.
        clear; induction kr; simpl; intros.
          elim (in_empty H).
        destruct (S.union_1 H); auto with sets.
      auto with sets.
    apply* subset_trans.
    clear; simpl.
    apply subset_union_l2; auto with sets.
    rewrite union_comm. rewrite union_assoc. auto with sets.
  unfold kinds_open. rewrite map_length. rewrite <- H. reflexivity.
Qed.

Lemma disjoint_fresh : forall n Xs L' L,
  fresh L n Xs ->
  disjoint (mkset Xs) L' ->
  fresh L' n Xs.
Proof.
  induction n; intros; destruct Xs; use (fresh_length _ _ _ H);
    try discriminate.
  simpl in *.
  split. elim (H0 v); intro; auto. elim H2; auto with sets.
  apply* IHn.
  intro.
  destruct (x == v). subst.
    elim (fresh_disjoint _ _ _ (proj2 H) v); intro; auto.
    elim (H0 v); intro; auto.
  elim (H0 x); intro; auto.
Qed.

Lemma kind_fv_list_app : forall Ks1 Ks2,
  kind_fv_list (Ks1 ++ Ks2) = kind_fv_list Ks1 \u kind_fv_list Ks2.
Proof.
  induction Ks1; intros; simpl. rewrite* union_empty_l.
  rewrite IHKs1. rewrite* <- union_assoc.
Qed.

Lemma dom_kinds_open_vars : forall Ks Xs,
  length Ks = length Xs ->
  dom (kinds_open_vars Ks Xs) = mkset Xs.
Proof.
  unfold kinds_open_vars.
  intros; rewrite* mkset_dom.
  unfold kinds_open. rewrite map_length. rewrite* H.
Qed.

(*
Fixpoint shift_bvars (n:nat) (T:typ) {struct T} : typ :=
  match T with
  | typ_bvar i => typ_bvar (n+i)
  | typ_fvar x => T
  | typ_arrow T1 T2 => typ_arrow (shift_bvars n T1) (shift_bvars n T2)
  end.

Definition shift_kinds n Ks := List.map (kind_map (shift_bvars n)) Ks.

Lemma combine_app : forall (A B:Set) (u2:list A) (v2:list B) u1 v1,
  length u1 = length v1 ->
  combine (u1 ++ u2) (v1 ++ v2) = combine u1 v1 ++ combine u2 v2.
Proof.
  induction u1; destruct v1; simpl; intros; try discriminate.
    auto.
  inversion H; rewrite* IHu1.
Qed.

Lemma typ_open_shift : forall Us Us' T,
  typ_open (shift_bvars (length Us') T) (Us' ++ Us) = typ_open T Us.
Proof.
  induction T; simpl; auto.
    induction Us'; auto.
  rewrite IHT1; rewrite* IHT2.
Qed.

Lemma kind_open_shift : forall Us Us' k,
  kind_open (kind_map (shift_bvars (length Us')) k) (Us' ++ Us) =
  kind_open k Us.
Proof.
  intros.
  unfold kind_open.
  unfold kind_map.
  destruct k as [[kc kr]|]; auto.
  induction kr; auto.
  destruct a.
  simpl in *.
  inversion* IHkr.
  clear.
  rewrite* typ_open_shift.
Qed.

Lemma typ_open_extra : forall Us Us' T,
  type (typ_open T Us) ->
  typ_open T (Us ++ Us') = typ_open T Us.
Proof.
  induction T; simpl; intros; auto.
    gen Us; induction n; destruct Us; simpl; intros; auto; inversion H.
  inversions H.
  rewrite* IHT1.
  rewrite* IHT2.
Qed.

Lemma kinds_open_vars_shift : forall Xs Ks Xs' Ks',
  length Ks' = length Xs' ->
  kenv_ok (kinds_open_vars Ks' Xs') ->
  kinds_open_vars (Ks' ++ shift_kinds (length Ks') Ks) (Xs' ++ Xs) =
  kinds_open_vars Ks Xs & kinds_open_vars Ks' Xs'.
Proof.
  introv.
  unfold kinds_open_vars.
  unfold concat.
  unfold kinds_open.
  rewrite map_app.
  replace (typ_fvars (Xs' ++ Xs)) with (typ_fvars Xs' ++ typ_fvars Xs)
    by (unfold typ_fvars; rewrite* map_app).
  set (Us := typ_fvars Xs).
  set (Us' := typ_fvars Xs').
  intros.
  replace (length Ks') with (length Us') by
    (unfold Us'; unfold typ_fvars; rewrite map_length; rewrite* H).
  clearbody Us; clearbody Us'.
  rewrite combine_app.
  gen Ks'; induction Xs'; destruct Ks'; simpl; intros; try discriminate.
    clear.
    gen Ks; induction Xs; destruct Ks; simpl; intros; try reflexivity.
    rewrite IHXs.
    rewrite* kind_open_shift.
  rewrite IHXs'; clear IHXs'.
      destruct H0.
      destruct* (H1 a (kind_open k Us')).
      unfold binds. simpl. case_var*.
      replace (kind_open k (Us' ++ Us)) with (kind_open k Us'). auto.
      clear -H2.
      destruct k as [[kc kr]|]; simpl; auto.
      apply (f_equal (fun x => Some (Kind kc x))).
      induction kr; auto.
      simpl. rewrite IHkr.
        destruct a. simpl.
        rewrite* typ_open_extra.
        unfold All_kind_types in H2.
        simpl in H2.
        destruct* H2.
      unfold All_kind_types in *.
      simpl in *.
      destruct* H2.
    inversion* H.
   split; destruct H0.
     inversion* H0.
   intro; intros.
   apply* (H1 x).
   apply (binds_concat_ok (a ~ kind_open k Us') H2 H0).
   rewrite map_length.
   rewrite* H.
Qed.

Definition cut (A:Set) (n:nat) (l:list A) :
  n <= length l ->
  exists l1, exists l2, length l1 = n /\ l = l1 ++ l2.
Proof.
  induction n; intros.
    exists (nil(A:=A)). exists l. simpl; auto.
  destruct l.
    simpl in H. elimtype False. omega.
  destruct (IHn l) as [l1 [l2 [L E]]]. simpl in H; omega.
  exists (a::l1). exists l2.
  subst; simpl; auto.
Qed.
*)

Fixpoint size (t : trm) : nat :=
  match t with
  | trm_abs t => S (size t)
  | trm_let t1 t2 => S (size t1 + size t2)
  | trm_app t1 t2 => S (size t1 + size t2)
  | _ => 1
  end.

Lemma math_ind : forall Q : nat -> Prop,
  (forall n, (forall m, m < n -> Q m) -> Q n) ->
  forall m, Q m.
Proof.
  intros.
  pose (n:= S m).
  assert (m < n). unfold n; omega.
  clearbody n.
  generalize dependent m.
  induction n; intros.
    assert False. omega. elim H1.
  apply H.
  intros; apply IHn.
  omega.
Qed.

Lemma size_open_var : forall x t n, size ({n~>trm_fvar x}t) = size t.
Proof.
  induction t; simpl; intros; auto.
  destruct (n0 === n); simpl; auto.
Qed.

Lemma fv_in_kenv : forall Z k K,
  binds Z k K ->
  typ_fv_list (kind_types k) << fv_in kind_fv K.
Proof.
  induction K; intros. elim (binds_empty H).
  destruct a.
  replace ((v,k0) :: K) with (K & v ~ k0) in * by simpl; auto.
  binds_cases H.
    apply* subset_trans.
    simpl. auto with sets.
  subst; simpl.
  unfold kind_fv. auto with sets.
Qed.

Lemma binds_dom : forall (A:Set) Z (k:A) K, binds Z k K -> Z \in dom K.
Proof.
  unfold binds; induction K; intros.
    discriminate.
  simpl in H.
  destruct a. destruct (Z == v); simpl; subst; auto with sets.
Qed.

Lemma in_binds : forall (A:Set) x (y:A) K,
  binds x y K -> In (x,y) K.
Proof.
  intros; induction K.
    elim (binds_empty H).
  unfold binds in *; simpl in H.
  destruct a.
  destruct (x == v).
    inversions H. auto.
  auto.
Qed.

Lemma map_equal : forall (A B:Set) (f g:A->B) l1 l2,
  length l1 = length l2 ->
  (forall x y, In (x,y) (combine l1 l2) -> f x = g y) ->
  List.map f l1 = List.map g l2.
Proof.
  induction l1; destruct l2; simpl; intros; try discriminate.
    auto.
  rewrite (IHl1 l2).
      rewrite* (H0 a a0).
    inversion* H.
  intros.
  apply* H0.
Qed.

Lemma in_fresh : forall x Xs,
  fresh {{x}} (length Xs) Xs -> In x Xs -> False.
Proof.
  intros.
  use (fresh_disjoint _ _ _ H).
  destruct (H1 x).
    elim H2. apply* in_mkset.
  elim H2; auto with sets.
Qed.

Lemma well_kinded_rename : forall K M Xs Xs0 Z c,
  fresh (dom K \u sch_fv M) (sch_arity M) Xs ->
  fresh (dom K \u mkset Xs) (sch_arity M) Xs0 ->
  let S := combine Xs (typ_fvars Xs0) in
  binds Z (Some c) (kinds_open_vars (sch_kinds M) Xs) ->
  well_kinded (K & kinds_open_vars (sch_kinds M) Xs0)
    (kind_subst S (Some c)) (typ_subst S (typ_fvar Z)).
Proof.
  intros.
  assert (sch_arity M = length Xs) by apply* fresh_length.
  assert (length Xs = length Xs0).
    rewrite <- H2.
    apply* fresh_length.
  assert (exists Y, typ_subst S (typ_fvar Z) = typ_fvar Y).
    unfold S.
    clear -H3.
    gen Xs0; induction Xs; destruct Xs0; simpl; intros; try discriminate.
      exists Z; auto.
    destruct (Z == a).
      exists v; auto.
    apply (IHXs Xs0).
    inversion* H3.
  destruct H4 as [y Hy].
  rewrite Hy.
  simpl.
  assert (In (Z,y) (combine Xs Xs0)).
    unfold S in Hy.
    use (in_binds H1).
    unfold kinds_open_vars in H4.
    use (in_combine_l _ _ _ _ H4).
    clear -H3 Hy H5.
    gen Xs0; induction Xs; destruct Xs0; simpl; intros; try discriminate.
      elim H5.
    destruct (Z == a).
      subst. inversion* Hy.
    right.
    simpl in H5. destruct H5. subst; elim n; auto.
    apply* (IHXs H Xs0).
  apply (wk_kind (k:=ckind_map (typ_subst S) c)
                 (K:=K&kinds_open_vars (sch_kinds M) Xs0)
                 (x:=y) (k':=ckind_map (typ_subst S) c)).
    apply binds_prepend.
    unfold kinds_open_vars in *.
    remember (typ_fvars Xs) as Vs.
    remember (typ_fvars Xs0) as Vs0.
    assert (Vs0 = List.map (typ_subst S) Vs).
      unfold S; clear S Hy; subst. clear -H3 H.
      unfold typ_fvars at 1 3.
      rewrite map_map.
      apply* map_equal.
      intros.
      use (fresh_resize _ _ _ H); clear H.
      gen Xs0; induction Xs; destruct Xs0; simpl; intros; try discriminate.
        elim H0.
      destruct (y==a).
        subst.
        destruct H0.
          inversion* H.
        simpl in H1.
        use (in_combine_r _ _ _ _ H); clear H.
        destruct H1.
        elim (in_fresh a Xs); auto.
      destruct H0.
        inversions H. elim n; auto.
      simpl in H1. destruct H1.
      assert (fresh (dom K \u sch_fv M) (length Xs) Xs) by auto.
      apply* (IHXs H2 Xs0).
    assert (Hdis: disjoint (dom S) (kind_fv_list (sch_kinds M))).
      use (fresh_disjoint _ _ _ H).
      unfold S. rewrite HeqVs0.
      rewrite mkset_dom.
        clear -H6.
        intro. destruct* (H6 x).
        right.
        unfold sch_fv in H.
        auto.
      unfold typ_fvars. rewrite* map_length.
    assert (TypS: env_prop type S).
      unfold S. rewrite HeqVs0; clear.
      intro.  unfold binds; intros.
      gen Xs0; induction Xs; destruct Xs0; simpl; intros; try discriminate.
      destruct (x == a0). inversion H; auto.
      apply* (IHXs Xs0).
    clear HeqVs HeqVs0.
    clearbody S.
    gen Xs Xs0. 
    unfold sch_arity in *.
    induction (sch_kinds M); destruct Xs; destruct Xs0;
      unfold binds; simpl; intros; try discriminate.
    destruct H4.
      inversions H4.
      unfold binds in H1; simpl in H1.
      destruct* (y == y).
      destruct* (Z == Z).
      clear e e0 H H0 H4 IHl.
      destruct a as [[kc kr]|].
        simpl in *.
        inversions H1. 
        apply (f_equal (fun x:ckind => Some (Some x))).
        clear -Hdis TypS.
        unfold ckind_map.
        rewrite map_map; simpl.
        apply (f_equal (Kind kc)).
        induction kr; simpl; auto.
        rewrite typ_subst_open.
          rewrite typ_subst_fresh.
            rewrite IHkr. auto.
            clear IHkr; unfold kind_fv in *; simpl.
            simpl in Hdis.
            intro. destruct (Hdis x). auto.
            right*.
          unfold kind_fv in *.
          simpl in Hdis.
          intro. destruct* (Hdis x).
        apply TypS.
      discriminate.
    destruct (y == v0).
      subst.
      use (in_combine_r _ _ _ _ H4).
      destruct H0.
      elim (in_fresh v0 Xs0); auto.
    unfold binds in IHl. eapply IHl.
      intro. destruct* (Hdis x).
      simpl in H6. right*.
      unfold binds in H1; simpl in H1.
      destruct (Z == v).
        simpl in H.
        destruct H.
        use (in_combine_l _ _ _ _ H4).
        elim (in_fresh Z Xs); auto.
        subst; auto.
      simpl in H; destruct H.
      destruct (fresh_union_r _ _ _ _ H6). apply H7.
      unfold binds in H1; simpl in H1.
      destruct (Z == v).
        simpl in H.
        destruct H.
        use (in_combine_l _ _ _ _ H4).
        elim (in_fresh Z Xs); subst; auto.
      apply H1.
      simpl in H2; inversion* H2.
      destruct* H0.
      simpl in H; destruct H.
      rewrite <- (fresh_length _ _ _ H6).
      apply* fresh_length.
    auto.
  apply entails_refl.
Qed.

Lemma well_subst_rename : forall L1 K E M Xs Xs0,
  fresh (L1 \u dom K \u fv_in kind_fv K \u env_fv E \u sch_fv M)
        (sch_arity M) Xs ->
  fresh (L1 \u dom K \u mkset Xs) (sch_arity M) Xs0 ->
  let S := combine Xs (typ_fvars Xs0) in
  well_subst
    (K & kinds_open_vars (sch_kinds M) Xs0 & kinds_open_vars (sch_kinds M) Xs)
    (K & kinds_open_vars (sch_kinds M) Xs0) S.
Proof.
  intros; intro; intros.
  assert (DomS: dom S = mkset Xs).
    unfold S; rewrite mkset_dom. auto.
    rewrite <- (fresh_length _ _ _ H).
    unfold typ_fvars; rewrite map_length.
    apply* fresh_length.
  destruct k; try apply wk_any.
  binds_cases H1.
      rewrite typ_subst_fresh.
        rewrite kind_subst_fresh.
          apply* wk_kind. apply entails_refl.
        rewrite DomS.
        apply* fresh_disjoint.
        apply* fresh_sub.
        apply* subset_trans. apply (fv_in_kenv B0).
        intro; intros; auto with sets.
      rewrite DomS.
      simpl.
      apply* fresh_disjoint.
      apply* fresh_sub.
      apply* subset_trans.
        intro; intros.
        rewrite (proj1 (in_singleton _ _) H1) in *.
        apply (binds_dom B0).
      intro; intros; auto with sets.
    rewrite typ_subst_fresh.
      rewrite kind_subst_fresh.
        apply* wk_kind. apply entails_refl.
      rewrite DomS.
      intro.
      destruct* (in_vars_dec x (mkset Xs)).
      right; intro.
      use (fv_in_kenv B1 H2).
      clear H2.
      forward~ (fv_in_kinds_open_vars (sch_kinds M) Xs0); intros.
        unfold sch_arity in H3. apply* fresh_length.
        apply H3.
      destruct (S.union_1 H2); clear H2.
        destruct* (fresh_disjoint _ _ _ H x).
        elim H2; unfold sch_fv; auto with sets.
      destruct* (fresh_disjoint _ _ _ H0 x).
      elim H2; auto with sets.
    rewrite DomS. simpl.
    intro.
    destruct* (x == Z).
    subst; left; intro.
    destruct* (fresh_disjoint _ _ _ H0 Z).
      elim H2.
      use (binds_dom B1).
      rewrite dom_kinds_open_vars in H3; auto.
      apply* fresh_length.
    elim H2; auto with sets.
  unfold S; apply* well_kinded_rename.
Qed.

Lemma typing_nrm_let : forall L1 M Xs K E t1 x L2 t2 T,
  fresh (L1 \u dom K \u fv_in kind_fv K \u env_fv E \u sch_fv M)
          (sch_arity M) Xs ->
  typing_nrm (K & kinds_open_vars (sch_kinds M) Xs) E t1 (sch_open_vars M Xs) ->
  x \notin L2 \u dom E \u trm_fv t2 ->
  typing_nrm K (E & x ~ M) (t2 ^ x) T ->
  typing_nrm K E (trm_let t1 t2) T.
Proof.
  intros.
  remember (E & x ~ M) as E'.
  remember (t2 ^ x) as t2'.
  gen H0; gen K. induction 2; intros.
    remember (sch_open_vars M Xs) as T'.
    remember (K & kinds_open_vars (sch_kinds M) Xs) as K'.
    gen K.
    induction H2; intros; subst.
      apply typing_nrm_in.
      apply* (@typing_let false M (L1 \u dom K0 \u mkset Xs)
                    (L2 \u dom E \u trm_fv t2 \u {{x}})).
        intros.
        unfold sch_open_vars.
        unfold typ_open_vars.
        pose (S := combine Xs (typ_fvars Xs0)).
        rewrite <- (typ_subst_fresh S (sch_type M)).
        assert (TypeS: env_prop type S).
          unfold S; clear.
          intro; intros.
          gen Xs; induction Xs0; destruct Xs; simpl; intros;
            try elim (binds_empty H).
          unfold binds in H; simpl in H.
          destruct (x == v).
            inversion H. auto.
          apply (IHXs0 Xs H).
        assert (DomS: dom S = mkset Xs).
          unfold S; rewrite mkset_dom. auto.
          rewrite <- (fresh_length _ _ _ H0).
          unfold typ_fvars; rewrite map_length.
          apply* fresh_length.
        replace (typ_fvars Xs0) with (List.map (typ_subst S) (typ_fvars Xs)).
          rewrite* <- typ_subst_open.
          apply* (@typing_typ_substs false (kinds_open_vars (sch_kinds M) Xs)).
            clear H H2.
            rewrite DomS. repeat rewrite dom_concat.
            repeat rewrite fv_in_concat.
            apply (fresh_disjoint (length Xs)).
            repeat apply* fresh_union_l.
              apply* disjoint_fresh.
                apply* fresh_resize.
              intro.
              destruct* (in_vars_dec x0 (mkset Xs)).
              right.
              intro.
              use (fv_in_kinds_open_vars (sch_kinds M) Xs0
                   (fresh_length _ _ _ H3) H2); clear H2.
              destruct* (S.union_1 H4); clear H4.
                destruct* (fresh_disjoint _ _ _ H0 x0).
                assert (x0 \in sch_fv M).
                  unfold sch_fv. unfold typ_fv_list.
                  simpl. unfold kind_fv_list in H0.
                  apply (S.union_3 (typ_fv (sch_type M)) H2).
                elim H4. auto with sets.
              destruct* (fresh_disjoint _ _ _ H3 x0).
              elim H4. auto with sets.
            eapply disjoint_fresh.
              apply* fresh_resize.
            intro.
            destruct* (in_vars_dec x0 (mkset Xs)).
            right; intro.
            rewrite dom_kinds_open_vars in H2.
              destruct* (fresh_disjoint _ _ _ H3 x0).
              elim H4. auto with sets.
            apply* fresh_length.
          unfold S; apply* well_subst_rename.
        apply* typing_weaken_kinds.
Qed.

Theorem typing_canonize : forall t K E T,
  K ; E |true|= t ~: T -> typing_nrm K E t T.
Proof.
  intro.
  remember (size t) as h.
  gen t; induction h using math_ind; introv Ht; introv Typ; inversions Typ.
  (* fvar *)
  auto.
  (* abs *)
  destruct (var_fresh (L \u trm_fv t1)) as [x Hx].
  assert (Hx' : x \notin L) by auto.
  use (H1 x Hx'); clear Hx'.
  assert (Ht1: size t1 < size (trm_abs t1)) by (simpl; omega).
  use (H _ Ht1 _ (sym_equal (size_open_var x t1 0)) _ _ _ H2).
  clear -Hx H3 Typ.
  fold (t1 ^ x) in H3.
  remember (E & x ~ Sch U nil) as E'.
  remember (t1 ^ x) as t1'.
  use (proj44 (typing_regular Typ)); clear Typ.
  gen K; induction 1; intros; subst.
    apply typing_nrm_in.
    apply* (@typing_abs false (L \u dom E \u trm_fv t1 \u {{x}})).
      inversion* H.
    intros.
    replace (E & x0 ~ Sch U nil) with (E & x0 ~ Sch U nil & empty)
      by (simpl; auto).
    rewrite* (@trm_subst_intro x t1 (trm_fvar x0)).
    apply* typing_rename.
    simpl.
    apply (proj2 (notin_union x0 (dom E \u {} \u {{x}}) (trm_fv (t1 ^ x)))).
    split*.
    intro.
    use (trm_fv_open (trm_fvar x) t1 0 H2).
    simpl in H3; destruct (S.union_1 H3); elim H1; auto with sets.
  apply (typing_nrm_gc Ks L0).
  intros.
  apply* (H1 Xs).
  (* let *)
  (*
  assert (forall x, x \notin L2 -> typing_nrm K (E & x ~ M) (t2 ^ x) T).
    clear -H H1.
    intros.
    assert (Ht2: size t2 < size (trm_let t1 t2)) by (simpl; omega).
    apply (H _ Ht2 _ (sym_equal (size_open_var x t2 0))).
    apply (H1 _ H0).
  *)
  destruct (var_fresh (L2 \u dom E \u trm_fv t2)) as [x Hx].
  assert (Hx' : x \notin L2) by auto.
  use (H1 _ Hx'); clear Hx'.
  assert (Ht2: size t2 < size (trm_let t1 t2)) by (simpl; omega).
  use (H _ Ht2 _ (sym_equal (size_open_var x t2 0)) _ _ _ H2).
  clear H1 H2 Ht2 Typ.
  fold (t2 ^ x) in H3.
  destruct (var_freshes (L1 \u dom K \u fv_in kind_fv K \u env_fv E
              \u sch_fv M) (sch_arity M)) as [Xs HXs].
  assert (Fr': fresh L1 (sch_arity M) Xs) by auto.
  use (H0 _ Fr'). clear H0 Fr'.
  assert (Ht1: size t1 < size (trm_let t1 t2)) by (simpl; omega).
  use (H _ Ht1 _ (refl_equal (size t1))
        (K & kinds_open_vars (sch_kinds M) Xs) E (sch_open_vars M Xs) H1).
  clear H H1 Ht1.

             
  (* gc *)
  clear H.
  remember true as gc.
  remember (trm_fvar v) as t.
  gen K L.
  induction 1; intros; subst; try discriminate.
    auto*.
  apply (typing_nrm_gc Ks0 L).
  intros.
  apply (H1 Xs H3 (refl_equal (trm_fvar v)) (L0 \u mkset Xs)); clear H1.
  intros.
  apply* typing_weaken_kinds.
  assert (Fr: fresh L0 (length Ks) Xs0) by auto.
  use (proj41 (typing_regular (H2 Xs0 Fr))); clear Fr H2.
  use (proj41 (typing_regular (H0 Xs H3))); clear H0.
  apply* kenv_ok_open_fresh.
Lemma kenv_ok_concat_inv : forall K1 K2,
  kenv_ok (K1 & K2) -> kenv_ok K1 /\ kenv_ok K2.
Proof.
  intros.
  split; split; destruct H; destruct* (ok_concat_inv _ _ H);
    intro; intros; apply* (H0 x a).
Qed.
    destruct* (kenv_ok_concat_inv _ _ H4).
  rewrite dom_concat.
  apply* fresh_union_l.
    apply* disjoint_fresh.
    rewrite* <- (dom_kinds_open_vars Ks Xs0).
    apply disjoint_comm.
    apply* ok_disjoint.
    apply* fresh_length.
  rewrite* dom_kinds_open_vars. apply* fresh_length.
  (* abs *)
  destruct (var_fresh (L \u trm_fv t1)) as [x Hx].
  use (IHt Typ).
  apply (typing_nrm_gc .
End.  

Lemma kind_map_map : forall f f' k,
  kind_map f (kind_map f' k) = kind_map (fun x => f (f' x)) k.
Proof.
  intros.
  destruct k as [[kc kr]|]; auto.
  induction kr; auto.
  simpl in *.
  inversion* IHkr.
Qed.
  rewrite kind_map_map.
  apply (f_equal (fun f:typ->typ => kind_map f k)).

Lemma ckind_map
      
  
    
  

    Search fresh.
  (* Abs *)
  destruct (var_fresh (L \u trm_fv t1)) as [x Hx].
  assert (Hx' : x \notin L) by auto.
  destruct* (H1 x Hx' L0) as [Ks [Lk AbsH]]; clear H0 H1 Hx'.
  exists Ks. exists Lk.
  intros.
  apply* (@typing_abs false (L \u dom E \u trm_fv t1 \u {{x}})).
  intros.
  replace (E & x0 ~ Sch U nil) with (E & x0 ~ Sch U nil & empty)
    by (simpl; auto).
  rewrite* (@trm_subst_intro x t1 (trm_fvar x0)).
  apply* typing_rename.
  simpl.
  apply (proj2 (notin_union x0 (dom E \u {} \u {{x}}) (trm_fv (t1 ^ x)))).
  split*.
  intro.
  use (trm_fv_open (trm_fvar x) t1 0 H2).
  simpl in H3; destruct (S.union_1 H3); elim H1; auto with sets.

Theorem typing_remove_gc : forall K E t T,
  K ; E |true|= t ~: T ->
  forall L, exists Ks, exists L',
    forall Xs, fresh (L \u L') (length Ks) Xs ->
      K & kinds_open_vars Ks Xs; E |false|= t ~: T.
Proof.
  remember true as gc.
  induction 1; intros.
  (* Var *)
  exists (nil(A:=kind)). exists {}.
  intros. destruct Xs. simpl. apply* typing_var.
  use (fresh_length _ _ _ H3).
  (* Abs *)
  destruct (var_fresh (L \u trm_fv t1)) as [x Hx].
  assert (Hx' : x \notin L) by auto.
  destruct* (H1 x Hx' L0) as [Ks [Lk AbsH]]; clear H0 H1 Hx'.
  exists Ks. exists Lk.
  intros.
  apply* (@typing_abs false (L \u dom E \u trm_fv t1 \u {{x}})).
  intros.
  replace (E & x0 ~ Sch U nil) with (E & x0 ~ Sch U nil & empty)
    by (simpl; auto).
  rewrite* (@trm_subst_intro x t1 (trm_fvar x0)).
  apply* typing_rename.
  simpl.
  apply (proj2 (notin_union x0 (dom E \u {} \u {{x}}) (trm_fv (t1 ^ x)))).
  split*.
  intro.
  use (trm_fv_open (trm_fvar x) t1 0 H2).
  simpl in H3; destruct (S.union_1 H3); elim H1; auto with sets.
  (* Let *)
  destruct (var_fresh (L2 \u dom E \u trm_fv t2)) as [x Hx].
  assert (Hx' : x \notin L2) by auto.
  destruct* (H2 x Hx' L) as [Ks [Lk Hlet]]; clear H1 H2 Hx'.
  destruct (var_freshes (L1 \u dom K \u fv_in kind_fv K \u env_fv E
              \u sch_fv M \u kind_fv_list Ks) (sch_arity M)) as [Xs HXs].
  assert (Fr': fresh L1 (sch_arity M) Xs) by auto.
  destruct* (H0 Xs Fr' (L \u mkset Xs)) as [Ks' [Lk' Harg]]; clear H H0 Fr'.
  exists (Ks ++ Ks'). exists (Lk \u Lk').
  intros.
  apply* (@typing_let false M (L1 \u dom K \u mkset Xs \umkset Xs0)
               (L2 \u dom E \u trm_fv t2 \u {{x}})).
    intros.
    unfold sch_open_vars.
    unfold typ_open_vars.
    pose (S := combine Xs (typ_fvars Xs1)).
    rewrite <- (typ_subst_fresh S (sch_type M)).
      replace (typ_fvars Xs1) with (List.map (typ_subst S) (typ_fvars Xs)).
        rewrite <- typ_subst_open.
        apply (@typing_typ_substs false (kinds_open_vars (sch_kinds M) Xs)).
            clear Hlet Harg.
            unfold S. rewrite mkset_dom. repeat rewrite dom_concat.
            repeat rewrite fv_in_concat.
            apply (fresh_disjoint (length Xs)).
               repeat apply* fresh_union_l.
               apply* disjoint_fresh.
                 apply* fresh_resize.
               intro.
               destruct* (in_vars_dec x0 (mkset Xs)).
               right.
               intro.
               use (fv_in_kinds_open_vars (sch_kinds M) Xs1
                      (fresh_length _ _ _ H0) H2); clear H2.
               destruct* (S.union_1 H3); clear H3.
                 destruct* (fresh_disjoint _ _ _ HXs x0).
                 assert (x0 \in sch_fv M).
                   unfold sch_fv. unfold typ_fv_list.
                   simpl. unfold kind_fv_list in H2.
                   apply (S.union_3 (typ_fv (sch_type M)) H2).
                 elim H3. auto with sets.
               destruct* (fresh_disjoint _ _ _ H0 x0).
               elim H3. auto with sets.
              eapply disjoint_fresh.
                apply* fresh_resize.
              intro.
              destruct* (in_vars_dec x0 (mkset Xs)).
              right; intro.
              use (fv_in_kinds_open_vars _ Xs0 (fresh_length _ _ _ H) H2);
                clear H2.
              destruct* (S.union_1 H3); clear H3.
              rewrite kind_fv_list_app in H2.
              destruct* (S.union_1 H2); clear H2.
               destruct* (fresh_disjoint _ _ _ HXs x0).
                 elim H2. auto with sets.
End.

Lemma typing_hide_gc : forall K E t T,
  K ; E |true|= t ~: T ->
  forall t',
  (forall K',
    K' ; E |false|= t ~: T ->
    K' ; E |false|= t' ~: T) ->
  K ; E |true|= t' ~: T.
Proof.
  remember true as gc.
  induction 1; intros; subst.
  (* Var *)
  apply typing_add_gc.
  use (H3 (empty(A:=kind))).
  (* Abs *)
  destruct (var_fresh L) as [x Hx].
  use (H1 x Hx); clear H1.
  apply* H1

  
(* ********************************************************************** *)
(** Extra hypotheses for main results *)

Module Type SndHypIntf.
  Parameter delta_typed : forall n t1 t2 tl K E T,
    Delta.rule n t1 t2 ->
    list_for_n term n tl ->
    K ; E |false|= trm_inst t1 tl ~: T ->
    K ; E |false|= trm_inst t2 tl ~: T.
  Parameter const_arity_ok : forall c vl K T,
    list_for_n value (S(Const.arity c)) vl ->
    K ; empty |false|= const_app c vl ~: T ->
    exists n:nat, exists t1:trm, exists t2:trm, exists tl:list trm,
      Delta.rule n t1 t2 /\ list_for_n term n tl /\
      const_app c vl = trm_inst t1 tl.
  Parameter delta_arity : forall n t1 t2,
    Delta.rule n t1 t2 ->
    exists c, exists pl, t1 = const_app c pl /\ length pl = S(Const.arity c).
End SndHypIntf.

Module Mk3(SH:SndHypIntf).
Import SH.

(* ********************************************************************** *)
(** Preservation: typing is preserved by reduction *)

Lemma typ_open_vars_nil : forall T,
  type T -> typ_open_vars T nil = T.
Proof.
  induction T; unfold typ_open_vars; simpl; intros; auto*.
    inversion H.
  unfold typ_open_vars in *; simpls.
  rewrite IHT1. rewrite* IHT2. inversion* H. inversion* H.
Qed.

Lemma typing_abs_inv : forall K E t t1 t2 T T1 T2,
  t = trm_abs t1 ->
  T = typ_arrow T1 T2 ->
  K ; E |= t ~: T ->
  K ; E |= t2 ~: T1 ->
  K ; E |= t1 ^^ t2 ~: T2.
Proof.
  introv Et ET Typ1 Typ2; induction Typ1; try discriminate.
    inversions Et; inversions ET; clear Et ET.
    pick_fresh x. 
    rewrite* (@trm_subst_intro x). 
    apply_empty* typing_trm_subst.
    exists {}. intro. unfold sch_arity, kinds_open_vars, sch_open_vars; simpl.
    destruct* Xs. simpl. rewrite* typ_open_vars_nil.
    simpl. intuition.
  apply* (typing_gc Ks L).
  intros.
  apply* H0.
  apply* typing_weaken_kinds'.
  simpl.
  forward~ (H Xs) as Typ. apply (proj41 (typing_regular Typ)).
Qed.

Lemma preservation_result : preservation.
Proof.
  introv Typ. gen t'.
  induction Typ; introv Red; subst; inversions Red;
    try (apply* delta_typed); try (apply* typing_gc; fail).
  rewrite* H3.
  rewrite* H2.
  pick_fresh x. rewrite* (@trm_subst_intro x). 
   apply_empty* typing_trm_subst.
   exists* L1.
  rewrite* H3.
  apply* (@typing_let M L1).
  (* Beta *)
  apply* typing_abs_inv.
  (* Delta *)
  rewrite* H.
  auto*.
  auto*.
  rewrite* H2.
Qed. 

(* ********************************************************************** *)
(** Progress: typed terms are values or can reduce *)

Lemma value_app_const : forall t1 t2 n,
  valu n (trm_app t1 t2) ->
  exists c:Const.const, exists vl:list trm,
    length vl + n = Const.arity c /\ trm_app t1 t2 = const_app c vl /\
    list_forall value vl.
Proof.
  induction t1; intros; inversions H; try (inversion H3; fail).
    clear IHt1_2.
    destruct (IHt1_1 _ _ H3) as [c [vl [Hlen [Heq Hv]]]].
    exists c. exists (vl ++ t2 :: nil).
    split. rewrite app_length. rewrite <- Hlen. simpl. ring.
    split. rewrite Heq. unfold const_app.
      rewrite fold_left_app. simpl. auto.
    apply* list_forall_concat.
    constructor; auto. exists* n2.
  exists c. exists (t2 :: nil).
  inversions H3. rewrite H1.
  unfold const_app. simpl; auto.
  split3*. constructor; auto. exists* n2.
Qed.

Lemma progress_delta : forall K t0 t3 t2 T,
  K; empty |= trm_app (trm_app t0 t3) t2 ~: T ->
  valu 0 (trm_app t0 t3) ->
  value t2 ->
  exists t' : trm, trm_app (trm_app t0 t3) t2 --> t'.
Proof.
  intros.
  destruct (value_app_const H0) as [c [vl [Hlen [Heq Hv]]]].
  destruct (const_arity_ok (c:=c) (vl:=vl ++ t2 :: nil) (K:=K) (T:=T)).
    split. rewrite <- Hlen. rewrite app_length. simpl; ring.
    apply* list_forall_concat.
    rewrite Heq in H.
    unfold const_app in *. rewrite* fold_left_app.
  destruct H2 as [t1' [t3' [tl [R [Htl Heq']]]]].
  exists (trm_inst t3' tl).
  rewrite Heq.
  unfold const_app in *.
  rewrite fold_left_app in Heq'; simpl in Heq'.
  rewrite Heq'.
  apply* red_delta.
Qed.

Lemma progress_result : progress.
Proof.
  introv Typ. gen_eq (empty:env) as E. poses Typ' Typ.
  induction Typ; intros; subst;
    try (pick_freshes (length Ks) Xs; apply* (H0 Xs)).
  inversions H1.
  left. exists* 0.
  right. pick_freshes (sch_arity M) Ys.
    destructi~ (@H0 Ys) as [[n Val1] | [t1' Red1]].
      assert (value t1). exists* n.
      exists* (t2 ^^ t1).
      exists* (trm_let t1' t2).
  destruct~ IHTyp1 as [Val1 | [t1' Red1]]. 
    destruct~ IHTyp2 as [Val2 | [t2' Red2]].
      gen_eq (typ_arrow S T) as U; intro HU.
      gen_eq (empty(A:=sch)) as E; intro HE.
      induction Typ1; inversions HU;
        try (pick_freshes (length Ks) Xs; apply* (H0 Xs);
               forward~ (H Xs) as Typ3; destruct* (typing_regular Typ3);
               try apply* typing_weaken_kinds'; simpl*);
        destruct Val1 as [n Val1]; inversions Val1.
        right; exists* (t1 ^^ t2).
        destruct n.
          right; apply* progress_delta.
        left. destruct Val2. exists* n.
        case_eq (Const.arity c); intros.
          right. rewrite H2 in Val1.
          destruct (const_arity_ok (c:=c)(vl:=t2::nil)(K:=K)(T:=T)).
            rewrite H2. constructor; simpl; auto.
          unfold const_app; simpl*.
          destruct H4 as [t1' [t3' [tl [R [Htl Heq]]]]].
          exists (trm_inst t3' tl).
          unfold const_app in Heq; simpl in Heq; rewrite Heq.
          apply* red_delta.
        left. exists n. rewrite H2 in Val1. destruct* Val2.
      right; exists* (trm_app t1 t2'). 
    right; exists* (trm_app t1' t2).
  left; exists* (Const.arity c).
Qed.

Lemma value_irreducible : forall t t',
  value t -> ~(t --> t').
Proof.
  induction t; introv HV; destruct HV as [k HV']; inversions HV';
    intro R; inversions R.
       destruct (delta_arity H0) as [c [pl [Heq Hlen]]]. rewrite Heq in H.
       destruct* (trm_inst_app_inv c pl tl). subst. discriminate.
       destruct H3; destruct H3; rewrite H3 in H. discriminate.
      inversions H2.
     clear IHt1 IHt2 H1.
     destruct (delta_arity H0) as [c [pl [Heq Hlen]]]. rewrite Heq in H.
     destruct (value_app_const HV').
     destruct H1 as [vl [Hl [He Hv]]].
     rewrite He in H; clear He.
     unfold trm_inst in H.
     rewrite trm_inst_app in H.
     destruct (const_app_eq _ _ _ _ H). subst.
     rewrite map_length in Hl.
     omega.
    elim (IHt1 t1'). exists* (S k). auto.
   elim (IHt2 t2'). exists* n2. auto.
  destruct (delta_arity H0) as [c' [pl [Heq Hlen]]]. rewrite Heq in H.
  unfold trm_inst in H.
  rewrite trm_inst_app in H.
  assert (const_app c nil = trm_cst c). auto.
  rewrite <- H2 in H.
  destruct (const_app_eq _ _ _ _ H). subst.
  rewrite <- (map_length (trm_inst_rec 0 tl)) in Hlen.
  rewrite H4 in Hlen. discriminate.
Qed.

End Mk3.

End Mk2.

End MkSound.
