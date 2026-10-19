NB. test_scroll_spec.ijs
NB.
NB. SPEC-MATRIX (LaOP) check of the scroll/follow-mode semantics.
NB.
NB. The follow-mode behavior is implemented TWICE: tui_handle_key
NB. (idle main loop) and tui_steer_poll (mid-LLM-call, from the
NB. spinner loop). The steer-poll copy once diverged (wheel bytes
NB. leaked into the input line and never pinned - the "follow mode
NB. is broken" bug). This test pins BOTH implementations to ONE
NB. spec matrix so that class of divergence is a checkable
NB. refinement failure, not an interactive discovery.
NB.
NB. Method: ~/projects/2026/jmethod/portable/LAOP-FOR-LLMS.md
NB.   - a SPEC is a loose boolean matrix (rows = (state,event),
NB.     cols = post-states {F=follow, P=pinned}); loose rows
NB.     (row sum > 1) are allowed outcomes.
NB.   - "PROG implements SPEC" is PROG refines SPEC, pointwise.
NB.   - total SPEC  = implementability (no dead (state,event) row)
NB.   - star PROG   = reachability: can the user always recover to F?
NB.
NB. Run from src/:  jconsole ../tests/test_scroll_spec.ijs
NB. (run_all.ijs auto-discovers test_*.ijs)

load '../src/tui.ijs'

NB. ----------------------------------------------------------------
NB. LaOP vocabulary (verbatim from LAOP-FOR-LLMS.md)
mp      =: +./ . *.                 NB. relational composition
refines =: 4 : '*./@, (x <: y)'     NB. PROG refines SPEC  ==> 1
total   =: 3 : '*./@, (0 < +/"1 y)' NB. every row has >= 1 one
det     =: 3 : '*./@, (1 >: +/"1 y)' NB. every row has <= 1 one
star    =: 3 : 0
  T =. (=/~ i. # y)
  for_i. i. # y do.
    T =. T +. y mp T
  end.
)

NB. ----------------------------------------------------------------
NB. Headless stubs (same as test_tui_newfeatures.ijs): no tty.
NB. Global (=: at top level) - inside a definition they would be
NB. locals invisible to the handlers.
puts =: ]
goxy =: ]
curs =: ]
ceol =: ]
reset =: ]
fgc =: ]
QUEUE =: 0 $ 0
keyp =: 3 : '0 < # QUEUE'
rkey =: 3 : 0
 r =. > {. QUEUE
 QUEUE =: }. QUEUE
 r
)
tui_process =: ]

