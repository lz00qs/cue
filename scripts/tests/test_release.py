import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from urllib.parse import parse_qs, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release import (DEV_MARKER, PLATFORMS, check_source, old_dev_releases,
                     package_release, prepare_metadata, publish_release)


SHA = "abcdef012345" + "0" * 28
PUBSPEC = "name: cue\nversion: 1.0.1+2\n"


def env(ref="dev", ref_type="branch", event="push", run_number=42, windows_only=False):
    return {
        "GITHUB_SHA": SHA, "GITHUB_REF_NAME": ref, "GITHUB_REF_TYPE": ref_type,
        "GITHUB_EVENT_NAME": event, "GITHUB_RUN_NUMBER": str(run_number),
        "GITHUB_RUN_ID": "123456", "WINDOWS_ONLY": str(windows_only).lower(),
    }


class FakeGitHub:
    repository = "lz00qs/cue"

    def __init__(self, metadata):
        self.metadata = metadata
        self.calls = []
        self.assets = []
        self.history = []
        self.existing = None
        self.tag_sha = None
        self.head = SHA
        self.fail_upload = False
        self.incomplete_listing = False
        self.supersede_on_upload = False
        self.published = False

    def optional(self, path):
        if path.startswith("/releases/tags/"):
            return self.existing
        if path.startswith("/git/ref/tags/"):
            return {"object": {"type": "commit", "sha": self.tag_sha}} if self.tag_sha else None
        raise AssertionError(path)

    def releases(self):
        return iter(self.history)

    def request(self, method, path, data=None, content_type=None):
        self.calls.append((method, path, data))
        if path == "/git/ref/heads/dev":
            return {"object": {"sha": self.head}}
        if path == "/git/refs":
            self.tag_sha = data["sha"]
            return {}
        if path == "/releases/generate-notes":
            return {"body": "Changes since the previous release"}
        if path == "/releases" or path == "/releases/1" and data.get("draft"):
            self.existing = {"id": 1, "draft": True, "upload_url": "https://uploads.github.com/assets{?name}"}
            return self.existing
        if path == "/releases/1" and method == "PATCH":
            self.published = True
            return {"html_url": "https://github.com/lz00qs/cue/releases/tag/" + self.metadata["tag"]}
        if path.startswith("https://uploads.github.com/"):
            name = parse_qs(urlsplit(path).query)["name"][0]
            result = {"id": len(self.assets) + 1, "name": name, "state": "uploaded",
                      "size": len(data), "digest": "sha256:" + hashlib.sha256(data).hexdigest()}
            self.assets.append(result)
            if self.supersede_on_upload:
                self.head = "f" * 40
            if self.fail_upload:
                result["digest"] = "sha256:" + "0" * 64
            return result
        if path.startswith("/releases/assets/") and method == "DELETE":
            self.assets = [asset for asset in self.assets if asset["id"] != int(path.rsplit("/", 1)[1])]
            return None
        if path == "/releases/1/assets?per_page=100":
            return self.assets[:-1] if self.incomplete_listing else self.assets
        raise AssertionError((method, path, data))


