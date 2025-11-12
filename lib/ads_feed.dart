import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdsFeed extends StatefulWidget {
  const AdsFeed({super.key});

  @override
  State<AdsFeed> createState() => _AdsFeedState();
}

class _AdsFeedState extends State<AdsFeed> {
  final supabase = Supabase.instance.client;
  final PageController _pageController = PageController();
  List<Map<String, dynamic>> ads = [];
  bool isLoading = true;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    fetchAds();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchAds() async {
    try {
      final response = await supabase
          .from('ads')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        ads = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      if (ads.isNotEmpty) {
        _startAutoScroll();
      }
    } catch (e) {
      print("❌ Error fetching ads: $e");
      setState(() => isLoading = false);
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients && ads.isNotEmpty) {
        int nextPage = _pageController.page!.toInt() + 1;
        if (nextPage >= ads.length) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ads.isEmpty) {
      return const Center(
        child: Text(
          "No ads available right now.",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return SizedBox(
      height: 150,
      width: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        itemCount: ads.length,
        itemBuilder: (context, index) {
          final ad = ads[index];
          return GestureDetector(
            onTap: () => _launchURL(ad['link']),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0), // full width, no border
              child: Stack(
                children: [
                  Image.network(
                    ad['image_url'],
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 10,
                    bottom: 10,
                    child: Text(
                      "Sponsored. Tap to view",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
