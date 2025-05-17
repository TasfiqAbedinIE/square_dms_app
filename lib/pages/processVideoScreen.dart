// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:dropdown_search/dropdown_search.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class VideoViewerScreen extends StatefulWidget {
//   const VideoViewerScreen({super.key});

//   @override
//   State<VideoViewerScreen> createState() => _VideoViewerScreenState();
// }

// class _VideoViewerScreenState extends State<VideoViewerScreen> {
//   final SupabaseClient supabase = Supabase.instance.client;

//   VideoPlayerController? _controller;
//   bool isLoading = true;

//   List<Map<String, String>> videoList = [];
//   String? selectedVideoName;

//   List<String> processNames = [];

//   @override
//   void initState() {
//     super.initState();
//     fetchVideoList();
//   }

//   Future<void> fetchVideoList() async {
//     try {
//       final response = await supabase
//           .from('process_video_list')
//           .select('process_name, video_id');

//       videoList =
//           (response as List)
//               .map(
//                 (e) => {
//                   'name': e['process_name'].toString(),
//                   'id': e['video_id'].toString(),
//                 },
//               )
//               .toList();

//       //////////////////////////////////////////////////
//       processNames = videoList.map((v) => v['name']!).toList();

//       if (videoList.isNotEmpty) {
//         selectedVideoName = videoList.first['name'];
//         await _initializePlayer(videoList.first['id']!);
//       }

//       setState(() {
//         isLoading = false;
//       });
//     } catch (e) {
//       print('Error fetching videos: $e');
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _initializePlayer(String googleDriveId) async {
//     try {
//       final videoUrl =
//           'https://drive.google.com/uc?export=download&id=$googleDriveId';

//       _controller?.dispose(); // Dispose old controller if any

//       _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
//       await _controller!.initialize();
//       setState(() {});
//       _controller!.play();
//     } catch (e) {
//       print('Video init error: $e');
//     }
//   }

//   void _onVideoChanged(String name) async {
//     final match = videoList.firstWhere((v) => v['name'] == name);
//     selectedVideoName = name;
//     await _controller?.pause();
//     await _initializePlayer(match['id']!);
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }

//   Widget buildVideoPlayer() {
//     if (_controller != null && _controller!.value.isInitialized) {
//       return Stack(
//         alignment: Alignment.center,
//         children: [
//           ClipRRect(
//             borderRadius: BorderRadius.circular(16),
//             child: AspectRatio(
//               aspectRatio: _controller!.value.aspectRatio,
//               child: Container(
//                 width: MediaQuery.of(context).size.width * 0.85,
//                 child: VideoPlayer(_controller!),
//               ),
//             ),
//           ),
//           IconButton(
//             iconSize: 56,
//             icon: Icon(
//               _controller!.value.isPlaying
//                   ? Icons.pause_circle
//                   : Icons.play_circle,
//               color: Colors.white.withOpacity(0.8),
//             ),
//             onPressed: () {
//               setState(() {
//                 _controller!.value.isPlaying
//                     ? _controller!.pause()
//                     : _controller!.play();
//               });
//             },
//           ),
//         ],
//       );
//     } else {
//       return const CircularProgressIndicator();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.amber,
//         title: const Text('Process Video'),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child:
//             isLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : Column(
//                   children: [
//                     DropdownSearch<String>(
//                       items: (filter, _) => processNames,
//                       // videoList.map((v) => v['name']!).toList(),
//                       selectedItem: selectedVideoName,
//                       popupProps: PopupProps.menu(showSearchBox: true),
//                       decoratorProps: DropDownDecoratorProps(
//                         decoration: InputDecoration(
//                           labelText: "Select Process",
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       ),
//                       onChanged: (value) {
//                         if (value != null) _onVideoChanged(value);
//                       },
//                     ),
//                     const SizedBox(height: 24),
//                     Center(child: buildVideoPlayer()),
//                   ],
//                 ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({super.key});

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool isLoading = true;

  List<Map<String, String>> videoList = [];
  String? selectedVideoName;

  @override
  void initState() {
    super.initState();
    fetchVideoList();
  }

  Future<void> fetchVideoList() async {
    try {
      final response = await supabase
          .from('process_video_list')
          .select('process_name, video_id');

      videoList =
          (response as List)
              .map(
                (e) => {
                  'name': e['process_name'].toString(),
                  'id': e['video_id'].toString(),
                },
              )
              .toList();

      if (videoList.isNotEmpty) {
        selectedVideoName = videoList.first['name'];
        await _initializePlayer(videoList.first['id']!);
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching videos: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _initializePlayer(String googleDriveId) async {
    final videoUrl =
        'https://drive.google.com/uc?export=download&id=$googleDriveId';

    // Dispose existing controllers if any
    await _videoController?.dispose();
    _chewieController?.dispose();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blueAccent,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.lightBlueAccent,
      ),
      allowFullScreen: true,
      allowPlaybackSpeedChanging: true,
    );

    setState(() {});
  }

  void _onVideoChanged(String name) async {
    final match = videoList.firstWhere((v) => v['name'] == name);
    selectedVideoName = name;
    await _initializePlayer(match['id']!);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Widget buildVideoPlayer() {
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        width: MediaQuery.of(context).size.width * 0.9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Chewie(controller: _chewieController!),
        ),
      );
    } else {
      return const CircularProgressIndicator();
    }
  }

  @override
  Widget build(BuildContext context) {
    final processNames = videoList.map((v) => v['name']!).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Video Viewer'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    DropdownSearch<String>(
                      items: (filter, _) => processNames,
                      selectedItem: selectedVideoName,
                      popupProps: const PopupProps.menu(showSearchBox: true),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: "Select Process",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) _onVideoChanged(value);
                      },
                    ),
                    const SizedBox(height: 24),
                    Expanded(child: Center(child: buildVideoPlayer())),
                  ],
                ),
      ),
    );
  }
}
