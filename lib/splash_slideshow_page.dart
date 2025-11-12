import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'main.dart'; // replace with your main page import

class SplashSlideshowPage extends StatefulWidget {
  const SplashSlideshowPage({super.key});

  @override
  State<SplashSlideshowPage> createState() => _SplashSlideshowPageState();
}

class _SplashSlideshowPageState extends State<SplashSlideshowPage> {
  final PageController _pageController = PageController();
  late Timer _timer;
  int _currentIndex = 0;
  VideoPlayerController? _videoController;

  final List<Map<String, dynamic>> slides = [
    {
      'type': 'image',
      'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
      'caption': 'Discover the calm waves of new adventures.'
    },
    {
      'type': 'video',
      'url':
          'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4',
      'caption': 'Every journey starts with a single step.'
    },
    {
      'type': 'image',
      'url': 'https://images.unsplash.com/photo-1526778548025-fa2f459cd5c1',
      'caption': 'Taste cultures, not just cuisines.'
    },
    {
      'type': 'image',
      'url': 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
      'caption': 'Let the world be your guide.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _startSlideshow();
  }

  void _startSlideshow() {
    _initializeVideo(slides[_currentIndex]);

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentIndex < slides.length - 1) {
        _currentIndex++;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
        _initializeVideo(slides[_currentIndex]);
      } else {
        _timer.cancel();
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
      }
    });
  }

  Future<void> _initializeVideo(Map<String, dynamic> slide) async {
    _videoController?.dispose();
    if (slide['type'] == 'video') {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(slide['url']))
            ..initialize().then((_) {
              _videoController?.setLooping(true);
              _videoController?.play();
              setState(() {});
            });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: slides.length,
        itemBuilder: (context, index) {
          final slide = slides[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background (Image or Video)
              if (slide['type'] == 'image')
                Image.network(
                  slide['url'],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                )
              else if (slide['type'] == 'video' &&
                  _videoController != null &&
                  _videoController!.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),

              // Dark overlay
              Container(color: Colors.black.withOpacity(0.4)),

              // Centered Caption
              Center(
                child: AnimatedOpacity(
                  opacity: _currentIndex == index ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      slide['caption'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontFamilyFallback: ['Times New Roman', 'sans-serif'],
                        height: 1.4,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
