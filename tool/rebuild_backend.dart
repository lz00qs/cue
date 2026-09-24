import 'dart:async';
import 'dart:io';

const _usage = '''
Usage: dart run tool/rebuild_backend.dart [--no-cache]

Rebuild the cue-api Docker image, recreate the backend container, wait until
it is healthy, and refresh any running Nginx proxy containers.

Options:
  --no-cache  Rebuild every Docker image layer without using the build cache.
  -h, --help  Show this help message.
''';

Future<void> main(List<String> arguments) async {
  try {
    await BackendUpdater(arguments).run();
  } on ToolFailure catch (error) {
    stderr.writeln('\nError: ${error.message}');
    exitCode = 1;
  } on ProcessException catch (error) {
    stderr.writeln(
      '\nError: Could not run ${error.executable}: ${error.message}',
    );
    exitCode = 1;
  }
}

final class BackendUpdater {
  BackendUpdater(this.arguments);

  final List<String> arguments;
  late final String projectDirectory;
  late final ComposeCommand compose;
  var noCache = false;

  Future<void> run() async {
    if (!_parseArguments()) {
      return;
    }

    projectDirectory = File.fromUri(Platform.script)
        .parent
        .parent
        .absolute
        .path;
    final healthTimeout = _readHealthTimeout();

    await _requireDocker();
    compose = await _findCompose();
    await _requireDockerDaemon();

    _log('Validating Docker Compose configuration');
    if (await compose.runLive(['config', '--quiet'], projectDirectory) != 0) {
      throw ToolFailure(
        'Compose configuration is invalid. If .env is missing, copy '
        '.env.example to .env and fill in its secrets.',
      );
    }

    _log('Ensuring PostgreSQL is running');
    await compose.runChecked(['up', '-d', 'cue-db'], projectDirectory);

    _log('Rebuilding the cue-api image');
    await compose.runChecked([
      'build',
      if (noCache) '--no-cache',
      'cue-api',
    ], projectDirectory);

    _log('Recreating the cue-api container');
    await compose.runChecked([
      'up',
      '-d',
      '--no-deps',
      '--force-recreate',
      'cue-api',
    ], projectDirectory);

    final apiContainerId = await compose.captureStdout([
      'ps',
      '-q',
      'cue-api',
    ], projectDirectory);
    if (apiContainerId.isEmpty) {
      await _showBackendLogs();
      throw ToolFailure('Docker Compose did not create the cue-api container.');
    }

    await _waitForBackend(apiContainerId, healthTimeout);
    await _refreshRunningProxy('cue-web');
    await _refreshRunningProxy('cue-https');

    _log('Backend update complete');
    await compose.runChecked(['ps', 'cue-api', 'cue-db'], projectDirectory);
  }

  bool _parseArguments() {
    for (final argument in arguments) {
      switch (argument) {
        case '--no-cache':
          noCache = true;
        case '-h' || '--help':
          stdout.write(_usage);
          return false;
        default:
          stderr.write(_usage);
          throw ToolFailure('Unknown option: $argument');
      }
    }
    return true;
  }

  int _readHealthTimeout() {
    final value = Platform.environment['CUE_BACKEND_HEALTH_TIMEOUT'] ?? '120';
    final timeout = int.tryParse(value);
    if (timeout == null || timeout <= 0) {
      throw ToolFailure(
        'CUE_BACKEND_HEALTH_TIMEOUT must be a positive integer.',
      );
    }
    return timeout;
  }

  Future<void> _requireDocker() async {
    final result = await _tryRunCaptured('docker', ['--version']);
    if (result == null || result.exitCode != 0) {
      throw ToolFailure('Docker is not installed or is not available in PATH.');
    }
  }

  Future<ComposeCommand> _findCompose() async {
    final plugin = await _tryRunCaptured('docker', ['compose', 'version']);
    if (plugin != null && plugin.exitCode == 0) {
      return const ComposeCommand('docker', ['compose']);
    }

    final standalone = await _tryRunCaptured('docker-compose', ['version']);
    if (standalone != null && standalone.exitCode == 0) {
      return const ComposeCommand('docker-compose', []);
    }

    throw ToolFailure('Docker Compose is not installed.');
  }

