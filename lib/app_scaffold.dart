library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/app.dart'
    show appServerUri, inviteOthersConfig;
import 'package:seedpod/screens/browse_files.dart';
import 'package:seedpod/providers/app_state.dart';
import 'package:seedpod/screens/childcare_screen.dart';
import 'package:seedpod/screens/health_screen.dart';
import 'package:seedpod/screens/home_screen.dart';
import 'package:seedpod/screens/modules_screen.dart';
import 'package:seedpod/screens/share_screen.dart';
import 'package:seedpod/screens/timeline_screen.dart';

final _scaffoldController = SolidScaffoldController();

const appScaffold = AppScaffold();

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final modulePrefs = context.watch<AppState>().modulePrefs;

    final menu = [
      const SolidMenuItem(
        icon: Icons.home_outlined,
        title: 'Home',
        tooltip: '''

            **Home**

            Your baby\'s dashboard with quick log access and today\'s summary.

            ''',
        child: HomeScreen(),
      ),
      const SolidMenuItem(
        icon: Icons.timeline,
        title: 'Timeline',
        tooltip: '''

            **Timeline**

            All log entries in chronological order.

            ''',
        child: TimelineScreen(),
      ),
      const SolidMenuItem(
        icon: Icons.favorite_outline,
        title: 'Health',
        tooltip: '''

            **Health Records**

            Growth charts, vaccine schedule, and feeding log.

            ''',
        child: HealthScreen(),
      ),
      if (modulePrefs.isEnabled('childcare'))
        const SolidMenuItem(
          icon: Icons.school_outlined,
          title: 'Childcare',
          tooltip: '''

            **Childcare & Schools**

            Waitlist tracker for childcare centres and schools.

            ''',
          child: ChildcareScreen(),
        ),
      const SolidMenuItem(
        icon: Icons.extension_outlined,
        title: 'Modules',
        tooltip: '''

            **Modules**

            Enable or disable optional tracking features.

            ''',
        child: ModulesScreen(),
      ),
      const SolidMenuItem(
        icon: Icons.people_outline,
        title: 'Share',
        tooltip: '''

            **Share Access**

            Grant family and caregivers access to your baby\'s POD data.

            ''',
        child: ShareScreen(),
      ),
    ];

    return SolidScaffold(
      controller: _scaffoldController,
      hideNavRail: false,
      enableProfile: true,
      onLogout: (context) => SolidAuthHandler.instance.handleLogout(context),
      menu: menu,
      appBar: SolidAppBarConfig(
        title: 'SeedPod',
        versionConfig: const SolidVersionConfig(
          changelogUrl:
              'https://github.com/YidingQiu/seedpod/blob/main/CHANGELOG.md',
          showUpdateButton: false,
        ),
        overflowItems: [
          SolidOverflowMenuItem(
            id: 'browse_files',
            icon: Icons.folder_open_outlined,
            label: 'Browse POD Files',
            onSelected: () =>
                _scaffoldController.navigateToSubpage(const BrowseFiles()),
          ),
        ],
      ),
      statusBar: const SolidStatusBarConfig(
        serverInfo: SolidServerInfo(serverUri: appServerUri),
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
