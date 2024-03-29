import 'dart:convert';
import 'dart:js';
// import 'dart:html';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:device_preview/device_preview.dart';

var client = http.Client();

List<RTCIceCandidate> candidates = [];
void main() {
  runApp(DevicePreview(
    enabled: true,
    tools: [
      ...DevicePreview.defaultTools,
    ],
    builder: (context) => MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  final sdpController = TextEditingController();

  @override
  dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderer();
    _createPeerConnecion().then((pc) {
      _peerConnection = pc;
    });
    // _getUserMedia();
    super.initState();
  }

  initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _createPeerConnecion() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream!);

    pc.onIceCandidate = (e) async {
      if (e.candidate != null) {
        print("New ice candidate");
        candidates.add(
            RTCIceCandidate(e.candidate, e.sdpMid.toString(), e.sdpMlineIndex));
      }
    };
    pc.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

    _localRenderer.srcObject = stream;
    // _localRenderer.mirror = true;

    return stream;
  }

  void _createOffer() async {
    print("Before gathering candidates");
    RTCSessionDescription description =
        await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
    _peerConnection!.setLocalDescription(description);

    while (_peerConnection?.iceGatheringState !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      print("Gathering candidates...");
      await Future.delayed(Duration(milliseconds: 500));
    }
    print("Creating offers with candidate:");
    print(candidates);

    for (RTCIceCandidate candidate in candidates) {
      description.sdp =
          description.sdp! + 'a=' + candidate.toMap()['candidate'] + '\r\n';
    }
    _peerConnection!.setLocalDescription(description);

    var session = parse(description.sdp.toString());
    print(session);
    print("SDP to be sent");
    print(json.encode(session));
    _offer = true;

    sendSDP(json.encode({
      'sdp': description.sdp.toString(),
      'type': description.type.toString(),
      "video_transform": "cartoon"
    }));
  }

  void _createAnswer() async {
    RTCSessionDescription description =
        await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());
    print(json.encode(session));
    // print(json.encode({
    //       'sdp': description.sdp.toString(),
    //       'type': description.type.toString(),
    //     }));

    _peerConnection!.setLocalDescription(description);
  }

  void sendSDP(body) async {
    var url = Uri.http('localhost:8080', 'offer');
    try {
      var response = await client.post(url, body: body);
      String jsonString = response.body;
      dynamic session = await jsonDecode('$jsonString');

      RTCSessionDescription description =
          new RTCSessionDescription(session['sdp'], session['type']);
      print(description.toMap());

      await _peerConnection!.setRemoteDescription(description);
    } catch (e) {
      print(e);
    }
  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    RTCSessionDescription description =
        new RTCSessionDescription(session['sdp'], session['type']);

    await _peerConnection!.setRemoteDescription(description);
  }

  void _addCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
  }

  SizedBox videoRenderers() => SizedBox(
      height: 500,
      width: 400,
      child: Column(children: [
        Flexible(
          child: new Container(
              key: new Key("local"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_localRenderer)),
        ),
        Flexible(
          child: new Container(
              key: new Key("remote"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer)),
        )
      ]));

  Row offerAndAnswerButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        new ElevatedButton(
          onPressed: _createOffer,
          child: Text('Bắt Đầu Nhận Dạng'),
          // color: Colors.amber,
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
            child: Container(
                child: Column(
          children: [
            videoRenderers(),
            offerAndAnswerButtons(),
          ],
        ))));
  }
}
