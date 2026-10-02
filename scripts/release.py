#!/usr/bin/env python3
"""Prepare, verify and publish Cue's stable and dev releases (stdlib only)."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


BUILD_NUMBER_BASE = 1000
DEV_MARKER = "<!-- cue-dev-release -->"
PLATFORMS = {
    "android": ("cue-android-apk", "android-universal.apk"),
    "macos": ("cue-macos-dmg", "macos-universal.dmg"),
    "windows": ("cue-windows-installer", "windows-x64-setup.exe"),
}


def prepare_metadata(env, pubspec):
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec, re.M)
    if not match:
        raise ValueError("Expected a numeric pubspec version such as 1.0.1+2")
    version, local_build = match.groups()
    run_number = int(env["GITHUB_RUN_NUMBER"])
    # Both channels enter through release.yml: its run number never resets on reruns.
    build_number = BUILD_NUMBER_BASE + run_number
    if run_number < 1 or not int(local_build) < build_number <= 65535:
        raise ValueError("Build number must exceed pubspec's number and fit Windows' 16-bit version")
    commit = env["GITHUB_SHA"]
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected a full commit SHA")
    event, ref_type, ref = (env[key] for key in (
        "GITHUB_EVENT_NAME", "GITHUB_REF_TYPE", "GITHUB_REF_NAME"))
    windows_only = env.get("WINDOWS_ONLY", "false").lower() == "true"
    publish_stable = env.get("PUBLISH_STABLE", "false").lower() == "true"
    if event not in ("push", "workflow_dispatch"):
        raise ValueError("Unsupported release event")
    if windows_only and event != "workflow_dispatch":
        raise ValueError("Windows-only validation must be manually dispatched")
    if publish_stable and (event != "workflow_dispatch" or windows_only
                           or ref_type != "tag" or ref != f"v{version}"):
        raise ValueError("Manual stable publication requires its matching vX.Y.Z tag and all platforms")
    channel = "stable"
    publish = False
    if ref_type == "branch" and ref == "dev":
        channel = "dev"
        publish = not windows_only
    elif event == "push" and ref_type == "tag" and ref == f"v{version}":
        publish = True
    elif publish_stable:
        publish = True
    elif event == "workflow_dispatch" and windows_only and ref_type == "branch" and ref == "main":
        pass
    elif event == "workflow_dispatch" and not windows_only and ref_type == "tag" and ref == f"v{version}-dryrun":
        pass
    else:
        raise ValueError("Use dev, a matching stable tag, main/windows_only, or a matching -dryrun tag")
    short_sha = commit[:12]
    tag = f"dev-{version}-{build_number}-{short_sha}" if channel == "dev" else f"v{version}"
    return {
        "version": version,
        "build_number": build_number,
        "channel": channel,
        "commit": commit,
        "tag": tag,
        "asset_prefix": f"Cue-{tag}",
        "image_tag": f"dev-{build_number}-{short_sha}" if channel == "dev" else version,
        "publish": publish,
        "run_number": run_number,
        "run_id": env["GITHUB_RUN_ID"],
    }


class GitHub:
    def __init__(self, repository, token):
        self.repository = repository
        self.token = token
        self.base = f"https://api.github.com/repos/{repository}"

    def request(self, method, path, data=None, content_type="application/json"):
        url = path if path.startswith("https://") else self.base + path
        # Never send the token to a URL outside GitHub's API/upload hosts.
        if not url.startswith(("https://api.github.com/", "https://uploads.github.com/")):
            raise ValueError("Unexpected GitHub API host")
        body = data if isinstance(data, bytes) else json.dumps(data).encode() if data is not None else None
        req = Request(url, body, {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": content_type,
            "X-GitHub-Api-Version": "2022-11-28",
        }, method=method)
        with urlopen(req, timeout=120) as response:
            result = response.read()
            return json.loads(result) if result else None

    def optional(self, path):
        try:
            return self.request("GET", path)
        except HTTPError as error:
            if error.code == 404:
                return None
            raise

    def releases(self):
        page = 1
        while True:
            releases = self.request("GET", f"/releases?per_page=100&page={page}")
            yield from releases
            if len(releases) < 100:
                return
            page += 1


def check_source(api, metadata, allow_published=False):
    if metadata["channel"] == "dev":
        head = api.request("GET", "/git/ref/heads/dev")["object"]["sha"]
        if head != metadata["commit"]:
            raise ValueError("A newer dev commit exists; publish its build instead")
    for release in api.releases():
        match = re.search(r"<!-- cue-release-build:(\d+) -->", release.get("body") or "")
        if not release["draft"] and match and int(match[1]) > metadata["build_number"]:
            raise ValueError("A newer build is already published; start a new workflow run")
    existing = api.optional(f"/releases/tags/{quote(metadata['tag'], safe='')}")
    if existing and not existing["draft"] and not allow_published:
        raise ValueError("This version is already published; start a new run for a new Dev build")
    return existing


def verify_uploads(assets, files):
    if {asset["name"] for asset in assets} != {path.name for path in files}:
        raise ValueError("Release attachments are incomplete")
    by_name = {asset["name"]: asset for asset in assets}
    for path in files:
        asset = by_name[path.name]
        expected = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
        if asset["state"] != "uploaded" or asset["size"] != path.stat().st_size or asset.get("digest") != expected:
            raise ValueError(f"Upload verification failed: {path.name}")


def verify_artifacts(root, metadata):
    files = []
    for platform, (directory, suffix) in PLATFORMS.items():
        artifact_dir = root / directory
        stamp = json.loads((artifact_dir / f"{platform}.json").read_text())
        if stamp != metadata:
            raise ValueError(f"{platform} artifact does not match this build")
        package = artifact_dir / f"{metadata['asset_prefix']}-{suffix}"
        if not package.is_file() or package.stat().st_size == 0:
            raise ValueError(f"Missing or empty {platform} package")
        files.append(package)
    return files


def package_release(root, metadata, repository, api_digest, web_digest):
    files = verify_artifacts(root, metadata)
    for digest in (api_digest, web_digest):
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise ValueError("Expected published API and Web image digests")
    deployment = root / "cue-deployment"
    deployment.mkdir(exist_ok=True)
    compose = Path("docker-compose.yml").read_text()
    for name, digest in (("cue-api", api_digest), ("cue-web", web_digest)):
        compose, count = re.subn(
            rf"image: ghcr\.io/lz00qs/cue/{name}:latest",
            f"image: ghcr.io/{repository.lower()}/{name}@{digest}", compose)
        if count != 1:
            raise ValueError(f"Expected exactly one {name} image in compose")
    (deployment / "docker-compose.yml").write_text(compose)
    (deployment / "example.env").write_bytes(Path(".env.example").read_bytes())
    manifest = dict(metadata, images={"api": api_digest, "web": web_digest})
    (deployment / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
    files.extend(deployment / name for name in ("docker-compose.yml", "example.env", "release.json"))
    sums = deployment / "SHA256SUMS"
    sums.write_text("".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in files))
    files.append(sums)
    return files


def release_body(metadata, repository):
    commit, tag = metadata["commit"], metadata["tag"]
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    body = (
        f"<!-- cue-release-build:{metadata['build_number']} -->\n\n"
        f"Version: {metadata['version']} · Build: {metadata['build_number']} · Channel: {metadata['channel']}\n\n"
        f"Commit: [{commit[:12]}](https://github.com/{repository}/commit/{commit})\n\n"
        f"Built by [Release run {metadata['run_number']}](https://github.com/{repository}/actions/runs/{metadata['run_id']}). "
        f"Prepared at {now}.\n\n"
        "Download the Android APK, notarized macOS DMG, or Windows installer below. "
        "These packages use the same application identity as the stable version and replace it when installed. "
        "Android cannot install an older build number over a newer build.\n\n"
        "Cue is self-hosted. The attached docker-compose.yml pins API and Web images to this build's digests. "
        "Copy example.env to .env and configure it before starting Docker Compose. "
        f"See the [中文部署说明](https://github.com/{repository}/blob/{commit}/README.zh.md) "
        f"or [English setup guide](https://github.com/{repository}/blob/{commit}/README.md). "
        "iOS distribution is separate; there is no installable iOS package in this release. "
        "SHA256SUMS and release.json identify the files and source used for this build.\n"
    )
    if metadata["channel"] == "dev":
        body = DEV_MARKER + "\n\n**Development preview for testing bug fixes.**\n\n" + body
    notes = Path(f".github/release-notes/{tag}.md")
    if notes.is_file():
        body += "\n" + notes.read_text()
    return body


def publish_release(api, metadata, files):
    existing = check_source(api, metadata, allow_published=True)
    tag_path = f"/git/ref/tags/{quote(metadata['tag'], safe='')}"
    tag_ref = api.optional(tag_path)
    if tag_ref:
        obj = tag_ref["object"]
        while obj["type"] == "tag":
            obj = api.request("GET", f"/git/tags/{obj['sha']}")["object"]
        if obj["type"] != "commit" or obj["sha"] != metadata["commit"]:
            raise ValueError("Release tag points to a different commit")
    elif existing and not existing["draft"]:
        raise ValueError("Published release tag is missing")
    else:
        api.request("POST", "/git/refs", {
            "ref": f"refs/tags/{metadata['tag']}", "sha": metadata["commit"]})
    if existing and not existing["draft"]:
        # Retry a failed alias-promotion step using the original artifacts. Never
        # rebuild/replace a published version: every byte must still match.
        verify_uploads(api.request("GET", f"/releases/{existing['id']}/assets?per_page=100"), files)
        print(f"Verified already published {metadata['tag']}; resuming channel promotion")
        return
    dev = metadata["channel"] == "dev"
    body = release_body(metadata, api.repository)
    previous = next((release for release in api.releases()
                     if not release["draft"] and release["prerelease"] == dev
                     and (not dev or DEV_MARKER in (release.get("body") or ""))), None)
    if previous:
        notes = api.request("POST", "/releases/generate-notes", {
            "tag_name": metadata["tag"], "target_commitish": metadata["commit"],
            "previous_tag_name": previous["tag_name"],
        })
        body += "\n" + notes["body"]
    payload = {
        "tag_name": metadata["tag"], "target_commitish": metadata["commit"],
        "name": f"Cue {metadata['version']} Dev · {metadata['build_number']} · {metadata['commit'][:12]}" if dev else f"Cue {metadata['tag']}",
        "body": body, "draft": True, "prerelease": dev, "make_latest": "false",
    }
    if existing:
        release = api.request("PATCH", f"/releases/{existing['id']}", payload)
    else:
        release = api.request("POST", "/releases", payload)
    release_id = release["id"]
    assets = api.request("GET", f"/releases/{release_id}/assets?per_page=100")
    # Only drafts are changed. A retry can replace incomplete uploads without
    # exposing a partial release or modifying already published packages.
    for asset in assets:
        api.request("DELETE", f"/releases/assets/{asset['id']}")
    upload_url = release["upload_url"].split("{")[0]
    for path in files:
        result = api.request("POST", upload_url + "?" + urlencode({"name": path.name}),
                             path.read_bytes(), "application/octet-stream")
        expected = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
        if result["state"] != "uploaded" or result["size"] != path.stat().st_size or result.get("digest") != expected:
            raise ValueError(f"Upload verification failed: {path.name}")
    uploaded = api.request("GET", f"/releases/{release_id}/assets?per_page=100")
    verify_uploads(uploaded, files)
    # Check again after potentially lengthy uploads so an older run cannot win.
    check_source(api, metadata)
    published = api.request("PATCH", f"/releases/{release_id}", {
        "draft": False, "prerelease": dev, "make_latest": "false" if dev else "true"})
    print(f"Published {published['html_url']}")


def old_dev_releases(releases, keep=10):
    managed = []
    for release in releases:
        match = re.fullmatch(r"dev-\d+\.\d+\.\d+-(\d+)-[0-9a-f]{12}", release["tag_name"])
        if (match and release["prerelease"] and not release["draft"]
                and DEV_MARKER in (release.get("body") or "")):
            managed.append((int(match[1]), release))
    managed.sort(key=lambda item: item[0], reverse=True)
    return [release for _, release in managed[keep:]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "stamp", "publish", "cleanup"))
    parser.add_argument("platform", nargs="?", choices=PLATFORMS)
    args = parser.parse_args()
    if args.command == "prepare":
        metadata = prepare_metadata(os.environ, Path("pubspec.yaml").read_text())
        if metadata["publish"]:
            check_source(GitHub(os.environ["GITHUB_REPOSITORY"], os.environ["GH_TOKEN"]), metadata)
        outputs = dict(metadata, metadata=json.dumps(metadata, separators=(",", ":")))
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            for key, value in outputs.items():
                output.write(f"{key}={json.dumps(value) if isinstance(value, bool) else value}\n")
        print(f"Prepared {metadata['tag']} (publish={metadata['publish']})")
        return
    metadata = json.loads(os.environ["CUE_RELEASE_METADATA"])
    if args.command == "stamp":
        if not args.platform:
            parser.error("stamp requires a platform")
        Path("build/release").mkdir(parents=True, exist_ok=True)
        Path(f"build/release/{args.platform}.json").write_text(json.dumps(metadata, sort_keys=True) + "\n")
        return
    if not metadata["publish"]:
        raise ValueError("This run is validation-only")
    api = GitHub(os.environ["GITHUB_REPOSITORY"], os.environ["GH_TOKEN"])
    if args.command == "publish":
        files = package_release(Path("artifacts"), metadata, api.repository,
                                os.environ["API_DIGEST"], os.environ["WEB_DIGEST"])
        publish_release(api, metadata, files)
    elif metadata["channel"] == "dev":
        for release in old_dev_releases(api.releases()):
            api.request("DELETE", f"/releases/{release['id']}")
            # Delete only the tag associated with a workflow-managed dev release.
            api.request("DELETE", f"/git/refs/tags/{quote(release['tag_name'], safe='')}")
            print(f"Removed old Dev release {release['tag_name']}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, HTTPError) as error:
        print(f"::error::{error}", file=sys.stderr)
        sys.exit(1)
