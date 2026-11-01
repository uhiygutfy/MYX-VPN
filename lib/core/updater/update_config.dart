/// Where MYX-VPN looks for new versions.
///
/// Every GitHub Release of this repo carries a `latest.json` manifest (built
/// by `.github/workflows/release.yml`). Installed apps read it from the
/// "latest release" download URL, which isn't subject to GitHub's API rate
/// limit; the REST API is only used as a fallback.
class UpdateConfig {
  static const githubRepo = 'uhiygutfy/MYX-VPN';

  static const manifestUrl =
      'https://github.com/$githubRepo/releases/latest/download/latest.json';
  static const apiLatestUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';
  static const releasesPage = 'https://github.com/$githubRepo/releases/latest';

  /// Background check cadence while the app is open.
  static const checkInterval = Duration(hours: 6);

  /// How long "Later" hides the prompt for the same version.
  static const snoozeFor = Duration(hours: 24);
}
