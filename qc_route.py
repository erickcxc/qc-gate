"""Parse a judge verdict, apply the gate, route the candidate, write the report.

Called by qc-image.sh. Reads the raw judge text from argv[1]; takes paths from env:
QC_DIR, CAND, APPROVE, REJECT, REPORTD. Exit 0 = PASS, 2 = FAIL, 1 = error.
"""
import json
import os
import re
import shutil
import sys

sys.path.insert(0, os.environ["QC_DIR"])
from qc_gate import decide  # noqa: E402


def extract_json(text):
    """Pull the JSON object out of the model text (handles stray fences/prose)."""
    text = text.strip()
    text = re.sub(r"^```(?:json)?|```$", "", text, flags=re.MULTILINE).strip()
    try:
        return json.loads(text)
    except Exception:
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            return json.loads(m.group(0))
        raise


def main():
    raw_path = sys.argv[1]
    cand = os.environ["CAND"]
    approve_dir = os.environ["APPROVE"]
    reject_dir = os.environ["REJECT"]
    report_dir = os.environ["REPORTD"]
    base = os.path.basename(cand)
    stem = os.path.splitext(base)[0]

    with open(raw_path) as f:
        raw = f.read()

    try:
        verdict = extract_json(raw)
    except Exception as e:
        # Unparseable judge output fails closed.
        verdict = {"parse_error": str(e), "raw": raw[:2000]}
        passed, reasons = False, [f"could not parse judge output: {e}"]
    else:
        passed, reasons = decide(verdict)

    report = {
        "candidate": base,
        "passed": passed,
        "gate_reasons": reasons,
        "judge": verdict,
    }
    report_path = os.path.join(report_dir, f"{stem}.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    dims = verdict.get("dimensions", {}) if isinstance(verdict, dict) else {}
    overall = verdict.get("overall") if isinstance(verdict, dict) else None

    if passed:
        dest = os.path.join(approve_dir, base)
        shutil.copy2(cand, dest)
        print(f"  PASS  overall={overall}  -> APPROVED/{base}")
        print(f"        scores: {dims}")
        print(f"        report: {report_path}")
        sys.exit(0)
    else:
        dest = os.path.join(reject_dir, base)
        shutil.copy2(cand, dest)
        print(f"  FAIL  overall={overall}  -> rejected/{base}")
        print(f"        scores: {dims}")
        for r in reasons:
            print(f"        - {r}")
        print(f"        report: {report_path}")
        sys.exit(2)


if __name__ == "__main__":
    main()
