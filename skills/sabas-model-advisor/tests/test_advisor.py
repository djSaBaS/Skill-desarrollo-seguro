"""Deterministic advisory contract tests."""
import sys
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from advisor import advise


class AdvisorTests(unittest.TestCase):
    """Verify core decisions without network or paid inference."""

    def test_decisions(self):
        # Supply measured fixture data, not real model claims.
        low = dict(assistant="test", name="low", available=True, capacity=2, cost=1)
        high = dict(assistant="test", name="high", available=True, capacity=5, cost=4)
        today = date.today().isoformat()
        # Exercise the main policy and uncertainty branches.
        cases = [
            (1, low, [high], {}, "continue"),
            (1, high, [low], {}, "pause"),
            (5, low, [high], {}, "pause"),
            (1, None, [low], {}, "uncertain"),
            (1, high, [low], {"override": True}, "continue"),
            (1, high, [low], {"policy": "DISABLED"}, "continue"),
            (1, high, [low], {"policy": "PERFORMANCE"}, "continue"),
            (1, high, [low], {"policy": "ECO"}, "pause"),
            (1, high, [low], {"critical": True}, "continue"),
            (5, low, [], {}, "uncertain"),
        ]
        # Isolate each scenario so failures identify the offending case.
        for level, current, candidates, options, expected in cases:
            with self.subTest(level=level, options=options, expected=expected):
                critical = options.get("critical", False)
                kwargs = {k: v for k, v in options.items() if k != "critical"}
                result = advise(dict(level=level, critical=critical), current,
                                candidates, reviewed=today, **kwargs)
                self.assertEqual(expected, result["action"])

    def test_stale_catalog(self):
        # Missing verification never triggers a model change.
        self.assertEqual("uncertain", advise({"level": 1}, None, [])["action"])
