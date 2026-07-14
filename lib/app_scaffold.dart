library;

import 'package:flutter/material.dart';

import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/app.dart';
import 'package:seedpod/screens/health_screen.dart';
import 'package:seedpod/screens/home_screen.dart';
import 'package:seedpod/screens/share_screen.dart';
import 'package:seedpod/screens/timeline_screen.dart';

final _scaffoldController = SolidScaffoldController();

const appScaffold = AppScaffold();

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return SolidScaffold(
      controller: _scaffoldController,
      hideNavRail: false,
      enableProfile: true,
      onLogout: (context) => SolidAuthHandler.instance.handleLogout(context),
      menu: const [
        SolidMenuItem(
          icon: Icons.home_outlined,
          title: 'Home',
          tooltip: '''

            **Home**

            Your baby\'s dashboard with quick log access and today\'s summary.

            ''',
          child: HomeScreen(),
        ),
        SolidMenuItem(
          icon: Icons.timeline,
          title: 'Timeline',
          tooltip: '''

            **Timeline**

            All log entries in chronological order.

            ''',
          child: TimelineScreen(),
        ),
        SolidMenuItem(
          icon: Icons.favorite_outline,
          title: 'Health',
          tooltip: '''

            **Health Records**

            Growth charts, vaccine schedule, and feeding log.

            ''',
          child: HealthScreen(),
        ),
        SolidMenuItem(
          icon: Icons.people_outline,
          title: 'Share',
          tooltip: '''

            **Share Access**

            Grant family and caregivers access to your baby\'s POD data.

            ''',
          child: ShareScreen(),
        ),
      ],
      appBar: SolidAppBarConfig(
        title: 'SeedPod',
        versionConfig: const SolidVersionConfig(
          changelogUrl:
              'https://github.com/YidingQiu/seedpod/blob/main/CHANGELOG.md',
          showUpdateButton: false,
        ),
      ),
      statusBar: const SolidStatusBarConfig(
        serverInfo: SolidServerInfo(serverUri: SolidConfig.defaultServerUrl),
        loginStatus: SolidLoginStatus(),
        securityKeyStatus: SolidSecurityKeyStatus(),
      ),
      aboutConfig: SolidAboutConfig(
        applicationName: 'SeedPod',
        applicationIcon: Image.asset(
          'assets/images/app_icon.png',
          width: 64,
          height: 64,
        ),
        applicationLegalese: '© SeedPod 2026',
        text: '''

        SeedPod is a private baby tracker that stores all data
        on your personal Solid POD — not on any central server.

        Track growth, sleep, feeding, milestones, and health records
        privately and securely. Share with family caregivers on your
        own terms.

        Built with [solidpod](https://pub.dev/packages/solidpod) and
        [solidui](https://pub.dev/packages/solidui) for the
        Australian Solid Community.

        ''',
      ),
      themeToggle: const SolidThemeToggleConfig(
        enabled: true,
        showInAppBarActions: true,
      ),
      inviteConfig: inviteOthersConfig,
      child: const HomeScreen(),
    );
  }
}
