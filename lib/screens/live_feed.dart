import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../services/stream_service.dart';

class LiveFeed extends StatefulWidget {
  const LiveFeed({super.key});

  @override
  State<LiveFeed> createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed> {
  // late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // _videoController =
    //     VideoPlayerController.asset('assets/videos/live_feed.mp4')
    //       ..initialize().then((_) {
    //         setState(() {});
    //         _videoController.play();
    //       });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // _videoController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      color: Colors.black,
      child: SizedBox.expand(
        child: Mjpeg(
            stream: StreamService.streamUrl,
            isLive: true,
            error: (context, error, stack) {
              return Text('Erro ao carregar o stream');
            },
            fit: BoxFit.contain),
      ),
    ));
  }
}
