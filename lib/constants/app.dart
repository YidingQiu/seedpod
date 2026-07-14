/// Seedpod - app-wide constants.
///
/// This file was generated from the `solidui` app template
/// (`dart run solidui:create`). Edit it freely to suit your app.

library;

import 'package:solidui/solidui.dart'
    show SolidFileUploadConfig, SolidInviteOthersConfig;

/// Application title displayed as the window title.

const String appTitle = 'SeedPod - Baby Tracker';

// ── Solid app registration ───────────────────────────────────────────────────

/// Solid OIDC client registration for Seedpod.
///
/// These values identify the app to the Solid server during login. They are
/// gathered here so you can update them in one place when you deploy to your
/// own infrastructure.
///
/// [appClientId] MUST resolve to a publicly hosted client profile document
/// (the template in the `solid/` folder) whose `redirect_uris` and
/// `post_logout_redirect_uris` list exactly the URIs below. If they do not
/// match, the identity provider will reject the login. See the `solid/README`
/// and https://solidproject.org for more information.
///
/// Note: the custom redirect scheme drops underscores from the project name
/// ('au.solidcommunity.seedpod'), because a URI scheme may not contain
/// underscores. Every other identifier keeps the full project name.

const String appClientId =
    'https://yidingqiu.github.io/seedpod/solid/client-profile.jsonld';

/// One redirect URI per platform; SolidUI selects the right one at runtime
/// based on the current platform. Keep this list in step with the
/// `redirect_uris` in the hosted client profile document.

const List<String> appRedirectUris = [
  'https://yidingqiu.github.io/seedpod/solid/redirect.html',
  'au.solidcommunity.seedpod://redirect',
  'http://localhost:4400/solid/redirect.html',
];

/// Where the identity provider returns the user after logging out. By default
/// we reuse the login redirect URIs, mirroring the hosted client profile.

const List<String> appPostLogoutRedirectUris = appRedirectUris;

/// The application folder created on the user's POD to store Seedpod data.

const String appPodDirectory = 'seedpod';

/// Homepage opened from the login page's info button. Point this at your own
/// project page or documentation.

const String appLink = 'https://github.com/YidingQiu/seedpod';

/// Shared upload configuration for every `SolidFile` view in Seedpod.
///
/// Restricts the file picker (both the toolbar Upload button and the side
/// upload panel) to Markdown and plain text files. Extensions are matched
/// case-insensitively by SolidUI, so users may still pick `.MD` / `.TXT`.
/// Adjust `allowedExtensions` to suit the file types your app manages.

const SolidFileUploadConfig appUploadConfig = SolidFileUploadConfig(
  allowedExtensions: ['md', 'txt'],
);

/// Public URL where Seedpod is hosted. Used by the Invite Others
/// feature to send a working link to the recipient.

const String appUrl = 'https://yidingqiu.github.io/seedpod/';

/// Application-wide Invite Others configuration shared by the
/// AppBar share button and the App Info dialog so that users can
/// invite others to set up their POD and try Seedpod.

const SolidInviteOthersConfig inviteOthersConfig = SolidInviteOthersConfig(
  applicationName: 'Seedpod',
  appUrl: appUrl,
  appDescription:
      'manage/share resources hosted on your Solid server using Seedpod',
  messageTemplate: '''
You might like to try the {appName} app, available online here:

{appUrl}

Signing into {appName} will set up your data vault so you can manage and
exchange files privately with other Solid users.

''',
  subject: 'Try the Seedpod app on your Solid POD',
  tooltip: '''

  **Invite Others**

  Tap to invite someone else to try Seedpod. You can copy the
  invitation to the clipboard or share it through any messaging app
  installed on your device.

  ''',
);
