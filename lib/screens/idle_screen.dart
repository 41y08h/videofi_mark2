import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:videofi_mark2/constants.dart';
import 'package:videofi_mark2/hooks/use_event_stream.dart';
import 'package:videofi_mark2/hooks/use_event_subscription.dart';
import 'package:videofi_mark2/hooks/use_ringtone_audio.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/providers/chat.dart';
import 'package:videofi_mark2/screens/call_screen.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/dispose_stream.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:videofi_mark2/utils/audio.dart';

class IdleScreen extends StatefulHookConsumerWidget {
  const IdleScreen({
    Key? key,
  }) : super(key: key);

  @override
  _IdleScreenState createState() => _IdleScreenState();
}

class _IdleScreenState extends ConsumerState<IdleScreen> {
  @override
  Widget build(BuildContext context) {
    final remoteIdController = useTextEditingController();
    final isTryingToCall = useState(false);
    final isWSConnected = useState(false);

    final outgoingAudio = useRingtoneAudio(
      () async => assetToAudioSource(kOutgoingRingAssetPath),
      volume: 0.1,
    );
    final incomingAudio = useRingtoneAudio(() async {
      return AudioSource.uri(Uri.parse(await getDefaultRingtoneUri()));
    });

    useEventStream(
      FlutterAndroidVolumeKeydown.stream,
      onEvent: (_) => incomingAudio.stop(),
      active: incomingAudio.isPlaying,
    );

    void showToast(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }

    void wsOnConnect(_) {
      final socket = SocketConnection().socket;
      socket.emit("get-id");
    }

    void wsOnIdCallback(dynamic id) {
      final chat = ref.read(chatProvider.notifier);
      chat.state = chat.state.copyWith(
        localId: id,
      );
      isWSConnected.value = true;
    }

    void wsOnDisconnect(_) {
      isWSConnected.value = false;
    }

    void wsOnOffer(data) async {
      final chat = ref.read(chatProvider.notifier);
      final signal = data['signal'];
      chat.state = chat.state.copyWith(
        remoteDescription: RTCSessionDescription(
          signal['sdp'],
          signal['type'],
        ),
        remoteId: data['remoteId'],
        callState: CallState.incoming,
      );

      Navigator.pushNamed(context, CallScreen.routeName);
    }

    void wsOnOfferEnded(data) async {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
        remoteId: null,
        remoteDescription: null,
      );

      showToast('Missed call');
    }

    void wsOnOfferRejected(data) async {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
        remoteId: null,
        localStream: null,
      );

