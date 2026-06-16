# WHITEPAPER v0.6 Line-to-Constitution Audit

Date: 2026-06-16
Scope: `WHITEPAPER.md` after C1_09 draft rewrite, flowchart restoration, hierarchy/flowchart-order amendment, and final recursive constitutional repair pass.
Auditor: Codex primary pass; restored-flow clean-context auditor result; 2026-06-16 attached conditional-pass auditor note; 2026-06-16 final recursive constitutional verdict.

## Sources

- `constitution/constitution.md`
- `ADR.md` section `ADR-019 Two-Scale Sovereign Kernel`
- `research/R_v06_directive.md`
- `MANIFESTO.md`
- `HARNESS.md`
- `contracts/README.md`
- `scripts/predicates/audit_whitepaper_v06.sh`
- Phase B gate requirements listed in `WHITEPAPER.md`

## Method

Each whitepaper section was checked for:

1. Direct constitutional anchor.
2. v0.6 directive or ADR-019 anchor.
3. Runtime/app boundary honesty.
4. Predicate/Veto/RiskFinding channel separation.
5. Macro/Micro scale separation.
6. No claim that a future runtime capability is already complete.
7. v0.5 load-bearing flowcharts preserved as v0.6 protocol views, not silently removed.

## Line-to-Constitution Map

| WHITEPAPER.md lines | Claim area | Constitutional anchor | v0.6 anchor | Audit result |
|---:|---|---|---|---|
| 1-17 | v0.6 certification status, root constitution hierarchy, no constitution edit | Art. V.1.1 and V.3: constitution is highest truth and sudo target | latest auditor hierarchy repair | PASS |
| 21-32 | one-sentence product thesis and Micro/Macro split | Art. 0.2 tape canonical; Art. I predicate discipline | ADR-019 A-B; directive §1-2 | PASS |
| 36-49 | version lineage and four design questions | Art. III.2 context shielding; Art. V meta architecture | directive §1 and §6 | PASS |
| 53-67 | anti-Oreo top/bottom whitebox, middle blackbox | Art. I quantization; Art. II broadcast; Art. III shielding | MANIFESTO M1-M8 | PASS |
| 71-84 | Art. 0 product interpretation, Q_t caveat, Path A/B/C debt | Art. 0.1-0.4, especially Art. 0.2 and 0.4 | latest auditor Art. 0.4 repair | PASS |
| 88-106 | Two-Scale Sovereign Kernel and `accepted_head_t == HEAD_t^micro` | Art. 0.2; Art. 0.4; Art. IV Q_t state loop | ADR-019 A-H; latest auditor Q_t alias repair | PASS |
| 110-123 | twelve v0.6 invariants | Art. 0.2; Art. I.1; Art. V.1.3 | directive §3 I1-I12; latest auditor order repair | PASS |
| 127-141 | state, evidence, failure, channel separation | Art. 0.2 failure as tape state; Art. I.1 predicate; Art. V.1.3 Veto-AI | directive I2, I6, §6 drift-lock | PASS |
| 145-160 | approval bytes and signature sovereignty | Art. V.1.1 human constitution root; Art. IV boot trust root | ADR-019 F; latest auditor byte-equivalence repair | PASS |
| 164-179 | macro merge gate and provenance routing | Art. I predicate; Art. II signal; Art. III shielding against false authority | ADR-019 B-E; directive I4-I9 | PASS |
| 183-191 | runtime/app boundary | Art. 0.2 source-of-truth discipline; Art. 0.4 substrate caveat | ADR-019 G; directive I11 | PASS |
| 195-209 | Software 3.0 UI as evidence projection and scale-labeled badges | Art. III.2 context shielding; Art. IV projection from state | latest auditor UI scale repair | PASS |
| 213-233 | roles: Facilitator, Meta, ArchitectAI, Veto-AI, Worker | Art. V.1.1-V.1.3 | latest auditor ArchitectAI ratification repair | PASS |
| 237-251 | protocol-native boundary and credential material rule | Art. III shielding; Art. V meta architecture | contracts/README.md; latest auditor credential repair | PASS |
| 255-261 | market as signal, not truth | Art. II.2 price signal; Art. I predicate separation | MANIFESTO market claim guard; latest auditor PPUT repair | PASS |
| 265-524 | boot/run flow, Flowchart Interface Contract, six Mermaid charts | Art. IV boot; Art. 0.2 reconstructibility; Art. 0.4 Q_t | final recursive auditor VETO repairs | PASS |
| 528-543 | non-negotiables, including diagram preservation, no pre-auth irreversible Macro action, no constitutional broadcast | Combined Art. 0-V hard constraints | latest auditor §15 repairs | PASS |
| 547-577 | roadmap, Phase B gates, Art. 0.4 substrate honesty | Art. 0.4 explicitly pending substrate path | latest auditor gate-list and Phase B/C repair | PASS |
| 581-604 | line-to-constitution summary and certification audit requirement | Art. III.2 progressive disclosure | final recursive auditor E-3 repair | PASS |
| 608-614 | closing thesis | Art. I-III anti-Oreo; Art. 0.2 tape memory | directive core model | PASS |

