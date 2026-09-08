#!/usr/bin/env python3
"""Unit tests for scripts/check-updates.py.

Stdlib unittest only: the server has no pytest, and a check script that can only be
tested on the authoring machine is a check script that stops being run.

Usage: python3 -m unittest discover -s tests -p 'test_*.py'
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("check_updates", ROOT / "scripts" / "check-updates.py")
cu = importlib.util.module_from_spec(_spec)
sys.modules["check_updates"] = cu
_spec.loader.exec_module(cu)


class ParseImageRef(unittest.TestCase):
    def test_splits_name_from_tag(self):
        self.assertEqual(cu.parse_image_ref("docker.io/n8nio/n8n:2.33.7"),
                         ("docker.io/n8nio/n8n", "2.33.7"))

    def test_missing_tag_means_latest(self):
        self.assertEqual(cu.parse_image_ref("docker.io/library/nginx"),
                         ("docker.io/library/nginx", "latest"))

    def test_registry_port_is_not_mistaken_for_a_tag(self):
        self.assertEqual(cu.parse_image_ref("localhost:5000/thing"),
                         ("localhost:5000/thing", "latest"))


class ShortRef(unittest.TestCase):
    def test_drops_docker_hub_boilerplate(self):
        self.assertEqual(cu.short_ref("docker.io/library/postgres:15-alpine"), "postgres:15-alpine")

    def test_keeps_other_registries_intact(self):
        self.assertEqual(cu.short_ref("ghcr.io/berriai/litellm:main-stable"),
                         "ghcr.io/berriai/litellm:main-stable")


class IsPinned(unittest.TestCase):
    def test_tags_starting_with_a_digit_are_pinned(self):
        for tag in ("2.33.7", "16-alpine", "11.8", "7.1-php8.3-apache", "3.13-slim"):
            self.assertTrue(cu.is_pinned(tag), tag)

    def test_moving_tags_are_not_pinned(self):
        for tag in ("alpine", "latest", "main-stable", "stable"):
            self.assertFalse(cu.is_pinned(tag), tag)


class TagShape(unittest.TestCase):
    def test_matches_the_same_family(self):
        shape = cu.tag_shape("7.1-php8.3-apache")
        self.assertTrue(shape.match("7.2-php8.4-apache"))
        self.assertTrue(shape.match("10.0-php8.3-apache"))

    def test_rejects_a_different_variant(self):
        shape = cu.tag_shape("7.1-php8.3-apache")
        self.assertFalse(shape.match("7.1-php8.3-fpm"))
        self.assertFalse(shape.match("7.1"))
        self.assertFalse(shape.match("latest"))

    def test_regex_metacharacters_in_a_tag_are_literal(self):
        shape = cu.tag_shape("1.2-r3")
        self.assertTrue(shape.match("1.9-r0"))
        self.assertFalse(shape.match("1x9-r0"))


class VersionKey(unittest.TestCase):
    def test_orders_numerically_not_lexically(self):
        self.assertGreater(cu.version_key("2.10.0"), cu.version_key("2.9.9"))

    def test_uses_every_numeric_run_in_the_tag(self):
        self.assertEqual(cu.version_key("7.1-php8.3-apache"), (7, 1, 8, 3))


class NewestTags(unittest.TestCase):
    def test_finds_the_highest_tag_of_the_same_shape(self):
        in_major, overall = cu.newest_tags("2.9.9", ["2.9.9", "2.10.0", "2.33.7", "latest"])
        self.assertEqual(overall, "2.33.7")

    def test_separates_a_same_major_bump_from_a_major_bump(self):
        in_major, overall = cu.newest_tags("15-alpine", ["15-alpine", "15.4-alpine", "16-alpine"])
        self.assertIsNone(in_major)
        self.assertEqual(overall, "16-alpine")

    def test_reports_a_same_major_bump_when_one_exists(self):
        in_major, overall = cu.newest_tags("11.4", ["11.4", "11.8", "12.0"])
        self.assertEqual(in_major, "11.8")
        self.assertEqual(overall, "12.0")

    def test_ignores_tags_of_another_shape(self):
        in_major, overall = cu.newest_tags("16-alpine", ["16-alpine", "17-bookworm", "99"])
        self.assertIsNone(in_major)
        self.assertIsNone(overall)

    def test_nothing_newer_reports_nothing(self):
        self.assertEqual(cu.newest_tags("2.33.7", ["2.33.7", "2.30.0"]), (None, None))


class CollectComposeImages(unittest.TestCase):
    def test_reads_images_from_the_stack_and_its_overlays(self):
        with tempfile.TemporaryDirectory() as td:
            stack = Path(td) / "n8n"
            stack.mkdir()
            (stack / "compose.yaml").write_text(
                "services:\n  n8n:\n    image: docker.io/n8nio/n8n:2.33.7\n")
            (stack / "compose.postgres.yaml").write_text(
                "services:\n  db:\n    image: docker.io/library/postgres:15-alpine\n")
            self.assertEqual(cu.collect_compose_images(stack),
                             {"docker.io/n8nio/n8n:2.33.7", "docker.io/library/postgres:15-alpine"})

    def test_a_build_only_stack_declares_no_image(self):
        with tempfile.TemporaryDirectory() as td:
            stack = Path(td) / "tic-tac-toe"
            stack.mkdir()
            (stack / "compose.yaml").write_text("services:\n  app:\n    build: .\n")
            self.assertEqual(cu.collect_compose_images(stack), set())


class CollectDockerfileImages(unittest.TestCase):
    def test_reads_base_images_and_drops_the_stage_alias(self):
        with tempfile.TemporaryDirectory() as td:
            stack = Path(td) / "weather-mcp"
            stack.mkdir()
            (stack / "Dockerfile").write_text(
                "FROM docker.io/library/python:3.13-slim AS build\n"
                "RUN true\n"
                "FROM docker.io/library/python:3.13-slim\n")
            self.assertEqual(cu.collect_dockerfile_images(stack),
                             {"docker.io/library/python:3.13-slim"})

    def test_a_reference_to_an_earlier_stage_is_not_an_image(self):
        with tempfile.TemporaryDirectory() as td:
            stack = Path(td) / "x"
            stack.mkdir()
            (stack / "Dockerfile").write_text(
                "FROM docker.io/library/python:3.13-slim AS build\n"
                "FROM build\n")
            self.assertEqual(cu.collect_dockerfile_images(stack),
                             {"docker.io/library/python:3.13-slim"})


class ModelImages(unittest.TestCase):
    MODEL = {
        "ApplicationComponent": [
            {"id": "ac-n8n", "stack": "compose/n8n",
             "image": "n8nio/n8n:2.33.7 + postgres:15-alpine"},
            {"id": "ac-tictactoe", "stack": "compose/tic-tac-toe", "image": "locally built"},
            {"id": "ac-cockpit", "stack": "(host package, not containerised)",
             "image": "distribution package"},
        ]
    }

    def test_splits_a_multi_image_component_on_the_plus(self):
        self.assertEqual(cu.model_images(self.MODEL)["n8n"], {"n8nio/n8n:2.33.7", "postgres:15-alpine"})

    def test_a_locally_built_component_declares_no_registry_image(self):
        self.assertEqual(cu.model_images(self.MODEL)["tic-tac-toe"], set())

    def test_a_component_with_no_compose_stack_is_skipped(self):
        self.assertNotIn("(host package, not containerised)", cu.model_images(self.MODEL))


class FindDrift(unittest.TestCase):
    def test_agreement_is_not_drift(self):
        self.assertEqual(
            cu.find_drift({"n8n": {"docker.io/n8nio/n8n:2.33.7"}}, {"n8n": {"n8nio/n8n:2.33.7"}}),
            [])

    def test_a_tag_the_model_disagrees_with_is_reported(self):
        drift = cu.find_drift({"n8n": {"docker.io/n8nio/n8n:2.33.7"}},
                              {"n8n": {"n8nio/n8n:2.19.5"}})
        self.assertEqual(len(drift), 1)
        self.assertIn("2.19.5", drift[0].detail)
        self.assertEqual(drift[0].stack, "n8n")

    def test_an_image_only_the_model_names_is_reported(self):
        drift = cu.find_drift({"wordpress": {"docker.io/library/wordpress:7.1-php8.3-apache"}},
                              {"wordpress": {"wordpress:7.1-php8.3-apache", "mariadb:11.8"}})
        self.assertEqual(len(drift), 1)
        self.assertIn("mariadb:11.8", drift[0].detail)

    def test_a_stack_absent_from_the_model_is_not_drift(self):
        self.assertEqual(cu.find_drift({"tls-proxy": {"docker.io/library/caddy:alpine"}}, {}), [])

    def test_a_locally_built_component_that_pulls_a_registry_image_is_drift(self):
        drift = cu.find_drift({"tic-tac-toe": {"docker.io/library/nginx:alpine"}},
                              {"tic-tac-toe": set()})
        self.assertEqual(len(drift), 1)
        self.assertIn("nginx:alpine", drift[0].detail)


class StrictExitCode(unittest.TestCase):
    """--strict is a CI signal, so "I could not check" must not read as "all current"."""

    def run_main(self, argv, tags):
        original = cu.list_registry_tags
        cu.list_registry_tags = lambda name: tags
        try:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                return cu.main(argv)
        finally:
            cu.list_registry_tags = original

    def test_an_unreachable_registry_does_not_pass(self):
        self.assertEqual(self.run_main(["--strict", "--stack", "n8n"], None), 2)

    def test_a_newer_published_tag_is_a_finding(self):
        self.assertEqual(self.run_main(["--strict", "--stack", "n8n"], ["99.99.99"]), 1)

    def test_nothing_newer_is_a_clean_run(self):
        self.assertEqual(self.run_main(["--strict", "--stack", "n8n"], []), 0)

    def test_offline_skips_the_registry_entirely(self):
        self.assertEqual(self.run_main(["--strict", "--offline", "--stack", "n8n"], None), 0)


if __name__ == "__main__":
    unittest.main()
