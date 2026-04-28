import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  // Um player por tipo de som para evitar conflitos
  static final AudioPlayer _correctPlayer = AudioPlayer();
  static final AudioPlayer _wrongPlayer   = AudioPlayer();
  static final AudioPlayer _victoryPlayer = AudioPlayer();
  static final AudioPlayer _failPlayer    = AudioPlayer();

  static Future<void> _configure(AudioPlayer player) async {
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(1.0);
    await player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    ));
  }

  static Future<void> playCorrect() async {
    try {
      await _configure(_correctPlayer);
      await _correctPlayer.play(AssetSource('sounds/correct.wav'));
    } catch (e) { debugPrint('SoundService: $e'); }
  }

  static Future<void> playWrong() async {
    try {
      await _configure(_wrongPlayer);
      await _wrongPlayer.play(AssetSource('sounds/wrong.wav'));
    } catch (e) { debugPrint('SoundService: $e'); }
  }

  static Future<void> playVictory() async {
    try {
      await _configure(_victoryPlayer);
      await _victoryPlayer.play(AssetSource('sounds/victory.wav'));
    } catch (e) { debugPrint('SoundService: $e'); }
  }

  static Future<void> playFail() async {
    try {
      await _configure(_failPlayer);
      await _failPlayer.play(AssetSource('sounds/fail.wav'));
    } catch (e) { debugPrint('SoundService: $e'); }
  }
}