## High-Risk Individual Lines

| WHITEPAPER.md line | Risk checked | Result |
|---:|---|---|
| 5-15 | Could make whitepaper outrank the root constitution | PASS: root `constitution/constitution.md` is explicitly founding law and wins every conflict |
| 17 | Could claim unimplemented or absent sources as landed facts | PASS: unlanded or ungated sources must be marked draft / pending adoption |
| 84 | Could overclaim Art. 0.4 substrate completion or soften Phase E Path B | PASS: line says app does not claim full runtime substrate and Phase E gate forces Path B unless sudo-amended |
| 96 | Could silently replace root `HEAD_t` with app vocabulary | PASS: line aliases `accepted_head_t == HEAD_t^micro` |
| 102 | Could treat Git hash as ChainTape identity | PASS: line explicitly rejects this |
| 117 | Could encode unsafe universal ordering | PASS: invariant now requires gates before irreversible Macro action and failure append on every failure |
| 158 | Could let signed visible bytes drift from consumed gate bytes | PASS: line pins `ApprovalCard.canonical_bytes` to hash/sign/gate/replay bytes |
| 177 | Could equate CI green with sovereign pass | PASS: line explicitly rejects this |
| 189 | Could let app become truth | PASS: line explicitly says app cannot become truth |
| 225 | Could grant ArchitectAI broad schema/trust-root mutation without ratification | PASS: line requires ratification/migration/fixture/gate evidence for sensitive classes |
| 280 | Could allow private UI/agent/cache state to cross flowchart boundaries | PASS: line allows only declared sources and typed Micro/external Macro event discipline |
| 306-319 | Could leave flowchart event labels informal instead of protocol events | PASS: additional internal event table defines loop-local event types |
| 405-411 | Could execute generic irreversible external action after human signature but before Micro predicate gate | PASS: `ExternalActionAuthorization` and `MICROEXT` precede external action |
| 433-446 | Could perform irreversible GitHub merge before Micro authorization | PASS: `MacroMergeAuthorization` and Micro predicate/approval validation precede merge |
| 447-452 | Could accept Macro merge receipt without consistency predicate | PASS: receipt must match prior `MacroMergeAuthorization`; mismatch appends failure |
| 490-492 | Could broadcast constitutional/substrate proposals as active artifacts | PASS: proposals enter `HALT_CONSTITUTIONAL_PENDING`, not `BCAST` |
| 542-543 | Could repeat pre-auth Macro action or constitutional broadcast | PASS: both are explicit non-negotiables |
| 604 | Could claim audit certification without committed audit file | PASS: audit MUST be maintained and committed with whitepaper before adoption |

## Primary Pass Violations

The restored primary pass found no constitutional violations at its then-current
scope. The later recursive constitutional audit found two additional hard VETOs
and three engineering/certification defects in the physical text. Those later
findings are recorded below and repaired in the current `WHITEPAPER.md`.

One non-constitutional process/harness violation was found in the prior C1_09
draft: the v0.5 Mermaid flowcharts were load-bearing architectural artifacts,
but the rewrite deleted them and the atom predicates did not detect the loss.
That violation is fixed in `WHITEPAPER.md` lines 265-524 and prevented by the
updated atom predicates and non-negotiables.

## Flowchart Restoration Audit

| Requirement | Evidence | Result |
|---|---|---|
| Restore v0.5 four-loop operating-flow architecture | Six `mermaid` blocks now cover overview, Boot, Legislation, Execution, Meta, and Attention/Morning Ritual | PASS |
| Update charts to v0.6 two-scale model | Execution chart separates Micro Tick, Macro Boundary, pre-merge `MacroMergeAuthorization`, and post-merge `MacroMergeReceiptAnchor` | PASS |
| Cross-chart arrows are typed events | `SystemConstitutionAccepted`, `ProjectReady`, `SignedDecision`, `ArchitectureGapObserved`, `WhiteboxArtifactActivated`, and other events are explicit | PASS |
| GitHub merge is not Micro identity | Merge is labeled external Macro action only; Micro authorization and approval-byte validation happen before merge | PASS |
| Failure appends remain unconditional | Budget, predicate, signature reject, and stop-loss paths append failure evidence and keep `accepted_head` unchanged | PASS |

## Latest Auditor Comment Amendment

Source: attached 2026-06-16 auditor comment beginning "WHITEPAPER v0.6 Constitutional Audit".

