import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'widgets/screen_select_dialog.dart';
import '../signaling.dart';
import 'dart:developer';

/*
 * getDisplayMedia sample
 */
class DisplayMedia extends StatefulWidget {
  static String tag = 'get_display_media_sample';

  @override
  _DisplayMediaState createState() => _DisplayMediaState();
}

class _DisplayMediaState extends State<DisplayMedia> {
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inSharing = false;
  DesktopCapturerSource? selected_source_;
  Signaling signaling = Signaling();
  String? roomId;

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  @override
  void deactivate() {
    super.deactivate();
    if (_inSharing) {
      _stop();
    }
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> selectScreenSourceDialog(BuildContext context) async {
    if (WebRTC.platformIsDesktop) {
      final source = await showDialog<DesktopCapturerSource>(
        context: context,
        builder: (context) => ScreenSelectDialog(),
      );
      if (source != null) {
        await _makeCall(source);
      }
    } else {
      await _makeCall(null);
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _makeCall(DesktopCapturerSource? source) async {
    setState(() {
      selected_source_ = source;
    });

    try {
      var stream =
          await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        'video': selected_source_ == null
            ? true
            : {
                'deviceId': {'exact': selected_source_!.id},
                'mandatory': {'frameRate': 30.0}
              }
      });
      stream.getVideoTracks()[0].onEnded = () {
        print(
            'By adding a listener on onEnded you can: 1) catch stop video sharing on Web');
      };

      _localStream = stream;
      _localRenderer.srcObject = _localStream;
       roomId = await signaling.createRoom(_localRenderer);
    } catch (e) {
      print(e.toString());
    }
    if (!mounted) return;

    setState(() {
      _inSharing = true;
    });
  }

  Future<void> _stop() async {
    try {
      if (kIsWeb) {
        _localStream?.getTracks().forEach((track) => track.stop());
      }
      await _localStream?.dispose();
      _localStream = null;
      _localRenderer.srcObject = null;
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _hangUp() async {
    await _stop();
    setState(() {
      _inSharing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Center(
              child: Container(
              width: MediaQuery.of(context).size.width,
              color: Colors.white10,
              child: Stack(children: <Widget>[
                if (_inSharing)
                  Container(
                    margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    decoration: BoxDecoration(color: Colors.black54),
                    child: RTCVideoView(_localRenderer),
                  )
          
              ]),
            )
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _inSharing ? _hangUp() : selectScreenSourceDialog(context);
        },
        tooltip: _inSharing ? 'Stop' : 'Pear',
        child: Icon(_inSharing ? Icons.cancel  : Icons.people_outline),
      ),
    );
  }
}
