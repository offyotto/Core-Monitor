# SMC And Apple Silicon

Core-Monitor reads AppleSMC values for thermals and fans. SMC value types handled in current docs and helper code include fixed-point and numeric forms such as `sp78`, `fpe2`, `flt`, `ui8`, and `ui16`.

Apple Silicon fan write behavior is not identical across machines. The helper probes mode-key formats (`F%dMd` vs `F%dmd`) and checks whether `Ftst` exists. It attempts direct manual-mode writes first and uses the force-test fallback only when required.

SMC code is duplicated in spirit across read-only app sampling and privileged helper write/read commands. Keep write-side validation in the helper, not only in the app, because the helper is the privileged boundary.