Blocking repairs applied:

| Auditor finding | WHITEPAPER.md repair | Result |
|---|---:|---|
| Legal hierarchy conflicted with top app charter status | 5-17 | PASS |
| `accepted_head_t` silently replaced root `HEAD_t` | 96, 275-278 | PASS |
| Execution flow merged GitHub before Micro authorization | 433-446 | PASS |
| Constitutional/substrate proposals broadcast as activation | 490-492 | PASS |
| §17 audit-file wording overclaimed certification state | 604 | PASS |

Remaining implementation gap:

- The whitepaper now names required certification gates in lines 553-565, but
  those gate scripts are Phase B work. This amendment does not claim they already
  exist or pass.

## Final Recursive Constitutional Audit Repairs

Source: final 2026-06-16 recursive constitutional verdict supplied by the user.

The final recursive verdict reported that the physical text still had two
constitutional VETOs and three engineering findings. Current repairs:

| Finding | WHITEPAPER.md repair | Result |
|---|---:|---|
| VETO-1: generic irreversible external action path could run after H4 signature without Micro predicate gate | 405-411 | PASS |
| VETO-2: Macro merge receipt anchor could flow to GC without receipt consistency predicate | 447-452, 473 | PASS |
| E-1: flowchart event labels missing from event table | 306-319 | PASS |
| E-2: Art. 0.4 Path B softened as default/approximation | 84 | PASS |
| E-3: audit-file claim used present-tense evidence language | 604 | PASS |

Current residual certification boundary:

- Text-level constitutional repairs are complete for the two auditor notes.
- Repository adoption still requires committing this audit artifact together with
  `WHITEPAPER.md`.
- Phase B machine audit scripts remain charter requirements and are not claimed
  as implemented in this pass.

## Incident Review

Root cause:

- The previous rewrite optimized for prose-level constitutional correction and
  line-to-constitution mapping, but it treated the old v0.5 flowcharts as
  expendable text instead of architectural artifacts.
- The atom predicates were underspecified: they checked title, core v0.6 phrases,
  audit file existence, and shipgate, but did not check Mermaid block count,
  flowchart interface contract, typed event names, or v0.5 artifact preservation.
- The clean-context auditor was scoped to constitutional violations and boundary
  drift. It was not instructed to compare against v0.5 for lost design artifacts.

Harness improvement:

- Added C1_09 predicates requiring at least five Mermaid blocks, `Flowchart
  Interface Contract`, `SystemConstitutionAccepted`, `MacroArtifactAnchor`, and
  this Incident Review.
- Added whitepaper non-negotiable #11: flowcharts are protocol views and every
  cross-loop arrow must name a typed ChainTape event.
- Added whitepaper non-negotiable #12: future rewrites must preserve and update
  load-bearing diagrams unless the atom explicitly ratifies removal.
- Future whitepaper edits must run a preservation diff against the previous
  version before final audit, specifically checking diagram count, section
  headings, tables, and named architectural artifacts.

## Prior Clean-Context Auditor Result

Verdict: PASS for the restored-flow version before the latest hierarchy and
flow-order amendment.

Read-only clean-context audit of the restored-flow whitepaper found no blocking
constitutional or directive violations. The auditor specifically checked that
v0.5-style operating flowcharts are present, that the Flowchart Interface
Contract exists, that the diagrams use typed ChainTape events, and that GitHub
artifacts remain Macro artifacts rather than Micro ChainTape nodes.

| Check | WHITEPAPER.md lines | Result |
|---|---:|---|
| v0.5-style operating flowcharts preserved | restored-flow draft | PASS |
| Flowchart Interface Contract exists | restored-flow draft | PASS |
| Two-scale model reflected | restored-flow draft | PASS |
| GitHub artifacts not Micro nodes | restored-flow draft | PASS |
| Failure appends evidence; accepted_head unchanged | restored-flow draft | PASS |
| Macro merge requires full gate | restored-flow draft | PASS |
| Approval/SignedDecision binds canonical bytes | restored-flow draft | PASS |
| Meta/protocol changes gated by Veto/signature/ratification | restored-flow draft | PASS |

Non-blocking risks from the restored clean-context audit:

- The Flowchart Interface Contract is stated in the whitepaper, but there is no
  machine predicate yet that verifies every Mermaid cross-loop edge has a
  matching typed event, schema, and replay rule. This is deferred to Phase B's
  flow edge event registry and schema package.
- Phase B/C still need implementation work for scale/domain, MacroAnchor,
  approval byte equivalence, provenance routing, dual cursor facades, and replay
  reconstruction. The whitepaper does not claim those runtime gates are complete.
- Art. 0.4 substrate fidelity remains a known future decision. The whitepaper
  handles this honestly as a roadmap item, not a solved runtime fact.
