library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:solidui/solidui.dart';

import 'package:seedpod/app_scaffold.dart';
import 'package:seedpod/constants/app.dart';
import 'package:seedpod/constants/theme.dart' as app_theme;
import 'package:seedpod/providers/app_state.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: SolidThemeApp(
        debugShowCheckedModeBanner: false,
        title: appTitle,
        theme: app_theme.buildAppTheme(),
        home: SolidLogin(
          title: 'SeedPod\nBaby Tracker',
          image: const AssetImage('assets/images/app_image.jpg'),
          logo: const AssetImage('assets/images/app_icon.png'),
          appDirectory: appPodDirectory,
          link: appLink,
          clientId: appClientId,
          redirectUris: appRedirectUris,
          postLogoutRedirectUris: appPostLogoutRedirectUris,
          child: appScaffold,
        ),
      ),
    );
  }
}
