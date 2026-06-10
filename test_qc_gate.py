"""Tests for the QC gate decision. Run: python3 -m unittest test_qc_gate -v"""
import unittest
from qc_gate import decide


def good(**over):
    v = {
        "dimensions": {"aesthetic_match": 8, "composition": 8, "brand_thread": 7,
                       "craft": 8, "mood_fidelity": 8},
        "overall": 7.8,
        "critical_violations": [],
        "verdict": "PASS",
    }
    v.update(over)
    return v


class GateTests(unittest.TestCase):
    def test_clean_pass(self):
        passed, reasons = decide(good())
        self.assertTrue(passed)
        self.assertEqual(reasons, [])

    def test_critical_violation_forces_fail_even_with_high_scores(self):
        v = good(overall=9.9, critical_violations=["baked-in text on the image"])
        passed, reasons = decide(v)
        self.assertFalse(passed)
        self.assertTrue(any("critical violation" in r for r in reasons))

    def test_low_overall_fails(self):
        passed, reasons = decide(good(overall=6.9))
        self.assertFalse(passed)
        self.assertTrue(any("overall below bar" in r for r in reasons))

    def test_one_dimension_below_floor_fails(self):
        v = good()
        v["dimensions"]["aesthetic_match"] = 4
        passed, reasons = decide(v)
        self.assertFalse(passed)
        self.assertTrue(any("aesthetic_match below floor" in r for r in reasons))

    def test_model_verdict_is_ignored_code_decides(self):
        # Model says PASS but scores are bad -> still FAIL.
        v = good(overall=3.0, verdict="PASS")
        passed, _ = decide(v)
        self.assertFalse(passed)
        # Model says FAIL but scores are good -> still PASS (code, not vibes).
        v2 = good(verdict="FAIL")
        passed2, _ = decide(v2)
        self.assertTrue(passed2)

    def test_missing_fields_fail_closed(self):
        self.assertFalse(decide({})[0])
        self.assertFalse(decide("not a dict")[0])
        self.assertFalse(decide({"dimensions": {}, "overall": 9})[0])

    def test_threshold_is_tunable(self):
        v = good(overall=6.5)
        self.assertFalse(decide(v)[0])
        self.assertTrue(decide(v, overall_min=6.0)[0])


if __name__ == "__main__":
    unittest.main()
