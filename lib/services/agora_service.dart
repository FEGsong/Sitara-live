import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';

/// Thin wrapper around the Agora SDK + our token server.
/// Audio-only — used for voice-call style live rooms with seats.
class AgoraService {
  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  int _myAgoraUid = 0;

  /// Called with the Agora uids currently detected as speaking —
  /// used to show the "speaking" ring around a seat.
  void Function(List<int> speakingUids)? onSpeakingUpdate;

  // ---- Room music state (read by the Music sheet) ----
  final ValueNotifier<String?> musicName = ValueNotifier<String?>(null);
  final ValueNotifier<bool> musicPlaying = ValueNotifier<bool>(false);
  int musicVolume = 60;

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
      throw Exception(
          'Microphone permission denied. Please allow microphone access in your phone settings.');
    }

    _myAgoraUid = uidToAgoraUid(myUid);

    final data = await _fetchToken(
        channel: channel, role: isHost ? 'host' : 'audience');
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: data['appId'] as String));

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
          final speaking = speakers
              .where((s) => (s.volume ?? 0) > 15)
              .map((s) {
            final u = s.uid ?? 0;
            // Agora reports the local user as uid 0.
            return u == 0 ? _myAgoraUid : u;
          }).toList();
          onSpeakingUpdate?.call(speaking);
        },
        onAudioMixingStateChanged: (state, reason) {
          if (state == AudioMixingStateType.audioMixingStateStopped ||
              state == AudioMixingStateType.audioMixingStateFailed) {
            musicPlaying.value = false;
            musicName.value = null;
          }
        },
      ),
    );

    await engine.enableAudio();
    await engine.enableAudioVolumeIndication(
        interval: 300, smooth: 3, reportVad: true);
    await engine.setClientRole(
      role: isHost
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await engine.joinChannel(
      token: data['token'] as String,
      channelId: channel,
      uid: _myAgoraUid,
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
    if (canSpeak) await _engine!.adjustRecordingSignalVolume(100);
  }

  /// Mutes only the microphone voice (the stream keeps publishing) so
  /// music mixed into the stream keeps playing while the host is muted.
  Future<void> toggleMic(bool mute) async {
    await _engine?.adjustRecordingSignalVolume(mute ? 0 : 100);
  }

  // ---- Music (plays a file from this phone into the room) ----

  Future<void> startMusic(String path, String name) async {
    final e = _engine;
    if (e == null) throw Exception('Not connected to the room');
    await e.startAudioMixing(filePath: path, loopback: false, cycle: 1);
    await e.adjustAudioMixingVolume(musicVolume);
    musicName.value = name;
    musicPlaying.value = true;
  }

  Future<void> pauseMusic() async {
    await _engine?.pauseAudioMixing();
    musicPlaying.value = false;
  }

  Future<void> resumeMusic() async {
    await _engine?.resumeAudioMixing();
    musicPlaying.value = true;
  }

  Future<void> stopMusic() async {
    await _engine?.stopAudioMixing();
    musicPlaying.value = false;
    musicName.value = null;
  }

  Future<void> setMusicVolume(int v) async {
    musicVolume = v;
    await _engine?.adjustAudioMixingVolume(v);
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    musicPlaying.value = false;
    musicName.value = null;
  }
}
