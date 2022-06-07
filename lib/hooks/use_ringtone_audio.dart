import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:just_audio/just_audio.dart';
import 'package:videofi_mark2/constants.dart';

class RingtoneAudio {
  final Future<void> Function() play;
  final Future<void> Function() stop;
  final bool isPlaying;
  RingtoneAudio(
      {required this.play, required this.stop, required this.isPlaying});
}

RingtoneAudio useRingtoneAudio(
  Future<AudioSource> Function() getSource, {
  double volume = 1,
}) {
  final player = useState(AudioPlayer());
  final isPlaying = useState(false);

  Future<void> play() async {
    final audioPlayer = player.value;

    await audioPlayer.setAudioSource(await getSource());
    await audioPlayer.setVolume(volume);
    await audioPlayer.setLoopMode(LoopMode.all);
    await audioPlayer.setAndroidAudioAttributes(
      kRingtoneAndroidAudioAttributes,
    );

    audioPlayer.play();
    isPlaying.value = true;
  }

  Future<void> stop() async {
    await player.value.stop();
    isPlaying.value = false;
  }

  useEffect(() {
    return () {
      player.value.dispose();
    };
  }, []);

  return RingtoneAudio(play: play, stop: stop, isPlaying: isPlaying.value);
}
