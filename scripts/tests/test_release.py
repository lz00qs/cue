import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import parse_qs, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release import (DEV_MARKER, PLATFORMS, check_source, old_dev_releases,
                     deployment_files, package_release, prepare_metadata, publish_release,
                     release_body, release_title)


SHA = "abcdef012345" + "0" * 28
PUBSPEC = "name: cue\nversion: 1.0.1+2\n"


def env(ref="dev", ref_type="branch", event="workflow_dispatch", run_number=42, windows_only=False):
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
        self.commits = []

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
        if path.startswith("/compare/"):
            return {"commits": self.commits}
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
        stable = prepare_metadata(env("v1.0.1", "tag", "push", run_number=43), PUBSPEC)
        self.assertTrue(dev["publish"])
        self.assertTrue(dev["push_images"])
        self.assertTrue(stable["push_images"])
        self.assertEqual(dev["tag"], "v1.0.1-dev.1042")
        self.assertEqual(release_title(dev), "Cue v1.0.1-dev.1042")
        self.assertEqual(release_title(stable), "Cue v1.0.1")
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
                self.assertFalse(metadata["push_images"])

    def test_internal_dev_build_uses_shared_numbering_without_publication(self):
        for windows_only in (False, True):
            with self.subTest(windows_only=windows_only):
                metadata = prepare_metadata(dict(env(windows_only=windows_only), BUILD_ONLY="true"), PUBSPEC)
                self.assertFalse(metadata["publish"])
                self.assertEqual(metadata["channel"], "dev")
                self.assertEqual(metadata["build_number"], 1042)
                self.assertEqual(metadata["asset_prefix"], "Cue-v1.0.1-dev.1042")
        for value in (env("main"), env("v1.0.1", "tag", "workflow_dispatch"),
                      env("v1.0.1", "tag", "push"), env(event="push"),
                      dict(env(), PUBLISH_STABLE="true")):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    prepare_metadata(dict(value, BUILD_ONLY="true"), PUBSPEC)

    def test_rejects_wrong_refs_events_and_version_numbers(self):
        invalid = [env("main"), env("v1.0.2", "tag"), env("dev", event="pull_request"),
                   env("v1.0.1-dryrun", "tag", "push"), env(run_number=0), env(run_number=64536),
                   env("dev", event="push"), env(windows_only=True, event="push"),
                   env("v1.0.1-dev.1042", "tag", "push"), env("feature/test", event="workflow_dispatch")]
        for value in invalid:
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    prepare_metadata(value, PUBSPEC)
        with self.assertRaises(ValueError):
            prepare_metadata(env(), "version: 1.0.1-dev.1+2")
        with self.assertRaises(ValueError):
            prepare_metadata(env(), "version: 1.0.1+1043")

    def test_selected_internal_platform_never_publishes(self):
        for platform in ("all", "android", "macos", "windows", "ios", "docker"):
            with self.subTest(platform=platform):
                metadata = prepare_metadata(dict(env(), BUILD_ONLY="true", BUILD_PLATFORM=platform), PUBSPEC)
                self.assertFalse(metadata["publish"])
                self.assertFalse(metadata["push_images"])
                self.assertEqual(metadata["platform"], platform)
                self.assertEqual(metadata["build_number"], 1042)
        self.assertEqual(prepare_metadata(env(windows_only=True), PUBSPEC)["platform"], "windows")
        self.assertEqual(prepare_metadata(env(), PUBSPEC)["platform"], "all")

    def test_public_releases_cannot_select_a_subset_of_platforms(self):
        for value in (env(), env("v1.0.1", "tag", "push"),
                      dict(env("v1.0.1", "tag"), PUBLISH_STABLE="true")):
            with self.subTest(value=value):
                with self.assertRaisesRegex(ValueError, "public releases must build all"):
                    prepare_metadata(dict(value, BUILD_PLATFORM="android"), PUBSPEC)

    def test_internal_docker_push_does_not_publish_a_release(self):
        for platform in ("all", "docker"):
            with self.subTest(platform=platform):
                metadata = prepare_metadata(dict(env(), BUILD_ONLY="true", BUILD_PLATFORM=platform,
                                                 PUSH_DEV_IMAGES="true"), PUBSPEC)
                self.assertTrue(metadata["push_images"])
                self.assertFalse(metadata["publish"])
                self.assertEqual(metadata["channel"], "dev")
                self.assertEqual(metadata["image_tag"], "dev-1042-abcdef012345")

    def test_internal_docker_push_rejects_incompatible_modes(self):
        invalid = [env(), dict(env(), BUILD_ONLY="true", BUILD_PLATFORM="android"),
                   dict(env(), BUILD_ONLY="true", WINDOWS_ONLY="true"),
                   dict(env("main"), BUILD_ONLY="true"),
                   env("v1.0.1", "tag", "push"),
                   dict(env(), BUILD_ONLY="true", PUBLISH_STABLE="true")]
        for value in invalid:
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    prepare_metadata(dict(value, PUSH_DEV_IMAGES="true"), PUBSPEC)

    def test_invalid_and_conflicting_internal_targets_are_rejected(self):
        for platform in ("unknown", "android,windows", ""):
            with self.subTest(platform=platform):
                with self.assertRaisesRegex(ValueError, "Unknown"):
                    prepare_metadata(dict(env(), BUILD_ONLY="true", BUILD_PLATFORM=platform), PUBSPEC)
        with self.assertRaisesRegex(ValueError, "conflicts"):
            prepare_metadata(dict(env(windows_only=True), BUILD_ONLY="true", BUILD_PLATFORM="macos"), PUBSPEC)

    def test_manual_stable_publication_allocates_a_new_number_without_retagging(self):
        manual = env("v1.0.1", "tag", "workflow_dispatch", run_number=44)
        manual["PUBLISH_STABLE"] = "true"
        metadata = prepare_metadata(manual, PUBSPEC)
        self.assertEqual(metadata["build_number"], 1044)
        self.assertTrue(metadata["publish"])
        self.assertEqual(metadata["channel"], "stable")
        for value in (env("dev", event="workflow_dispatch"),
                      env("v1.0.1", "tag", "push"),
                      env("v1.0.1", "tag", "workflow_dispatch", windows_only=True)):
            with self.assertRaises(ValueError):
                prepare_metadata(dict(value, PUBLISH_STABLE="true"), PUBSPEC)


class InternalDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.metadata = prepare_metadata(dict(env(), BUILD_ONLY="true", BUILD_PLATFORM="docker",
                                              PUSH_DEV_IMAGES="true"), PUBSPEC)
        self.api_digest = "sha256:" + "a" * 64
        self.web_digest = "sha256:" + "b" * 64

    def test_deployment_pins_both_images_without_native_packages(self):
        files = deployment_files(self.root, self.metadata, "lz00qs/cue", self.api_digest, self.web_digest)
        self.assertEqual({path.name for path in files}, {"docker-compose.yml", "example.env", "release.json"})
        compose = (self.root / "docker-compose.yml").read_text()
        self.assertIn("cue-api@" + self.api_digest, compose)
        self.assertIn("cue-web@" + self.web_digest, compose)
        self.assertNotIn("cue-api:latest", compose)
        self.assertNotIn("cue-web:latest", compose)
        manifest = json.loads((self.root / "release.json").read_text())
        self.assertFalse(manifest["publish"])
        self.assertEqual(manifest["images"], {"api": self.api_digest, "web": self.web_digest})
        self.assertEqual(manifest["commit"], SHA)

    def test_cli_prepares_checked_deployment_without_a_github_token(self):
        for source, target in (("docker-compose.yml", "docker-compose.yml"), (".env.example", ".env.example")):
            (self.root / target).write_bytes(Path(source).read_bytes())
        summary = self.root / "summary.md"
        result = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / "release.py"),
                                 "deployment"], cwd=self.root, capture_output=True, text=True, env={
                                     "PATH": os.environ["PATH"],
                                     "CUE_RELEASE_METADATA": json.dumps(self.metadata),
                                     "GITHUB_REPOSITORY": "lz00qs/cue",
                                     "GITHUB_STEP_SUMMARY": str(summary),
                                     "API_DIGEST": self.api_digest, "WEB_DIGEST": self.web_digest,
                                 })
        self.assertEqual(result.returncode, 0, result.stderr)
        deployment = self.root / "build/release/cue-deployment"
        checksums = (deployment / "SHA256SUMS").read_text().splitlines()
        self.assertEqual(len(checksums), 3)
        for line in checksums:
            digest, filename = line.split("  ")
            self.assertEqual(digest, hashlib.sha256((deployment / filename).read_bytes()).hexdigest())
        self.assertIn("cue-api:dev-1042-abcdef012345", summary.read_text())
        self.assertIn("cue-dev-deployment", summary.read_text())

    def test_deployment_rejects_missing_or_malformed_published_digests(self):
        for digests in (("", self.web_digest), (self.api_digest, "sha256:bad")):
            with self.subTest(digests=digests):
                with self.assertRaisesRegex(ValueError, "Expected published"):
                    deployment_files(self.root, self.metadata, "lz00qs/cue", *digests)
        self.assertEqual(list(self.root.iterdir()), [])


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
        self.assertEqual(creates[0]["name"], "Cue v1.0.1-dev.1042")
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

    def test_both_channels_use_one_notes_layout_and_curated_stable_changes(self):
        for channel, tag in (("dev", "v1.0.1-dev.1042"), ("stable", "v1.0.1")):
            body = release_body(dict(self.metadata, channel=channel, tag=tag), self.api.repository)
            for heading in ("## 本版内容", "## 获取与部署", "## 构建信息", "## English"):
                self.assertEqual(body.count(heading), 1)
            self.assertNotIn("# Cue", body)
            self.assertIn(f"发布标签：`{tag}`", body)
            self.assertIn("README.zh.md", body)
            if channel == "stable":
                self.assertIn("在 Today 视图新建任务时", body)

    def test_notes_keep_existing_filenames_and_do_not_invent_missing_assets(self):
        old = dict(self.metadata, channel="stable", tag="v1.0.0", image_tag="1.0.0",
                   assets=["app-release.apk", "Cue-v1.0.0-macos-universal.dmg",
                           "Cue-v1.0.0-windows-x64-setup.exe", "cue-windows.zip"])
        body = release_body(old, self.api.repository)
        self.assertIn("`app-release.apk`", body)
        self.assertIn("`cue-windows.zip`", body)
        self.assertNotIn("`release.json`", body)
        self.assertNotIn("`example.env`", body)

    def test_dev_changes_compare_previous_dev_or_first_stable_without_extra_headings(self):
        for prerelease in (False, True):
            with self.subTest(prerelease=prerelease):
                self.api = FakeGitHub(self.metadata)
                self.api.history = [{"draft": False, "prerelease": prerelease,
                                     "tag_name": "v1.0.1-dev.1041" if prerelease else "v1.0.1",
                                     "body": DEV_MARKER if prerelease else "Stable notes"}]
                self.api.commits = [{"sha": SHA, "commit": {"message": "fix(ui): handle [empty] tasks\n\nDetails"}}]
                publish_release(self.api, self.metadata, self.package())
                payload = next(data for method, path, data in self.api.calls if method == "POST" and path == "/releases")
                self.assertIn(r"handle \[empty\] tasks", payload["body"])
                self.assertEqual(payload["body"].count("## 本版内容"), 1)
                self.assertIn("[完整变更]", payload["body"])


class RetentionTests(unittest.TestCase):
    def test_keeps_ten_and_preserves_stable_manual_and_draft_releases(self):
        managed = [{"id": number, "tag_name": f"v1.0.1-dev.{1000 + number}",
                    "prerelease": True, "draft": False, "body": DEV_MARKER}
                   for number in range(1, 13)]
        # Legacy releases count toward the same retention limit during migration.
        managed[0]["tag_name"] = "dev-1.0.1-1001-abcdef012345"
        unrelated = [dict(managed[0], id=100, prerelease=False),
                     dict(managed[0], id=101, draft=True),
                     dict(managed[0], id=102, body="Manually published"),
                     dict(managed[0], id=103, tag_name="v1.0.1")]
        self.assertEqual([item["id"] for item in old_dev_releases(managed + unrelated)], [2, 1])


if __name__ == "__main__":
    unittest.main()
