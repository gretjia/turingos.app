# git plumbing parser goldens (NOT turingos CLI transcripts)

Raw byte captures of `git worktree list --porcelain -z` / `git status
--porcelain=v2 -z --branch --untracked-files=normal` / `git diff --numstat -z
HEAD`, consumed by `daemon/src/snapshot.rs` unit tests as parser golden inputs.

docs/CLI_ABI.md law #7 reserves `fixtures/cli_transcripts/<command>.jsonl` for
real `turingos` CLI recordings; this `git/` subfolder is deliberately separate
so the two kinds are never conflated. Regeneration recipe lives in the A1_02
atom receipt trail (tempdir repos; absolute /tmp paths inside are inert test
strings).
