#!/usr/bin/env python3
"""Check that every scrape target says what it describes.

Every series Grafana shows must be tied to the architecture model, with exactly one of:
  service  an ApplicationService id (as_*), for what an application exposes
  entity   any other id in architecture/model.yaml (n_*, ts_*, ...), for what no application
           service owns: the host, the reverse proxy, systemd

This is the static half, run by the deploy gate. It reads compose/prometheus/prometheus.yml and
fails if a scrape target lacks the label, carries both, or names an id the model does not have.
scripts/check-monitoring.sh is the runtime half (live series and dashboard queries).

Usage: python3 scripts/check-metric-identity.py
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required:  pip install pyyaml  (or apt install python3-yaml)")

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "architecture" / "model.yaml"
PROMETHEUS = ROOT / "compose" / "prometheus" / "prometheus.yml"
IDENTITY = ("service", "entity")


def model_ids(model: dict) -> tuple[set[str], set[str]]:
    """Return (application service ids, every id in the model)."""
    everything: set[str] = set()
    for value in model.values():
        if isinstance(value, list):
            everything.update(e["id"] for e in value if isinstance(e, dict) and "id" in e)
    services = {e["id"] for e in model.get("ApplicationService", [])}
    return services, everything


def check_value(where: str, label: str, value: object, services: set[str], everything: set[str],
                errors: list[str]) -> None:
    if label == "service" and value not in services:
        errors.append(f"{where}: service={value!r} is not an ApplicationService in the model")
    elif label == "entity" and value not in everything:
        errors.append(f"{where}: entity={value!r} is not an id in the model")


def check_relabels(where: str, rules: list, services: set[str], everything: set[str],
                   errors: list[str]) -> None:
    for rule in rules or []:
        label = rule.get("target_label")
        if label in IDENTITY:
            check_value(where, label, rule.get("replacement"), services, everything, errors)


def check(prometheus: dict, model: dict) -> list[str]:
    services, everything = model_ids(model)
    errors: list[str] = []
    for job in prometheus.get("scrape_configs", []):
        name = job.get("job_name", "?")
        static = job.get("static_configs")
        if not static:
            errors.append(f"job {name}: only static_configs can be checked; "
                          "add a check here before using another discovery mechanism")
            continue
        for i, entry in enumerate(static):
            where = f"job {name} target {', '.join(entry.get('targets', [])) or i}"
            labels = entry.get("labels") or {}
            present = [k for k in IDENTITY if k in labels]
            if len(present) != 1:
                errors.append(f"{where}: needs exactly one of {IDENTITY}, has {present or 'neither'}")
                continue
            check_value(where, present[0], labels[present[0]], services, everything, errors)
        check_relabels(f"job {name} relabel_configs", job.get("relabel_configs"), services, everything, errors)
        check_relabels(f"job {name} metric_relabel_configs", job.get("metric_relabel_configs"),
                       services, everything, errors)
    return errors


def main() -> int:
    errors = check(yaml.safe_load(PROMETHEUS.read_text()), yaml.safe_load(MODEL.read_text()))
    for e in errors:
        print(f"[metric-identity] ERROR {e}", file=sys.stderr)
    if errors:
        return 1
    print("[metric-identity] every scrape target is tied to a model id")
    return 0


if __name__ == "__main__":
    sys.exit(main())
