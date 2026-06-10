# TuringOS.app - Dashboard Snapshot (placeholder renderer)

projection_id: prj_slice_dashboard | schema_version: tos.app.projection.v0
derive_source: fixture_event_stream | as_of_seq: 7 | events_folded: 8
rebuild_command: bash scripts/simulate_event_stream.sh <fixture> | bash scripts/render_snapshot_placeholder.sh

## Projects
| project | canonical_path |
|---|---|
| proj_demo | /Users/zephry/code/demo |

## Worktrees
| worktree | branch | head | dirty | badge | note |
|---|---|---|---|---|---|
| wt_feature_x | feature/x | a1b2c3d | False | active | diff sha256:1f2e3d4c5b6 (+12/-2) |
| wt_main | main | a1b2c3d | False | foreign |  |

## Agent Sessions
| session | agent | state | badge |
|---|---|---|---|
| sess_0001 | agent_claude_01 | open | active |

## Proposals
| proposal | state | predicate | veto | badge |
|---|---|---|---|---|
| cand_0001 | candidate |  |  | active |

## Reconciliation
- last: seen=2 drift=0 via git_worktree_list+fs

_Badges are semantic words from docs/VISUAL_SEMANTICS.md; colors bind in the SwiftUI design-tokens phase._
