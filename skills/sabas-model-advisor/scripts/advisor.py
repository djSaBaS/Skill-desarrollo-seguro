"""Offline advisory decision engine; no shell or network access."""
from datetime import date

POLICIES = {"ECO", "BALANCED", "PERFORMANCE", "DISABLED"}


def advise(task, current, candidates, policy="BALANCED", threshold=2,
           override=False, reviewed=None, max_age=90):
    """Return an advisory decision from explicitly supplied, measured metadata."""
    # Reject malformed policy and complexity instead of guessing.
    if policy not in POLICIES or type(task["level"]) is not int or not 1 <= task["level"] <= 5:
        raise ValueError("Invalid policy or complexity")
    # Require positive thresholds.
    if type(threshold) is not int or threshold < 1:
        raise ValueError("Invalid threshold")
    # Respect explicit opt-out without waiving downstream security gates.
    if policy == "DISABLED" or override:
        return {"action": "continue", "reason": "opt-out"}
    # Avoid recommendations from unreviewed or expired data.
    if reviewed is None or not 0 <= (date.today() - date.fromisoformat(reviewed)).days <= max_age:
        return {"action": "uncertain", "reason": "catalog freshness"}
    # Derive minimum capability from risk, not just task name.
    level = max(task["level"], 4 if task.get("critical") else 1)
    # Require confirmed tools and local resource suitability.
    required = set(task.get("capabilities", []))
    def suitable(model):
        # Only explicitly available, compatible configurations qualify.
        return (model.get("available") is True and model.get("fits", True) is True
                and model["capacity"] >= level
                and required <= set(model.get("capabilities", [])))
    # Keep candidate data on the same assistant and cost scale.
    if not current or not current.get("assistant") or current.get("available") is not True:
        return {"action": "uncertain", "reason": "unknown current configuration"}
    # Restrict alternatives to confirmed configurations of this assistant.
    eligible = [m for m in candidates if m.get("assistant") == current["assistant"]
                and suitable(m)]
    # If no compatible alternative exists, report uncertainty.
    if not eligible:
        return {"action": "continue" if suitable(current) else "uncertain",
                "reason": "no confirmed alternative"}
    # Rank by internal estimates, not by invented billing figures.
    if policy == "PERFORMANCE":
        best = max(eligible, key=lambda m: (m["capacity"], -m["cost"]))
    else:
        best = min(eligible, key=lambda m: (m["cost"], -m["capacity"]))
    # Escalate whenever known capabilities are insufficient.
    if not suitable(current):
        return {"action": "pause", "reason": "insufficient", "recommended": best}
    # Use the configured threshold to avoid marginal changes.
    if policy != "PERFORMANCE" and current["cost"] - best["cost"] >= (1 if policy == "ECO" else threshold):
        return {"action": "pause", "reason": "efficiency", "recommended": best}
    # Performance mode prioritizes significant capability improvement.
    if policy == "PERFORMANCE" and best["capacity"] - current["capacity"] >= threshold:
        return {"action": "pause", "reason": "quality", "recommended": best}
    # Equivalent configurations do not interrupt the task.
    return {"action": "continue", "reason": "adequate"}
