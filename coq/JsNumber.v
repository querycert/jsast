Set Implicit Arguments.
Require Export Shared.
Require Flocq.Appli.Fappli_IEEE Flocq.Appli.Fappli_IEEE_bits.


(**************************************************************)
(** ** Type for number (IEEE floats) *)

Definition number : Type := 
  Fappli_IEEE_bits.binary64.


(**************************************************************)
(** ** Conversions on numbers *)

Definition of_int : int -> number := 
  Fappli_IEEE_bits.b64_of_bits.

(* TODO: implement definitions *)
Parameter from_string : string -> number.
Parameter to_string : number -> string.


(**************************************************************)
(** ** Particular values of numbers *)

(* TODO: find definitions in Flocq *)
Parameter nan : number.
Parameter zero : number.
Parameter neg_zero : number.
Parameter one : number.
Parameter infinity : number.
Parameter neg_infinity : number.


(**************************************************************)
(** ** Unary operations on numbers *)

(* TODO: find definitions in Flocq *)

Parameter floor : number -> number.
Parameter absolute : number -> number.
Parameter sign : number -> number. (* returns arbitrary when x is zero or nan *)


(**************************************************************)
(** ** Binary operations on numbers *)

Definition add : number -> number -> number :=
  Fappli_IEEE_bits.b64_plus Fappli_IEEE.mode_NE.

Definition mult : number -> number -> number :=
  Fappli_IEEE_bits.b64_mult Fappli_IEEE.mode_NE.

Definition div : number -> number -> number :=
  Fappli_IEEE_bits.b64_div Fappli_IEEE.mode_NE.

(* Todo: find comparison operator *)
Global Instance number_comparable : Comparable number.
Proof. Admitted.


(**************************************************************)
(** ** Extraction of numbers *)

Require Import ExtrOcamlZInt.
Extract Inductive Fappli_IEEE.binary_float => float [
  "(fun s -> if s then (0.) else (-0.))"
  "(fun s -> if s then infinity else neg_infinity)"
  "nan"
  "(fun (s, m, e) -> let f = ldexp (float_of_int m) e in if s then f else -.f)"
].

(** The following inline are needed to avoid their code being extracted *)

Extraction Inline Fappli_IEEE.Bplus Fappli_IEEE.binary_normalize Fappli_IEEE_bits.b64_plus.
Extraction Inline Fappli_IEEE.Bmult Fappli_IEEE.Bmult_FF Fappli_IEEE_bits.b64_mult.
Extraction Inline Fappli_IEEE.Bdiv Fappli_IEEE_bits.b64_div.