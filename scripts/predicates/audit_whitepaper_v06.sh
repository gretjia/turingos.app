#!/usr/bin/env bash
# audit_whitepaper_v06.sh — mechanical recursive-audit predicate for WHITEPAPER v0.6
# "Two-Scale Sovereign Kernel Correction" (atom A1_14_whitepaper_v06).
#
# Spec: research/R_v06_directive.md §七 (12 invariants). This script enforces the
# GREP-ABLE invariants (1/2/5/6/10/11) plus the spine anchors that make the
# two-scale correction mechanically checkable. The SEMANTIC invariants
# (3/4/7/8/9/12) are not fully decidable by grep and are audited by an
# independent clean-context agent per the atom card; this script asserts their
# load-bearing textual anchors so drift on them is at least surfaced.
#
# Output domain {PASS, FAIL} (red-line 4: predicates are {0,1}; subjective
# findings go to RiskFinding, never here). Fail-closed: missing file = FAIL.
set -uo pipefail
cd "$(dirname "$0")/../.."

WP="WHITEPAPER.md"
FAIL=0
pass() { printf '[PASS] %s\n' "$1"; }
bad()  { printf '[FAIL] %s\n' "$1"; FAIL=1; }

if [ ! -f "$WP" ]; then
  echo "[FAIL] $WP not found (fail-closed)"; exit 1
fi

# --- MUST_ABSENT: v0.5 scale-conflation strings that v0.6 must have removed ----
# label::pattern (fixed-string grep -F). Any hit = the old defect survived.
absent() {
  local label="$1"; shift
  local pat="$1"
  if grep -Fq -- "$pat" "$WP"; then
    bad "ABSENT[$label]: forbidden v0.5 string still present -> «$pat»"
  else
    pass "ABSENT[$label]: «$pat» removed"
  fi
}

# inv1: HEAD_t must not be defined as a GitHub merge commit SHA anchor
absent "inv1-headt-mergesha"      "merge commit SHA 锚点"
absent "inv1-headt-anchor-7.3"    "merge SHA 锚定 HEAD"
absent "inv1-headt-anchor-13.4"   "merge 后锚定 HEAD"
absent "inv1-headt-record"        "记录为 HEAD_{t+1}"
# inv2: wtool must not equal git commit/merge
absent "inv2-wtool-gitcommit"     "tape 追加 + git commit/merge"
# inv10: Reward formula must not contain predicate pass / user approval terms
absent "inv10-reward-goodhart"    "Reward = predicate pass + CI signal + user approval"
# inv11: ExternalAgentAdapter must not call Git the public/ChainTape substrate
absent "inv11-git-public-base"    "Git 是首选公共底座"

# --- MUST_PRESENT: v0.6 spine anchors -----------------------------------------
present() {
  local label="$1"; shift
  local pat="$1"
  if grep -Fq -- "$pat" "$WP"; then
    pass "PRESENT[$label]: «$pat»"
  else
    bad "PRESENT[$label]: required v0.6 anchor MISSING -> «$pat»"
  fi
}

# version + title
present "ver-v06"            "v0.6"
present "title-two-scale"    "Two-Scale Sovereign Kernel Correction"
# inv5: core theorem — GitHub is macro substrate, ChainTape is sovereign micro-ledger
present "thm-microledger"    "Internal ChainTape is the sovereign micro-ledger"
present "thm-macrosubstrate" "macro execution substrate"
present "inv5-macro-artifact" "macro artifact"
# inv1: HEAD_t = internal accepted-world pointer; project git is separate
present "inv1-accepted-ptr"  "internal accepted-world pointer"
present "inv1-project-head"  "project_git_head"
# dual cursors (inv3/inv4 anchors): tape_tip advances on failure; accepted_head gated
present "cursor-tape-tip"    "tape_tip"
present "cursor-accepted"    "accepted_head"
# inv2: wtool = internal bus.append
present "inv2-bus-append"    "bus.append"
# inv8: flowchart interface contract section exists
present "inv8-contract-sec"  "7.0.1 Flowchart Interface Contract"
present "inv8-typed-event"   "event_type"
# inv6 + inv7: §8 two-scale equation with micro tick AND macro boundary + approval gate
present "inv6-micro-tick"    "Micro Tick"
present "inv6-macro-boundary" "Macro Boundary"
present "inv7-pp-macro"      "Πp_macro"
present "inv7-merge-allowed" "macro_merge_allowed"
# inv9: approval integrity law (signed bytes == downstream predicate bytes)
present "inv9-approval-law"  "Approval Integrity Law"
# inv10: §11 reward split into hard gates vs ranking
present "inv10-hard-gates"   "Hard gates"
# M4: four-level provenance
present "prov-repo-level"    "REPO_LEVEL"
present "prov-outside-gov"   "OUTSIDE_GOVERNANCE"
# inv11: macro interoperability substrate wording
present "inv11-macro-interop" "macro interoperability substrate"
# inv12: roadmap M1 contains minimal sovereign kernel
present "inv12-min-kernel"   "Minimal Sovereign Kernel"

# --- §8 structural co-occurrence: both scales in the kernel section -----------
# Extract §8 (from "## 8." to the next "## 9.") and require both scale tokens.
sec8=$(awk '/^## 8\. /{f=1} /^## 9\./{f=0} f' "$WP")
if printf '%s' "$sec8" | grep -Fq "Micro Tick" && printf '%s' "$sec8" | grep -Fq "Macro Boundary"; then
  pass "inv6-sec8-both-scales: §8 kernel shows BOTH micro tick and macro boundary"
else
  bad "inv6-sec8-both-scales: §8 kernel must contain BOTH 'Micro Tick' and 'Macro Boundary'"
fi

# --- §19 non-negotiables gained the two new invariants ------------------------
sec19=$(awk '/^## 19\./{f=1} /^## 20\./{f=0} f' "$WP")
if printf '%s' "$sec19" | grep -Eq "two-scale|两尺度|micro-ledger|macro 执行" \
   && printf '%s' "$sec19" | grep -Eq "Flowchart Interface Contract|图间连接契约|过缝事件"; then
  pass "inv-19: §19 added two-scale invariant + flowchart interface contract"
else
  bad "inv-19: §19 must add the two-scale invariant AND the flowchart interface contract clause"
fi

echo "----------------------------------------"
if [ "$FAIL" -eq 0 ]; then
  echo "audit_whitepaper_v06: PASS (mechanical invariants 1/2/5/6/10/11 + spine anchors)"
  exit 0
else
  echo "audit_whitepaper_v06: FAIL (drift from research/R_v06_directive.md §七)"
  exit 1
fi
