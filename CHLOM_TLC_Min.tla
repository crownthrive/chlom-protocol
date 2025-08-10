---- MODULE CHLOM_TLC_Min ----

VARIABLES L_state, L_used, L_cap, L_nonce, S_w, T_Override, Ledger

Init == \/\ L_state = "Draft"
        /\ L_used = 0
        /\ L_nonce = 0
        /\ L_cap \in Nat
        /\ S_w \in Seq(Nat)
        /\ T_Override \in Seq(Nat)
        /\ Ledger = << >>

Next == (* Implementation-specific transition relation to be completed *)

====
