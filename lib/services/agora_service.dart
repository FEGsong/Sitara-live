import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../config.dart';

/// Thin wrapper around the Agora SDK + our token server.
/// Audio-only — used for voice-call style live rooms with seats.
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

  /// Joins an audio channel. [isHost] controls whether this device
  /// starts able to speak (broadcaster) or starts as a silent
  /// listener (audience) — use [setSpeakingRole] later to switch
  /// a listener into a seat, or a seat-holder back to listening.
  Future<RtcEngine> joinChannel({
    required String channel,
    required bool isHost,
  }) async {
    final data = await _fetchToken(
        channel: channel, role: isHost ? 'host' : 'audience');
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: data['appId'] as String));
    await engine.enableAudio();
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
        publishMicrophoneTrack: isHost,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
    _engine = engine;
    return engine;
  }

  /// Switches this device between "can speak" (seated) and
  /// "listen only" — called when a user takes or leaves a seat.
  Future<void> setSpeakingRole(bool canSpeak) async {
    if (_engine == null) return;
    await _engine!.setClientRole(
      role: canSpeak
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await _engine!.muteLocalAudioStream(!canSpeak);
  }

  /// Mutes/unmutes this device's own microphone (only meaningful
  /// while seated / broadcasting).
  Future<void> toggleMic(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}
