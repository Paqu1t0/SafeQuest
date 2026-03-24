import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> _play(String fileName) async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.stop();
      await _player.play(AssetSource(fileName));
    } catch (e) {
      print('SoundService error: $e');
    }
  }

  static Future<void> playCorrect()  async => await _play('sounds/correct.wav');
  static Future<void> playWrong()    async => await _play('sounds/wrong.wav');
  static Future<void> playVictory()  async => await _play('sounds/victory.wav');
  static Future<void> playFail()     async => await _play('sounds/fail.wav');
}