class MetadataTests(unittest.TestCase):
    def test_both_channels_share_build_sequence_and_reruns_are_identical(self):
        dev = prepare_metadata(env(), PUBSPEC)
        stable = prepare_metadata(env("v1.0.1", "tag", run_number=43), PUBSPEC)
        self.assertTrue(dev["publish"])
        self.assertEqual(dev["tag"], "dev-1.0.1-1042-abcdef012345")
        self.assertFalse(dev["tag"].startswith("v"))
        self.assertEqual(stable["build_number"], dev["build_number"] + 1)
        self.assertEqual(stable["image_tag"], "1.0.1")
        self.assertEqual(prepare_metadata(env(), PUBSPEC), dev)

    def test_manual_dev_publishes_but_windows_and_dryrun_only_validate(self):
        self.assertTrue(prepare_metadata(env(event="workflow_dispatch"), PUBSPEC)["publish"])
        for ref, ref_type, windows in (("dev", "branch", True), ("main", "branch", True),
                                       ("v1.0.1-dryrun", "tag", False)):
            with self.subTest(ref=ref):
                metadata = prepare_metadata(env(ref, ref_type, "workflow_dispatch", windows_only=windows), PUBSPEC)
                self.assertFalse(metadata["publish"])

    def test_rejects_wrong_refs_events_and_version_numbers(self):
        invalid = [env("main"), env("v1.0.2", "tag"), env("dev", event="pull_request"),
                   env("v1.0.1-dryrun", "tag"), env(run_number=0), env(run_number=64536),
                   env(windows_only=True), env("feature/test", event="workflow_dispatch")]
        for value in invalid:
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    prepare_metadata(value, PUBSPEC)
        with self.assertRaises(ValueError):
            prepare_metadata(env(), "version: 1.0.1-dev.1+2")
        with self.assertRaises(ValueError):
            prepare_metadata(env(), "version: 1.0.1+1043")

    def test_manual_stable_publication_allocates_a_new_number_without_retagging(self):
        manual = env("v1.0.1", "tag", "workflow_dispatch", run_number=44)
        manual["PUBLISH_STABLE"] = "true"
        metadata = prepare_metadata(manual, PUBSPEC)
        self.assertEqual(metadata["build_number"], 1044)
        self.assertTrue(metadata["publish"])
        self.assertEqual(metadata["channel"], "stable")
        for value in (env("dev", event="workflow_dispatch"),
                      env("v1.0.1", "tag"),
                      env("v1.0.1", "tag", "workflow_dispatch", windows_only=True)):
            with self.assertRaises(ValueError):
                prepare_metadata(dict(value, PUBLISH_STABLE="true"), PUBSPEC)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.metadata = prepare_metadata(env(), PUBSPEC)
        self.api = FakeGitHub(self.metadata)
        for platform, (directory, suffix) in PLATFORMS.items():
            target = self.root / directory
            target.mkdir()
            (target / f"{platform}.json").write_text(json.dumps(self.metadata))
            (target / f"{self.metadata['asset_prefix']}-{suffix}").write_bytes(platform.encode())

    def package(self):
        return package_release(self.root, self.metadata, self.api.repository,
                               "sha256:" + "a" * 64, "sha256:" + "b" * 64)

    def test_packages_are_pinned_and_all_checksums_match(self):
        files = self.package()
        compose = (self.root / "cue-deployment/docker-compose.yml").read_text()
        self.assertNotIn("cue-api:latest", compose)
        self.assertNotIn("cue-web:latest", compose)
        self.assertIn("cue-api@sha256:" + "a" * 64, compose)
        checksums = {line.split("  ")[1]: line.split("  ")[0]
                     for line in files[-1].read_text().splitlines()}
        self.assertEqual(len(files), 7)
        for path in files[:-1]:
            self.assertEqual(checksums[path.name], hashlib.sha256(path.read_bytes()).hexdigest())

    def test_rejects_mixed_commit_artifacts_and_missing_packages(self):
        stamp = self.root / "cue-macos-dmg/macos.json"
        stamp.write_text(json.dumps(dict(self.metadata, commit="f" * 40)))
        with self.assertRaisesRegex(ValueError, "does not match"):
            self.package()
        stamp.write_text(json.dumps(self.metadata))
        (stamp.parent / f"{self.metadata['asset_prefix']}-macos-universal.dmg").unlink()
        with self.assertRaisesRegex(ValueError, "Missing or empty"):
            self.package()

    def test_dev_is_draft_until_verified_and_never_latest(self):
        publish_release(self.api, self.metadata, self.package())
        creates = [data for method, path, data in self.api.calls if method == "POST" and path == "/releases"]
        self.assertTrue(creates[0]["draft"])
        self.assertTrue(creates[0]["prerelease"])
        self.assertEqual(creates[0]["target_commitish"], SHA)
        self.assertEqual(creates[0]["make_latest"], "false")
        self.assertIn(DEV_MARKER, creates[0]["body"])
        self.assertEqual(self.api.calls[-1][2], {"draft": False, "prerelease": True, "make_latest": "false"})
        self.assertTrue(self.api.published)

    def test_stable_becomes_latest_after_verification(self):
        self.metadata.update(channel="stable", tag="v1.0.1")
        publish_release(self.api, self.metadata, self.package_for_updated_metadata())
        self.assertEqual(self.api.calls[-1][2]["make_latest"], "true")
        self.assertFalse(self.api.calls[-1][2]["prerelease"])

    def package_for_updated_metadata(self):
        for platform, (directory, _) in PLATFORMS.items():
            (self.root / directory / f"{platform}.json").write_text(json.dumps(self.metadata))
        return self.package()

    def test_failed_or_incomplete_upload_stays_draft(self):
        for option in ("fail_upload", "incomplete_listing", "supersede_on_upload"):
            with self.subTest(option=option):
                self.api = FakeGitHub(self.metadata)
                setattr(self.api, option, True)
                with self.assertRaises(ValueError):
                    publish_release(self.api, self.metadata, self.package())
                self.assertFalse(self.api.published)

    def test_published_versions_wrong_tags_and_superseded_builds_are_rejected(self):
        self.api.existing = {"draft": False}
        with self.assertRaisesRegex(ValueError, "already published"):
            check_source(self.api, self.metadata)
        self.assertEqual(self.api.calls, [("GET", "/git/ref/heads/dev", None)])
        self.api.existing = None
        self.api.tag_sha = "f" * 40
        with self.assertRaisesRegex(ValueError, "different commit"):
            publish_release(self.api, self.metadata, self.package())
        self.api.tag_sha = None
        self.api.history = [{"draft": False, "body": "<!-- cue-release-build:1043 -->"}]
        with self.assertRaisesRegex(ValueError, "newer build"):
            check_source(self.api, self.metadata)

    def test_draft_retry_replaces_uploads_before_publication(self):
        self.api.existing = {"id": 1, "draft": True}
        self.api.assets = [{"id": 99, "name": "old-file"}]
        publish_release(self.api, self.metadata, self.package())
        self.assertIn(("DELETE", "/releases/assets/99", None), self.api.calls)
        self.assertTrue(self.api.published)

    def test_promotion_retry_verifies_published_files_without_mutating_them(self):
        files = self.package()
        publish_release(self.api, self.metadata, files)
        self.api.existing = {"id": 1, "draft": False}
        self.api.calls.clear()
        publish_release(self.api, self.metadata, files)
        self.assertTrue(all(method == "GET" for method, _, _ in self.api.calls))
        files[0].write_bytes(b"different build")
        with self.assertRaisesRegex(ValueError, "Upload verification failed"):
            publish_release(self.api, self.metadata, files)


class RetentionTests(unittest.TestCase):
    def test_keeps_ten_and_preserves_stable_manual_and_draft_releases(self):
        managed = [{"id": number, "tag_name": f"dev-1.0.1-{1000 + number}-abcdef012345",
                    "prerelease": True, "draft": False, "body": DEV_MARKER}
                   for number in range(1, 13)]
        unrelated = [dict(managed[0], id=100, prerelease=False),
                     dict(managed[0], id=101, draft=True),
                     dict(managed[0], id=102, body="Manually published"),
                     dict(managed[0], id=103, tag_name="v1.0.1")]
        self.assertEqual([item["id"] for item in old_dev_releases(managed + unrelated)], [2, 1])


if __name__ == "__main__":
    unittest.main()