  Future<void> _requireDockerDaemon() async {
    final result = await _tryRunCaptured('docker', ['info']);
    if (result == null || result.exitCode != 0) {
      throw ToolFailure(
        'Docker is not running. Start Docker Desktop, OrbStack, or another '
        'Docker engine and try again.',
      );
    }
  }

  Future<void> _waitForBackend(String containerId, int timeoutSeconds) async {
    _log('Waiting up to ${timeoutSeconds}s for cue-api to become healthy');
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    var lastStatus = '';

    while (DateTime.now().isBefore(deadline)) {
      final result = await _tryRunCaptured('docker', [
        'inspect',
        '--format',
        '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}',
        containerId,
      ]);
      final status = result?.exitCode == 0 ? '${result!.stdout}'.trim() : '';

      if (status.isNotEmpty && status != lastStatus) {
        stdout.writeln('    status: $status');
        lastStatus = status;
      }

      if (status == 'healthy') {
        return;
      }
      if (status == 'exited' || status == 'dead') {
        await _showBackendLogs();
        throw ToolFailure('cue-api stopped before becoming healthy.');
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }

    await _showBackendLogs();
    throw ToolFailure(
      'cue-api did not become healthy within ${timeoutSeconds}s.',
    );
  }

  Future<void> _refreshRunningProxy(String service) async {
    final containerId = await compose.captureStdout(
      ['ps', '-q', service],
      projectDirectory,
      failOnError: false,
    );
    if (containerId.isEmpty) {
      return;
    }

    final inspect = await _tryRunCaptured('docker', [
      'inspect',
      '--format',
      '{{.State.Running}}',
      containerId,
    ]);
    if (inspect?.exitCode != 0 || '${inspect!.stdout}'.trim() != 'true') {
      return;
    }

    // Nginx resolves Compose service names while loading its configuration.
    // Reload it so it immediately uses the recreated API container's address.
    _log('Refreshing $service proxy');
    final reloadExitCode = await compose.runLive([
      'exec',
      '-T',
      service,
      'nginx',
      '-s',
      'reload',
    ], projectDirectory);
    if (reloadExitCode != 0) {
      stderr.writeln('Nginx reload failed; restarting $service instead.');
      await compose.runChecked(['restart', service], projectDirectory);
    }
  }

  Future<void> _showBackendLogs() async {
    stderr.writeln('\n--- Recent cue-api logs ---');
    await compose.runLive(['logs', '--tail=80', 'cue-api'], projectDirectory);
  }
}

final class ComposeCommand {
  const ComposeCommand(this.executable, this.prefixArguments);

  final String executable;
  final List<String> prefixArguments;

  Future<int> runLive(List<String> arguments, String workingDirectory) {
    return _runLive(executable, [
      ...prefixArguments,
      ...arguments,
    ], workingDirectory);
  }

  Future<void> runChecked(
    List<String> arguments,
    String workingDirectory,
  ) async {
    final result = await runLive(arguments, workingDirectory);
    if (result != 0) {
      throw ToolFailure(
        '$executable ${[...prefixArguments, ...arguments].join(' ')} '
        'failed with exit code $result.',
      );
    }
  }

  Future<String> captureStdout(
    List<String> arguments,
    String workingDirectory, {
    bool failOnError = true,
  }) async {
    final fullArguments = [...prefixArguments, ...arguments];
    final result = await Process.run(
      executable,
      fullArguments,
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      if (failOnError) {
        throw ToolFailure(
          '$executable ${fullArguments.join(' ')} failed with exit code '
          '${result.exitCode}: ${result.stderr}',
        );
      }
      return '';
    }
    return '${result.stdout}'.trim();
  }
}

final class ToolFailure implements Exception {
  const ToolFailure(this.message);

  final String message;
}

Future<ProcessResult?> _tryRunCaptured(
  String executable,
  List<String> arguments,
) async {
  try {
    return await Process.run(executable, arguments);
  } on ProcessException {
    return null;
  }
}

Future<int> _runLive(
  String executable,
  List<String> arguments,
  String workingDirectory,
) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final stdoutDone = stdout.addStream(process.stdout);
  final stderrDone = stderr.addStream(process.stderr);
  final result = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);
  return result;
}

void _log(String message) {
  stdout.writeln('\n==> $message');
}
