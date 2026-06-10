"""Pure gate decision for the music-asset QC pipeline.

Code decides PASS/FAIL from the judge's scores + critical violations. The model's own
"verdict" field is advisory and deliberately ignored here, so the bar is enforced in code,
not by the model's mood. See RUBRIC.md for the standard.
"""

# Tunable bar (keep in sync with RUBRIC.md).
OVERALL_MIN = 7.0
DIMENSION_FLOOR = 5
DIMENSIONS = ("aesthetic_match", "composition", "brand_thread", "craft", "mood_fidelity")


def decide(verdict, overall_min=OVERALL_MIN, dimension_floor=DIMENSION_FLOOR):
    """Return (passed: bool, reasons: list[str]) for a parsed judge verdict dict.

    A candidate PASSES only when every condition holds:
      - no critical violations
      - every known dimension >= dimension_floor
      - overall >= overall_min
    Missing/garbled fields fail closed (cannot pass on absent data).
    """
    reasons = []

    if not isinstance(verdict, dict):
        return False, ["verdict is not an object (judge output unparseable)"]

    violations = verdict.get("critical_violations") or []
    if not isinstance(violations, list):
        violations = [str(violations)]
    for v in violations:
        if str(v).strip():
            reasons.append(f"critical violation: {v}")

    dims = verdict.get("dimensions")
    if not isinstance(dims, dict):
        reasons.append("missing dimensions block")
        dims = {}

    for name in DIMENSIONS:
        score = dims.get(name)
        if not isinstance(score, (int, float)):
            reasons.append(f"{name}: no score")
            continue
        if score < dimension_floor:
            reasons.append(f"{name} below floor ({score} < {dimension_floor})")

    overall = verdict.get("overall")
    if not isinstance(overall, (int, float)):
        reasons.append("overall: no score")
    elif overall < overall_min:
        reasons.append(f"overall below bar ({overall} < {overall_min})")

    passed = len(reasons) == 0
    return passed, reasons
