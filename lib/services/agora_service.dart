import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../config.dart';

/// Thin wrapper around the Agora SDK + our token server.
/// Screens call [joinChannel]/[leaveChannel] and listen to the
/// returned [RtcEngine] for video/audio callbacks.
class AgoraService {
  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  /// Fetches a secure token from our own backend — never hardcode
  /// the App Certificate in the app itself.
  Future<Map<String, dynamic>> _fetchToken({
    required String channel,
    required String role, // 'host' or 'audience'
  }) async {
    final uri = Uri.parse(
        '${AppConfig.tokenServerUrl}/rtc-token?channel=$channel&role=$role');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Token server error: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<RtcEngine> joinChannel({
    required String channel,
    required bool isHost,
  }) async {
    final data =
        await _fetchToken(channel: channel, role: isHost ? 'host' : 'audience');

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: data['appId'] as String));
    await engine.enableVideo();
    await engine.setClientRole(
      role: isHost
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    await engine.joinChannel(
      token: data['token'] as String,
      channelId: channel,
      uid: 0,
      options: ChannelMediaOptions(
        clientRoleType: isHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      ),
    );

    _engine = engine;
    return engine;
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}
