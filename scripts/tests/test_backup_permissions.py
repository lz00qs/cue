"""Exercise the inline POSIX preflight without Docker or third-party libraries."""

import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import textwrap
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[2]
COMPOSE = (ROOT / "docker-compose.yml").read_text()
SERVICES = dict(re.findall(
    r"^  ([a-z][a-z0-9-]*):\n(.*?)(?=^  [a-z][a-z0-9-]*:|^volumes:|\Z)",
    COMPOSE, re.MULTILINE | re.DOTALL))
SCRIPT = textwrap.dedent(SERVICES["backup-permissions-check"].split(
    "    command:\n      - |\n", 1)[1]).replace("$$", "$").strip() + "\n"


@unittest.skipIf(os.geteuid() == 0, "Filesystem permission tests require a non-root user")
class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cue-preflight-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # Spaces exercise quoting in the exact script used by Compose.
        self.backups = self.root / "backup directory"
        self.backups.mkdir()
        self.env = os.environ.copy()
        self.env["LC_ALL"] = "C"
        self.script = SCRIPT.replace("backup_dir=/backups", "backup_dir=" + shlex.quote(str(self.backups)), 1)

    def run_check(self):
        return subprocess.run(["/bin/sh", "-c", self.script], env=self.env,
                              capture_output=True, text=True)

    def shim(self, name, body):
        bin_dir = self.root / "bin"
        bin_dir.mkdir(exist_ok=True)
        command = bin_dir / name
        command.write_text("#!/bin/sh\n" + body + "\n")
        command.chmod(0o755)
        self.env["PATH"] = str(bin_dir) + os.pathsep + os.environ["PATH"]

    def assert_clean(self):
        self.assertEqual(list(self.backups.rglob(".cue-permissions.*")), [])

    def assert_failure(self, result, reason):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("[CUE] Backup directory permission check failed.", result.stderr)
        self.assertIn("Container UID: " + str(os.geteuid()), result.stderr)
        self.assertIn("Container GID: " + str(os.getegid()), result.stderr)
        self.assertIn(reason, result.stderr)
        self.assertIn("CUE_UID", result.stderr)
        self.assertIn("CUE_GID", result.stderr)
        self.assert_clean()

    def test_posix_shell_syntax(self):
        result = subprocess.run(["/bin/sh", "-n"], input=SCRIPT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_writable_directory_passes_and_preserves_existing_backups(self):
        for directory in (self.backups, *(self.backups / name for name in ("last", "daily", "weekly", "monthly"))):
            directory.mkdir(exist_ok=True)
            (directory / "existing.sql.gz").write_bytes(b"existing backup\x00")
        snapshots = {path: (path.read_bytes(), path.stat()) for path in self.backups.rglob("*.sql.gz")}
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("[CUE] Backup directory permission check passed:", result.stdout)
        self.assert_clean()
        self.assertEqual(set(self.backups.rglob("*.sql.gz")), set(snapshots))
        for path, (data, before) in snapshots.items():
            self.assertEqual(path.read_bytes(), data)
            after = path.stat()
            for field in ("st_ino", "st_uid", "st_gid", "st_mode", "st_mtime_ns", "st_nlink"):
                self.assertEqual(getattr(after, field), getattr(before, field))

    def test_directory_without_write_permission_fails(self):
        self.backups.chmod(0o500)
        self.addCleanup(self.backups.chmod, 0o700)
        self.assert_failure(self.run_check(), "Permission denied")

    def test_directory_without_traversal_permission_fails(self):
        self.backups.chmod(0o600)
        self.addCleanup(self.backups.chmod, 0o700)
        result = self.run_check()
        self.backups.chmod(0o700)
        self.assert_failure(result, "Cannot enter directory:")

    def test_existing_rotation_directory_without_write_permission_fails(self):
        last = self.backups / "last"
        last.mkdir(mode=0o500)
        self.addCleanup(last.chmod, 0o700)
        result = self.run_check()
        self.assert_failure(result, "Permission denied")
        self.assertIn("Path: " + str(last), result.stderr)

    def test_missing_directory_fails(self):
        self.backups.rmdir()
        self.assert_failure(self.run_check(), "Backup path does not exist or is not a directory.")

    def test_non_directory_rotation_path_fails_without_modifying_it(self):
        last = self.backups / "last"
        last.write_bytes(b"keep me")
        self.assert_failure(self.run_check(), "Backup path is not a directory.")
        self.assertEqual(last.read_bytes(), b"keep me")

    def test_unsupported_hard_links_fail_and_clean_up(self):
        # Fault injection models a filesystem rejecting hard links; not a NAS test.
        self.shim("ln", 'echo "ln: Operation not supported" >&2\nexit 1')
        self.assert_failure(self.run_check(), "Cannot create hard link: ln: Operation not supported")

    def test_unsupported_symbolic_links_fail_and_clean_up(self):
        real_ln = shlex.quote(shutil.which("ln"))
        self.shim("ln", 'if [ "$1" = "-s" ]; then echo "ln: Operation not supported" >&2; exit 1; fi\n'
                  + "exec " + real_ln + ' "$@"')
        self.assert_failure(self.run_check(), "Cannot create symbolic link: ln: Operation not supported")

    def test_file_write_failure_cleans_up(self):
        self.shim("sh", 'echo "write: Permission denied" >&2\nexit 1')
        self.assert_failure(self.run_check(), "Cannot write test file: write: Permission denied")

    def test_delete_failure_is_reported_and_trap_retries_cleanup(self):
        marker = shlex.quote(str(self.root / "rm-failed"))
        real_rm = shlex.quote(shutil.which("rm"))
        self.shim("rm", 'if [ ! -e ' + marker + ' ]; then touch ' + marker
                  + '; echo "rm: Permission denied" >&2; exit 1; fi\nexec ' + real_rm + ' "$@"')
        self.assert_failure(self.run_check(), "Cannot delete temporary test files: rm: Permission denied")

    def test_root_identity_is_rejected_before_any_write(self):
        real_id = shlex.quote(shutil.which("id"))
        self.shim("id", 'if [ "$1" = "-u" ]; then echo 0; else exec ' + real_id + ' "$@"; fi')
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CUE_UID must be a non-root numeric UID.", result.stderr)
        self.assertEqual(list(self.backups.iterdir()), [])


class ComposeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not shutil.which("docker"):
            raise unittest.SkipTest("Docker Compose CLI is unavailable (no daemon needed)")
        result = subprocess.run(["docker", "compose", "version"], capture_output=True, text=True)
        if result.returncode:
            raise unittest.SkipTest("Docker Compose plugin is unavailable")

    def config(self, uid=None, gid=None, dev=False, env_file=None):
        # Never read the user's .env or echo expanded passwords/secrets.
        env = {key: value for key, value in os.environ.items()
               if not key.startswith(("CUE_", "POSTGRES_", "COMPOSE_"))}
        env.update(POSTGRES_PASSWORD="test-database-password",
                   CUE_JWT_SECRET="test-jwt-secret", CUE_REFRESH_SECRET="test-refresh-secret")
        if uid is not None:
            env["CUE_UID"] = uid
        if gid is not None:
            env["CUE_GID"] = gid
        command = ["docker", "compose", "--env-file", str(env_file or os.devnull), "--profile", "https",
                   "-f", str(ROOT / "docker-compose.yml")]
        if dev:
            command += ["-f", str(ROOT / "docker-compose.dev.yml")]
        result = subprocess.run(command + ["config", "--format", "json"], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, "docker compose config failed; expanded output withheld")
        return json.loads(result.stdout)

    def test_default_and_empty_ids_are_999(self):
        for ids in ((None, None), ("", "")):
            with self.subTest(ids=ids):
                services = self.config(*ids)["services"]
                for name in ("db-backup", "backup-permissions-check"):
                    self.assertEqual(services[name]["user"], "999:999")

    def test_custom_ids_reach_only_backup_services(self):
        services = self.config("1026", "100")["services"]
        for name in ("db-backup", "backup-permissions-check"):
            self.assertEqual(services[name]["user"], "1026:100")
        for name in ("cue-db", "cue-api", "cue-web", "cue-https"):
            self.assertNotIn("user", services[name])

    def test_custom_ids_are_loaded_from_env_file(self):
        with tempfile.TemporaryDirectory(prefix="cue-env-test-") as directory:
            env_file = Path(directory) / ".env"
            env_file.write_text("CUE_UID=1026\nCUE_GID=100\n")
            services = self.config(env_file=env_file)["services"]
        for name in ("db-backup", "backup-permissions-check"):
            self.assertEqual(services[name]["user"], "1026:100")

    def test_preflight_gates_only_backup_and_uses_the_same_mount_and_image(self):
        services = self.config()["services"]
        backup = services["db-backup"]
        check = services["backup-permissions-check"]
        self.assertEqual(backup["image"], "prodrigestivill/postgres-backup-local:17")
        self.assertEqual(check["image"], backup["image"])
        self.assertEqual(check["volumes"], backup["volumes"])
        self.assertEqual(check["volumes"][0]["source"], str(ROOT / "backups"))
        self.assertEqual(check["volumes"][0]["target"], "/backups")
        self.assertEqual(check["restart"], "no")
        self.assertEqual(check["network_mode"], "none")
        self.assertTrue(check["healthcheck"]["disable"])
        self.assertNotIn("environment", check)
        self.assertEqual(check["entrypoint"], ["/bin/sh", "-c"])
        # `config` re-escapes dollars for its reusable serialized output.
        self.assertEqual([value.replace("$$", "$") for value in check["command"]], [SCRIPT])
        self.assertNotRegex(SERVICES["backup-permissions-check"].split("      - |\n", 1)[1],
                            r"(?<!\$)\$(?!\$)")
        self.assertEqual(backup["depends_on"]["backup-permissions-check"]["condition"],
                         "service_completed_successfully")
        self.assertEqual(backup["depends_on"]["cue-db"]["condition"], "service_healthy")
        for name in ("cue-db", "cue-api", "cue-web", "cue-https"):
            self.assertNotIn("backup-permissions-check", services[name].get("depends_on", {}))

    def test_existing_deployment_settings_and_dev_overlay_remain_valid(self):
        for dev in (False, True):
            with self.subTest(dev=dev):
                services = self.config(dev=dev)["services"]
                backup = services["db-backup"]
                self.assertEqual(backup["restart"], "always")
                for key, value in {"BACKUP_ON_START": "TRUE", "SCHEDULE": "@hourly", "BACKUP_KEEP_MINS": "1440",
                                   "BACKUP_KEEP_DAYS": "7", "BACKUP_KEEP_WEEKS": "4", "BACKUP_KEEP_MONTHS": "3"}.items():
                    self.assertEqual(backup["environment"][key], value)
                self.assertEqual(services["cue-db"]["volumes"][0]["source"], "cue-postgres-data")
                self.assertEqual(services["cue-db"]["volumes"][0]["target"], "/var/lib/postgresql/data")
                self.assertEqual(services["cue-api"]["depends_on"]["cue-db"]["condition"], "service_healthy")
                self.assertEqual(services["cue-web"]["depends_on"]["cue-api"]["condition"], "service_healthy")


@unittest.skipUnless(os.environ.get("CUE_TEST_DOCKER") == "1",
                     "Set CUE_TEST_DOCKER=1 to run isolated container tests")
class DockerPreflightTests(unittest.TestCase):
    def command(self, *args):
        return subprocess.run(args, capture_output=True, text=True, timeout=120)

    def setUp(self):
        self.name = "cue-backup-test-" + uuid.uuid4().hex[:12]
        self.volume = self.name + "-data"
        self.temp = tempfile.TemporaryDirectory(prefix=self.name)
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "compose.json"
        self.image = "prodrigestivill/postgres-backup-local:17"
        model = ComposeTests().config("999", "999")
        check = model["services"]["backup-permissions-check"]
        # An isolated Docker volume makes these tests independent of host ACLs.
        check["volumes"] = ["test-backups:/backups"]
        self.fixture = {
            "name": self.name,
            "services": {
                "backup-permissions-check": check,
                "db-backup": {
                    "image": self.image, "user": "999:999", "restart": "no",
                    "network_mode": "none", "healthcheck": {"disable": True},
                    "entrypoint": ["/bin/sh", "-c"],
                    "command": ["printf '%s\\n' CUE_TEST_BACKUP_STARTED"],
                    "depends_on": {"backup-permissions-check": {"condition": "service_completed_successfully"}},
                },
            },
            "volumes": {"test-backups": {"external": True, "name": self.volume}},
        }
        self.path.write_text(json.dumps(self.fixture))
        result = self.command("docker", "volume", "create", self.volume)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.addCleanup(self.command, "docker", "volume", "rm", self.volume)
        self.addCleanup(self.compose, "down", "--remove-orphans")

    def compose(self, *args):
        return self.command("docker", "compose", "--env-file", os.devnull,
                            "-f", str(self.path), *args)

    def prepare_volume(self, mode, owner="999:999"):
        # Root is used only to prepare this newly-created test fixture, never production data.
        result = self.command("docker", "run", "--rm", "--network", "none", "--user", "0:0",
                              "--volume", self.volume + ":/backups", "--entrypoint", "/bin/sh",
                              self.image, "-c", "chown " + owner + " /backups && chmod " + mode + " /backups")
        self.assertEqual(result.returncode, 0, result.stderr)

    def assert_volume_empty(self):
        result = self.command("docker", "run", "--rm", "--network", "none", "--user", "999:999",
                              "--volume", self.volume + ":/backups", "--entrypoint", "/bin/sh",
                              self.image, "-c", 'test -z "$(ls -A /backups)"')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_writable_volume_allows_dependent_service_to_start(self):
        self.prepare_volume("700")
        result = self.compose("up", "-d")
        self.assertEqual(result.returncode, 0, result.stderr)
        container = self.compose("ps", "-a", "-q", "db-backup").stdout.strip()
        self.assertTrue(container)
        self.command("docker", "wait", container)
        logs = self.compose("logs", "db-backup").stdout
        self.assertIn("CUE_TEST_BACKUP_STARTED", logs)
        check_logs = self.compose("logs", "backup-permissions-check").stdout
        self.assertIn("permission check passed", check_logs)
        self.assert_volume_empty()

    def test_unwritable_volume_blocks_dependent_service_without_restarts(self):
        self.prepare_volume("500")
        result = self.compose("up", "-d")
        self.assertNotEqual(result.returncode, 0)
        check_id = self.compose("ps", "-a", "-q", "backup-permissions-check").stdout.strip()
        self.assertTrue(check_id)
        check = json.loads(self.command("docker", "inspect", check_id).stdout)[0]
        self.assertNotEqual(check["State"]["ExitCode"], 0)
        self.assertEqual(check["RestartCount"], 0)
        self.assertEqual(check["HostConfig"]["RestartPolicy"]["Name"], "no")
        logs = self.compose("logs", "backup-permissions-check").stdout
        self.assertIn("Container UID: 999", logs)
        self.assertIn("Container GID: 999", logs)
        self.assertIn("Permission denied", logs)
        backup_id = self.compose("ps", "-a", "-q", "db-backup").stdout.strip()
        if backup_id:
            backup = json.loads(self.command("docker", "inspect", backup_id).stdout)[0]
            self.assertEqual(backup["State"]["StartedAt"], "0001-01-01T00:00:00Z")
        self.assertNotIn("CUE_TEST_BACKUP_STARTED", self.compose("logs", "db-backup").stdout)
        self.assert_volume_empty()

    def test_real_postgresql_startup_backup_with_custom_numeric_ids(self):
        self.prepare_volume("700", "1026:100")
        model = ComposeTests().config("1026", "100")
        backup = model["services"]["db-backup"]
        backup["volumes"] = ["test-backups:/backups"]
        database = model["services"]["cue-db"]
        # Actual PostgreSQL initialization uses disposable tmpfs, never Cue's named volume.
        database["volumes"] = [{"type": "tmpfs", "target": "/var/lib/postgresql/data"}]
        database["restart"] = "no"
        self.fixture["services"]["backup-permissions-check"]["user"] = "1026:100"
        self.fixture["services"]["db-backup"] = backup
        self.fixture["services"]["cue-db"] = database
        self.path.write_text(json.dumps(self.fixture))
        result = self.compose("up", "-d")
        self.assertEqual(result.returncode, 0, result.stderr)
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            result = self.compose("exec", "-T", "db-backup", "/bin/sh", "-c",
                                  "test -s /backups/last/cue-latest.sql.gz && "
                                  "gzip -t /backups/last/cue-latest.sql.gz && "
                                  "stat -c '%u:%g' /backups/last/cue-latest.sql.gz && "
                                  "gzip -dc /backups/last/cue-latest.sql.gz")
            if result.returncode == 0:
                break
            time.sleep(0.5)
        self.assertEqual(result.returncode, 0, "Startup backup was not produced within 30 seconds")
        self.assertTrue(result.stdout.startswith("1026:100\n"))
        self.assertIn("PostgreSQL database dump", result.stdout)
        for name in ("last", "daily", "weekly", "monthly"):
            result = self.compose("exec", "-T", "db-backup", "test", "-s", "/backups/" + name + "/cue-latest.sql.gz")
            self.assertEqual(result.returncode, 0, result.stderr)
        result = self.compose("exec", "-T", "db-backup", "/bin/sh", "-c",
                              'test -z "$(find /backups -name ".cue-permissions.*" -print)"')
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
