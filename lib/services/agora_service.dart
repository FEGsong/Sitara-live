import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';

/// Thin wrapper around the Agora SDK + our token server.
/// Audio-only — used for voice-call style live rooms with seats.
class AgoraService {
  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  /// Called with the list of currently-speaking Agora uids (and
  /// their volume) whenever Agora reports an audio volume update —
  /// used to show a "speaking" ring around the active seat.
  void Function(List<int> speakingUids)? onSpeakingUpdate;

  /// Converts a Firestore uid (string) into a stable positive
  /// integer Agora can use as a numeric uid — needed so we can
  /// later match Agora's volume-indication uid back to a seat.
  static int uidToAgoraUid(String uid) => uid.hashCode & 0x7FFFFFFF;

  Future<Map<String, dynamic>> _fetchToken({
    required String channel,
    required String role,
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
    required String myUid,
  }) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Microphone permission denied. Please allow microphone access in your phone settings.');
    }

    final data = await _fetchToken(
        channel: channel, role: isHost ? 'host' : 'audience');
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: data['appId'] as String));

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
          // Only report uids that are actually making noise, using a
          // small threshold to ignore background/mic noise.
          final speaking = speakers
              .where((s) => s.volume != null && s.volume! > 15)
              .map((s) => s.uid ?? 0)
              .toList();
          onSpeakingUpdate?.call(speaking);
        },
      ),
    );

    await engine.enableAudio();
    await engine.enableAudioVolumeIndication(interval: 300, smooth: 3, reportVad: true);
    await engine.setClientRole(
      role: isHost
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await engine.joinChannel(
      token: data['token'] as String,
      channelId: channel,
      uid: uidToAgoraUid(myUid),
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

  Future<void> setSpeakingRole(bool canSpeak) async {
    if (_engine == null) return;
    await _engine!.setClientRole(
      role: canSpeak
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await _engine!.muteLocalAudioStream(!canSpeak);
  }

  Future<void> toggleMic(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}