      showToast('Rejected');
    }

    void wsOnAnswer(data) async {
      final signal = data['signal'];
      final answer = RTCSessionDescription(
        signal['sdp'],
        signal['type'],
      );
      final pc = await PeerConnection().pc;
      await pc.setRemoteDescription(answer);
    }

    void wsOnOutgoingTimeout(data) async {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
        localStream: null,
      );

      showToast('Call timed out');
    }

    void wsOnIncomingTimeout(data) async {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
      );

      showToast('Call timed out');
    }

    void wsOnCallDisconnected(_) async {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);
      disposeStream(chat.state.remoteStream);

      chat.state = chat.state.copyWith(
        localStream: null,
        remoteStream: null,
        remoteId: null,
        callState: CallState.idle,
        remoteDescription: null,
      );

      showToast('Call ended');
    }

    void wsOnOpponendDisconnected(_) async {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);
      disposeStream(chat.state.remoteStream);

      chat.state = chat.state.copyWith(
        localStream: null,
        remoteStream: null,
        remoteId: null,
        callState: CallState.idle,
        remoteDescription: null,
      );

      showToast('Opponent disconnected');
    }

    void wsOnIceCandidate(data) async {
      final chat = ref.read(chatProvider.notifier);

      final signal = data['candidate'];
      final candidate = RTCIceCandidate(
        signal['candidate'],
        signal['sdpMid'],
        signal['sdpMLineIndex'],
      );
      chat.state = chat.state.copyWith(
        remoteCandidates: [...chat.state.remoteCandidates, candidate],
      );
    }

    void onCallPressed() async {
      isTryingToCall.value = true;

      final chat = ref.read(chatProvider.notifier);
      final socket = SocketConnection().socket;
      final pc = await PeerConnection().pc;
      final remoteId = int.tryParse(remoteIdController.text);

      try {
        final localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': true,
        });

        chat.state = chat.state.copyWith(localStream: localStream);
        localStream.getTracks().forEach((element) {
          pc.addTrack(element, localStream);
        });
      } catch (error) {
        showToast("Camera permission denied");

        return;
      }
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      socket.emitWithAck('offer', {
        'remoteId': remoteId,
        'signal': offer.toMap(),
      }, ack: (data) async {
        if (data['error'] == null) {
          chat.state = chat.state.copyWith(
            callState: CallState.outgoing,
            remoteId: remoteId,
          );
          Navigator.pushNamed(context, CallScreen.routeName);
          isTryingToCall.value = false;
        } else {
          isTryingToCall.value = false;

          final errorMessage = data['error']['message'];
          showToast(errorMessage);

          PeerConnection().dispose();
          disposeStream(chat.state.localStream);

          chat.state = chat.state.copyWith(
            localStream: null,
            callState: CallState.idle,
          );
        }
      });
    }

    void pcOnIceCandidate(RTCIceCandidate candidate) {
      final socket = SocketConnection().socket;
      socket.emit("ice-candidate", {
        'candidate': candidate.toMap(),
      });
    }

    void pcOnTrack(event) {
      final chat = ref.read(chatProvider.notifier);

      if (event.track.kind != 'video') return;
      chat.state = chat.state.copyWith(
        remoteStream: event.streams.first,
        callState: CallState.connected,
      );
    }

    void pcOnConnectionState(RTCPeerConnectionState state) {
      final chat = ref.read(chatProvider.notifier);

      if (state != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        return;
      }

      chat.state = chat.state.copyWith(
        callState: CallState.connected,
      );
    }

    void onCallStateChanged(CallState? previous, CallState current) {
      if (current == CallState.outgoing) {
        outgoingAudio.play();
      } else if (current == CallState.incoming) {
        incomingAudio.play();
      } else {
        outgoingAudio.stop();
        incomingAudio.stop();
      }
    }

    useEventSubscription('connect', wsOnConnect);
    useEventSubscription('get-id/callback', wsOnIdCallback);
    useEventSubscription("disconnect", wsOnDisconnect);

    useEventSubscription("offer", wsOnOffer);
    useEventSubscription("offer-ended", wsOnOfferEnded);
    useEventSubscription("offer-rejected", wsOnOfferRejected);
    useEventSubscription("answer", wsOnAnswer);
    useEventSubscription("outgoing-time-out", wsOnOutgoingTimeout);
    useEventSubscription("incoming-time-out", wsOnIncomingTimeout);
    useEventSubscription("ice-candidate", wsOnIceCandidate);
    useEventSubscription("call-disconnected", wsOnCallDisconnected);
    useEventSubscription("opponent-disconnected", wsOnOpponendDisconnected);

    useEffect(() {
      PeerConnection().onConnectionState(pcOnConnectionState);
      PeerConnection().onIceCandidate(pcOnIceCandidate);
      PeerConnection().onTrack(pcOnTrack);

      return () {
        final chat = ref.read(chatProvider);
        disposeStream(chat.localStream);
        disposeStream(chat.remoteStream);
        SocketConnection().socket.dispose();
        PeerConnection().dispose();
      };
    }, []);

    final localId = ref.watch(
      chatProvider.select((value) => value.localId.toString()),
    );
    final isCallInProgress = ref.watch(
      chatProvider.select((value) => value.callState != CallState.idle),
    );
    ref.listen<CallState>(
      chatProvider.select((value) => value.callState),
      onCallStateChanged,
    );

    if (isWSConnected.value == false) {
      return const Scaffold(
        body: Center(
          child: Text("Connecting..."),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (isCallInProgress)
              Positioned(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, CallScreen.routeName);
                  },
                  child: Container(
                    height: 50,
                    width: MediaQuery.of(context).size.width,
                    color: Colors.green,
                    child: const Center(
                      child: Text(
                        "Tap to view call",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // A green dot
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your ID",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          localId,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  height: 50,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: remoteIdController,
                    onChanged: (_) {
                      // To update the state of the button
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Remote ID',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    child: Text(isTryingToCall.value ? '...' : 'Call'),
                    onPressed:
                        remoteIdController.text.isEmpty || isTryingToCall.value
                            ? null
                            : onCallPressed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
