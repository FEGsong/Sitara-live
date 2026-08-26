/// Central place for anything environment-specific.
/// Update tokenServerUrl once you deploy the Node.js token server
/// (see the agora-token-server project) to Railway/Render/etc.
class AppConfig {
  static const String tokenServerUrl = 'https://your-token-server.example.com';
}
