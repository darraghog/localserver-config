#!/usr/bin/env python3
"""Unit tests for scripts/check-metric-identity.py.

Usage: python3 -m unittest discover -s tests -p 'test_*.py'
"""
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("check_metric_identity", ROOT / "scripts" / "check-metric-identity.py")
cmi = importlib.util.module_from_spec(_spec)
sys.modules["check_metric_identity"] = cmi
_spec.loader.exec_module(cmi)

MODEL = {
    "ApplicationService": [{"id": "as_a"}],
    "Node": [{"id": "n_host"}],
}


def job(labels, **extra):
    return {"scrape_configs": [{"job_name": "j", "static_configs": [{"targets": ["t:1"], "labels": labels}], **extra}]}


class CheckIdentity(unittest.TestCase):
    def test_service_and_entity_are_accepted(self):
        self.assertEqual(cmi.check(job({"service": "as_a"}), MODEL), [])
        self.assertEqual(cmi.check(job({"entity": "n_host"}), MODEL), [])

    def test_missing_label_is_rejected(self):
        self.assertEqual(len(cmi.check(job({}), MODEL)), 1)

    def test_both_labels_are_rejected(self):
        self.assertEqual(len(cmi.check(job({"service": "as_a", "entity": "n_host"}), MODEL)), 1)

    def test_service_must_be_an_application_service(self):
        # n_host is in the model, but it is not an application service.
        self.assertEqual(len(cmi.check(job({"service": "n_host"}), MODEL)), 1)

    def test_unknown_ids_are_rejected(self):
        self.assertEqual(len(cmi.check(job({"service": "as_nope"}), MODEL)), 1)
        self.assertEqual(len(cmi.check(job({"entity": "n_nope"}), MODEL)), 1)

    def test_relabel_replacements_are_checked(self):
        bad = job({"entity": "n_host"}, metric_relabel_configs=[{"target_label": "entity", "replacement": "ts_nope"}])
        self.assertEqual(len(cmi.check(bad, MODEL)), 1)

    def test_unverifiable_discovery_is_rejected(self):
        cfg = {"scrape_configs": [{"job_name": "j", "file_sd_configs": [{"files": ["x"]}]}]}
        self.assertEqual(len(cmi.check(cfg, MODEL)), 1)

    def test_the_real_config_conforms(self):
        prom = yaml.safe_load(cmi.PROMETHEUS.read_text())
        model = yaml.safe_load(cmi.MODEL.read_text())
        self.assertEqual(cmi.check(prom, model), [])


if __name__ == "__main__":
    unittest.main()
