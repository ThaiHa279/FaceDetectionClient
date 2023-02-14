import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localRenderer = RTCVideoRenderer();
  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;

  @override
  void initState() {
    // TODO: implement initState
    initRenderer();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });

    super.initState();
  }

  initRenderer() async {
    await _localRenderer.initialize();
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
          ]
        }
      ]
    };

    _localStream = await _getUserMedia();
    RTCPeerConnection pc = await createPeerConnection(configuration);
    pc.addStream(_localStream);
  }

  _getUserMedia() async {
    // var stream = await navigator.mediaDevices
    //     .getUserMedia({'video': true, 'audio': false});
    final Map<String, dynamic> MediaConstraints = {
      'audio': 'false',
      'video': {'facingMode': 'user'},
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(MediaConstraints);
    _localRenderer.srcObject = stream;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: new Container(
          child: new RTCVideoView(_localRenderer),
        ),
      ),
    );
  }
}
