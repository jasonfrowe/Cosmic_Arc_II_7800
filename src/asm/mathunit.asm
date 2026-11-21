; ===========================================================================
; AstroCart math unit, version 2: register equates.
;
; The definition is docs/MATHUNIT.md in the AstroCart V4 repository
; (~/Software/FPGA/Atari7800_AstroCart_V4); the a7800 fork's astromath.h
; matches it bit for bit. Little endian. Writes and reads are different
; registers at the same address. Results are ready on the next instruction.
; The unit answers only when the .a78 header has "ACM" at bytes 59-61
; (tools/a78header.py).
; ===========================================================================

; ---- arithmetic block ($0430-$043F) ----
M_A     = $0430     ; W  A (16)            R  P = A*B, bits 0-15
M_B     = $0432     ; W  B (16)            R  P bits 16-31
M_P     = $0430     ;                      R  P (32)
M_N     = $0434     ; W  N (32)            R  Q = N/D (32)
M_Q     = $0434
M_D     = $0438     ; W  D (16)            R  R = N mod D (16)
M_R     = $0438
M_CTRL  = $043A     ; W  bit 0: signed     R  S = sqrt(N), bits 0-7
M_S     = $043A     ;                      R  S (16)
M_CMD   = $043B     ; W  1 ACC=0, 2 ACC+=P, 3 ACC-=P, 4 N=ACC
M_CTRLR = $043C     ;                      R  CTRL
M_STAT  = $043D     ;                      R  bit 0: D is 0
M_RND   = $043E     ; W  shift a seed byte R  xorshift32, steps once a read
M_ID    = $043F     ;                      R  $A1

; ---- trig block ($0420-$042F) ----
M_X     = $0420     ; W  X (16, signed)    R  XR: X turned by T
M_Y     = $0422     ; W  Y (16, signed)    R  YR
M_T     = $0424     ; W  T (angle)         R  ANG = atan2(Y, X)
M_XR    = $0420
M_YR    = $0422
M_ANG   = $0424
M_LEN   = $0426     ;                      R  LEN = sqrt(X^2+Y^2)
M_VER   = $042F     ;                      R  $A2

M_ID_V1  = $A1
M_VER_V2 = $A2

MCMD_CLR = 1
MCMD_ADD = 2
MCMD_SUB = 3
MCMD_N   = 4

; Angles are binary: $10000 = a full turn, $4000 = a quarter.
; Read M_RND with LDA abs only: read-modify-write instructions and
; page-crossing indexed reads step the generator more than once.