NB. ----------------------------------------------------------------
NB. Harness: run one event against one handler, observe the
NB. (F, scroll) outcome. Events are delivered exactly as the real
NB. terminal delivers them:
NB.   UP   = SGR wheel-up     ESC [ < 64 ; 13 ; 5 M
NB.   DOWN = SGR wheel-down   ESC [ < 65 ; 13 ; 5 M   (x2: one tick
NB.                            may not reach bottom; DOWN is a
NB.                            reach-bottom event, fire until the
NB.                            buffer edge or 10 ticks)
NB.   L    = Ctrl-L (byte 12)
NB.   OUT  = tui_print '' (new output arrived)
NB.
NB. The buffer is prepared per-row so DOWN has room to move:
NB. 100 lines, oh = 18 (24 rows, empty input), bottom scroll = 82.

NB. state index: 0 = F (following), 1 = P (pinned)
NB. event index: 0 UP, 1 DOWN, 2 L, 3 OUT
NB. rows of SPEC: (0,F) (1,F) (2,F) (3,F) (0,P) (1,P) (2,P) (3,P)

EVUP   =: 27 91 60 54 52 59 49 51 59 53 77          NB. wheel-up
EVDOWN =: 27 91 60 54 53 59 49 51 59 53 77          NB. wheel-down
EVL    =: , 12                                        NB. Ctrl-L

NB. prep: 100-line buffer, known geometry; y = state (0=F,1=P)
prep =: 3 : 0
  TUI_LINES =: 24 [ TUI_COLS =: 80
  TUI_INPUT =: '' [ TUI_CURSOR =: 0
  TUI_OUTPUT =: < @ ('line ' , ":) " 0 i. 100
  if. 0 = y do.
    TUI_FOLLOW =: 1
    TUI_SCROLL =: 82
  else.
    TUI_FOLLOW =: 0
    TUI_SCROLL =: 70
  end.
)

NB. outcome: 1 if post-state is F (following), 0 if P.
NB. Determined by TUI_FOLLOW AND the view at bottom (a pinned view
NB. sits above bottom; following implies bottom).
isF =: 3 : 0
  (1 = TUI_FOLLOW) *. tui_at_bottom ''
)

NB. one observation: x = handler ('idle' or 'steer'), y = 'state event'
NB. returns the post-state index (0=F, 1=P); drives the real verbs.
observe =: 4 : 0
  'st ev' =. y
  prep st
  if. 'idle' -: x do.
    select. ev
      case. 0 do. QUEUE =: EVUP
      case. 1 do. QUEUE =: 5 # EVDOWN
      case. 2 do. QUEUE =: EVL
      case. do.
    end.
    NB. pop-then-dispatch, exactly as the real main loop does
    NB. (k =. rkey'' then tui_handle_key k). Peek-then-dispatch
    NB. re-feeds the ESC byte to the sequence parser, which then
    NB. mis-parses and drops the whole wheel event.
    while. keyp 0 do.
      k =. rkey ''
      tui_handle_key k
    end.
  else.
    select. ev
      case. 0 do. QUEUE =: EVUP
      case. 1 do. QUEUE =: 5 # EVDOWN
      case. 2 do. QUEUE =: EVL
      case. do.
    end.
    tui_steer_poll ''
  end.
  NB. OUT is not a key: new output arrives through tui_print
  if. 3 = ev do. tui_print 'streamed output line' end.
  -. isF ''
)

NB. build the 8x2 PROG matrix for one handler by observing all
NB. (state,event) pairs. y = handler name.
NB. Each row gets exactly ONE 1, in the observed post-state's
NB. column (writing the outcome VALUE would leave F-outcomes as
NB. 0 0, which vacuously "refines" any SPEC row).
build_prog =: 3 : 0
  m =. 8 2 $ 0
  row =. 0
  for_st. i. 2 do.
    for_ev. i. 4 do.
      post =. y observe st , ev
      m =. 1 (< row , post) } m
      row =. row + 1
    end.
  end.
  m
)

NB. ----------------------------------------------------------------
NB. SPEC. Rows: (F,UP) (F,DOWN) (F,L) (F,OUT) (P,UP) (P,DOWN)
NB. (P,L) (P,OUT). Cols: F P.
NB.
NB.   (F,UP)   -> must pin                          0 1
NB.   (F,DOWN) -> stays following                    1 0
NB.   (F,L)    -> stays following                    1 0
NB.   (F,OUT)  -> snaps to bottom, keeps following   1 0
NB.   (P,UP)   -> stays pinned                       0 1
NB.   (P,DOWN) -> LOOSE: F iff bottom reached, else P   1 1
NB.   (P,L)    -> must resume follow                 1 0
NB.   (P,OUT)  -> MUST stay pinned (the feature)     0 1
SPEC =: 8 2 $ 0 1 1 0 1 0 1 0 0 1 1 1 1 0 0 1

PASS =: 0
FAIL =: 0
check =: 3 : 0
  if. y do. PASS =: PASS + 1
  else.
    FAIL =: FAIL + 1
    smoutput 'check FAILED'
  end.
)
report =: monad define
  if. 0 = FAIL do.
    smoutput 'ALL SCROLL-SPEC TESTS PASSED'
    smoutput 'PASS'
  else.
    smoutput 'Results: ' , (": PASS) , ' passed, ' , (": FAIL) , ' failed'
    smoutput 'FAIL'
  end.
)

