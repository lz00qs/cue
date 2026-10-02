import 'package:cue/ui/about_cue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('Dev version identifies the build and source used in bug reports', () {
    const info = CueAppInfo(
      version: '1.0.1',
      buildNumber: '1042',
      channel: 'dev',
      commit: 'abcdef0123450000000000000000000000000000',
    );
    expect(info.versionLabel, 'Dev · 1.0.1 (1042) · abcdef012345');
  });

  test('Installed package metadata supplies the build number', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Cue',
      packageName: 'top.hylcreative.cue',
      version: '1.0.1',
      buildNumber: '1042',
      buildSignature: '',
    );
    final info = await loadCueAppInfo();
    expect(info.version, '1.0.1');
    expect(info.buildNumber, '1042');
    expect(info.channel, cueReleaseChannel);
    expect(info.commit, cueReleaseCommit);
    if (cueReleaseChannel == 'dev') {
      expect(info.versionLabel, contains('Dev · 1.0.1 (1042)'));
    } else {
      expect(info.versionLabel, '1.0.1 (1042)');
    }
  });
}
