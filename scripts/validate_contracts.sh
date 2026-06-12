#!/usr/bin/env bash
# Contracts + fixtures structural validation (repo law, no Claude dependency).
# Honest scope: strict SUBSET of JSON Schema (type/required/properties/enum/const/pattern/minimum).
# Full Draft 2020-12 validation arrives with the Rust daemon (serde+schemars).
set -u
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, re, sys, glob, os

FAIL = []
def ok(name): print("[PASS] %s" % name)
def bad(name, detail):
    print("[FAIL] %s - %s" % (name, detail)); FAIL.append(name)

def validate(inst, schema, path="$"):
    errs = []
    t = schema.get("type")
    if t == "object":
        if not isinstance(inst, dict): return ["%s: expected object" % path]
        for r in schema.get("required", []):
            if r not in inst: errs.append("%s: missing required field %r" % (path, r))
        for k, sub in schema.get("properties", {}).items():
            if k in inst: errs += validate(inst[k], sub, path + "." + k)
        return errs
    if t == "integer":
        if not isinstance(inst, int) or isinstance(inst, bool): return ["%s: expected integer" % path]
        if "minimum" in schema and inst < schema["minimum"]: errs.append("%s: below minimum" % path)
    if t == "string":
        if not isinstance(inst, str): return ["%s: expected string" % path]
        if "pattern" in schema and not re.search(schema["pattern"], inst):
            errs.append("%s: pattern mismatch %r" % (path, schema["pattern"]))
    if t == "boolean" and not isinstance(inst, bool): return ["%s: expected boolean" % path]
    if "enum" in schema and inst not in schema["enum"]: errs.append("%s: %r not in enum" % (path, inst))
    if "const" in schema and inst != schema["const"]: errs.append("%s: %r != const %r" % (path, inst, schema["const"]))
    return errs

schemas = {}
for f in sorted(glob.glob("contracts/*.schema.json")):
    try:
        schemas[os.path.basename(f)] = json.load(open(f))
        ok("schema well-formed: %s" % f)
    except Exception as e:
        bad("schema well-formed: %s" % f, str(e))

env = schemas.get("event_stream.schema.json")
sub_map = {  # kind -> (payload key, schema file)
    "PredicateResult": [("result", "predicate_result.schema.json")],
    "SignatureVerified": [("receipt", "signature_receipt.schema.json")],
    "SignatureRejected": [("receipt", "signature_receipt.schema.json")],
    "ProposalSubmitted": [("receipt", "signature_receipt.schema.json")],
    "RatificationProposed": [("ratification", "ratification_payload.schema.json")],
    "RatificationSigned": [("ratification", "ratification_payload.schema.json"),
                            ("receipt", "signature_receipt.schema.json")],
}
ALL_TRUST = set(env["properties"]["trust_state"]["enum"]) if env else set()

for f in sorted(glob.glob("fixtures/event_streams/*.jsonl")):
    errs, seqs, ids, seen_trust = [], [], set(), set()
    for n, line in enumerate(open(f), 1):
        line = line.strip()
        if not line: continue
        try: ev = json.loads(line)
        except Exception as e:
            errs.append("line %d: bad JSON (%s)" % (n, e)); continue
        if env: errs += ["line %d: %s" % (n, e) for e in validate(ev, env)]
        seqs.append(ev.get("seq")); ids.add(ev.get("event_id")); seen_trust.add(ev.get("trust_state"))
        for key, sf in sub_map.get(ev.get("kind", ""), []):
            sub = (ev.get("payload") or {}).get(key)
            if sub is None: errs.append("line %d: kind %s requires payload.%s" % (n, ev.get("kind"), key))
            elif sf in schemas: errs += ["line %d payload.%s: %s" % (n, key, e) for e in validate(sub, schemas[sf])]
    if seqs != sorted(set(seqs)): errs.append("seq not strictly increasing")
    if len(ids) != len(seqs): errs.append("event_id not unique")
    if "p2_identity_states" in f and ALL_TRUST - seen_trust:
        errs.append("trust states not covered: %s" % sorted(ALL_TRUST - seen_trust))
    if errs: bad("fixture: %s" % f, "; ".join(errs[:6]))
    else: ok("fixture: %s (%d events)" % (f, len(seqs)))

# --- sprint0 standalone fixtures (fixtures/sprint0/*.fixture.json) -----------
# Each file is named <schema_stem>.fixture.json and validated against
# contracts/<schema_stem>.schema.json using the same structural-subset validator.
sprint0_map = {
    "tape_node":            "tape_node.schema.json",
    "approval_envelope":    "approval_envelope.schema.json",
    "capability_manifest":  "capability_manifest.schema.json",
    "work_order_package":   "work_order_package.schema.json",
    "model_call":           "model_call.schema.json",
    "failure_node":         "failure_node.schema.json",
    "merge_dossier":        "merge_dossier.schema.json",
}
for stem, sf in sorted(sprint0_map.items()):
    fpath = "fixtures/sprint0/%s.fixture.json" % stem
    if sf not in schemas:
        bad("sprint0 fixture: %s" % fpath, "schema %s not loaded" % sf); continue
    try:
        inst = json.load(open(fpath))
    except Exception as e:
        bad("sprint0 fixture: %s" % fpath, "bad JSON: %s" % e); continue
    errs = validate(inst, schemas[sf])
    if errs: bad("sprint0 fixture: %s" % fpath, "; ".join(errs[:6]))
    else: ok("sprint0 fixture: %s" % fpath)

print("validate_contracts: %s (structural-subset validator)" % ("FAIL" if FAIL else "PASS"))
sys.exit(1 if FAIL else 0)
PY