NB. ----------------------------------------------------------------
NB. 1. SPEC health: implementable (total), and known-loose row
NB.    (P,DOWN) has row sum 2.
t1 =: monad define
  r =. total SPEC
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: total SPEC' end.
  r =. 2 = 5 { +/"1 SPEC
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: (P,DOWN) loose' end.
)
t1 ''

NB. ----------------------------------------------------------------
NB. 2. Idle handler (tui_handle_key) refines SPEC.
NB.    PROG rows come from observations of the real verbs.
t2 =: monad define
  PROG_IDLE =: build_prog 'idle'
  r =. PROG_IDLE refines SPEC
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: idle refines SPEC' end.
  NB. every row observed exactly one outcome: deterministic
  r =. det PROG_IDLE
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: idle det' end.
)
t2 ''

NB. ----------------------------------------------------------------
NB. 3. Steer handler (tui_steer_poll) refines SPEC.
NB.    This is the copy that previously diverged (wheel bytes
NB.    leaked, never pinned). The refinement gate catches that
NB.    class as a 0 instead of an interactive bug report.
t3 =: monad define
  PROG_STEER =: build_prog 'steer'
  r =. PROG_STEER refines SPEC
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: steer refines SPEC' end.
  r =. det PROG_STEER
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: steer det' end.
  NB. both implementations observe the SAME outcome for every
  NB. (state,event) - the two-copy consistency check
  r =. PROG_IDLE -: PROG_STEER
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: idle = steer' end.
)
t3 ''

NB. ----------------------------------------------------------------
NB. 4. Liveness: from any reachable state the user can return to F
NB.    (star of the observed transitions includes the recovery
NB.    edges). PROG_STEER's post-graph over {F,P}: recovery is
NB.    P -> F via (P,L) or (P,DOWN-at-bottom).
t4 =: monad define
  NB. post-graph over abstract states: edge s->t iff some event
  NB. takes s to t. Rows 4*s+i. (i=0..3) are pre-state s; column t
  NB. holds the post-state. Extract each 4x2 block (drop THEN
  NB. take - take-then-drop yields an empty block for s=1), and
  NB. OR over its column entries.
  A =: 2 2 $ 0
  for_s. i. 2 do.
    blk =. 4 {. (4 * s) }. PROG_STEER
    for_t. i. 2 do.
      A =: (1 e. t {"1 blk) (< s , t) } A
    end.
  end.
  S =: star A
  NB. from P (index 1) F (index 0) must be reachable
  r =. 1 = (< 1 0) { S
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: P reaches F' end.
)
t4 ''

NB. ----------------------------------------------------------------
NB. 5. Leak localization demo (spec-side, no failure expected):
NB.    the leak matrix names exact (row, cell) counterexamples
NB.    when a refines check fails. Here against a KNOWN-bad prog:
NB.    the OLD broken steer behavior (wheel-up while pinned leaves
NB.    F=1... i.e. (F,UP) -> F, a spec violation).
t5 =: monad define
  BROKEN =: 8 2 $ 0
  BROKEN =: (1 (< 0 0) } BROKEN)          NB. (F,UP) -> F: wrong
  BROKEN =: (1 (< 4 1) } BROKEN)         NB. (P,UP) -> P: ok
  r =. 0 = BROKEN refines SPEC
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: broken does NOT refine' end.
  leak =: BROKEN * (-. SPEC)
  NB. (<0 0) { leak — the parenthesized index matters: bare
  NB. 1 = <0 0 { leak parses as 1 = <(0 0 { leak), boxing a
  NB. whole 2x2 matrix, which never equals 1.
  r =. 1 = (< 0 0) { leak
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: leak names the bad cell' end.
  r =. 1 = +/ , leak
  if. r do. PASS =: PASS + 1 else. FAIL =: FAIL + 1 [ smoutput 'FAIL: leak has exactly one cell' end.
)
t5 ''

report ''
exit 0
