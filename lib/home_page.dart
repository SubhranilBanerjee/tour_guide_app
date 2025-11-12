// home_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:confetti/confetti.dart';
import 'activity_details_page.dart';
import 'post_details_page.dart';

import 'search_page.dart';
import 'posts_page.dart';
import 'notifications_page.dart';
import 'guides_list_page.dart';
import 'influencers_list_page.dart';
import 'kolkata_destinations.dart';
import 'posts_feed.dart';
import 'activity_feed.dart';
import 'global_search_live_page.dart';
import 'paris_page.dart';
import 'dubai_page.dart';
import 'newyork_page.dart';
import 'rio_page.dart';
import 'bali_page.dart';
import 'ads_feed.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String? fullName;
  String? locationName;
  String? profileImageUrl;

  late ConfettiController _confettiController;
  int _currentIndex = 0;
  late final List<String> _slideshowImages;
  late final List<String> _captions;
  late final Timer _timer;

  // NEW: boosted items
  bool boostedLoading = true;
  String? boostedError;
  List<Map<String, dynamic>> boostedItems =
      []; // each item contains a 'type' key: 'post' or 'activity'

  @override
  void initState() {
    super.initState();
    _initData();

    _slideshowImages = [
      'assets/sea.jpg',
      'assets/mountain1.jpg',
      'assets/mountain.jpg',
      'assets/Victoria-Memorial.jpg',
      'assets/Pareshnath-Jain-Temple.jpg',
    ];

    _captions = [
      "Find Peace by the Sea 🌊",
      "Conquer the Peaks 🏔️",
      "Breathe in the Mountains 🌄",
      "Explore Victoria Memorial 🏛️",
      "Discover Pareshnath Temple 🕉️",
    ];

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() =>
            _currentIndex = (_currentIndex + 1) % _slideshowImages.length);
      }
    });

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchUserName();
    await _fetchLocation();
    await _fetchBoostedItems();
  }

  Future<void> _fetchUserName() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => fullName = "Guest");
      return;
    }
    final data = await supabase
        .from('profiles')
        .select('full_name, profile_image_url')
        .eq('id', user.id)
        .maybeSingle();

    setState(() {
      fullName = data?['full_name'] ?? "Guest";
      profileImageUrl = data?['profile_image_url'];
    });
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => locationName = "Location disabled");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => locationName = "Permission denied");
      return;
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    final placemark = placemarks.first;
    setState(() {
      locationName =
          "${placemark.locality ?? 'Unknown'}, ${placemark.country ?? ''}";
    });
  }

  void _showConfetti() => _confettiController.play();

  // ---------------------------
  // NEW: Fetch boosted posts & activities
  // ---------------------------
  Future<void> _fetchBoostedItems() async {
    setState(() {
      boostedLoading = true;
      boostedError = null;
    });

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Fetch boosted posts where boost_end > now and is_boosted = true
      final boostedPostsResp = await supabase
          .from('posts')
          .select()
          .eq('is_boosted', true)
          .gt('boost_end', nowIso)
          .order('boost_end', ascending: false);

      // Fetch boosted activities where boost_end > now and is_boosted = true
      final boostedActsResp = await supabase
          .from('activities')
          .select()
          .eq('is_boosted', true)
          .gt('boost_end', nowIso)
          .order('boost_end', ascending: false);

      final List<Map<String, dynamic>> postsList = (boostedPostsResp is List)
          ? List<Map<String, dynamic>>.from(boostedPostsResp)
          : [];
      final List<Map<String, dynamic>> actsList = (boostedActsResp is List)
          ? List<Map<String, dynamic>>.from(boostedActsResp)
          : [];

      // tag each record with its type
      final combined = <Map<String, dynamic>>[];
      for (var p in postsList) {
        final copy = Map<String, dynamic>.from(p);
        copy['__type'] = 'post';
        combined.add(copy);
      }
      for (var a in actsList) {
        final copy = Map<String, dynamic>.from(a);
        copy['__type'] = 'activity';
        combined.add(copy);
      }

      // optional: sort by boost_end descending (most recently boosted first) or by boost_end remaining
      combined.sort((a, b) {
        final aEnd = DateTime.tryParse(a['boost_end']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bEnd = DateTime.tryParse(b['boost_end']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bEnd.compareTo(aEnd);
      });

      setState(() {
        boostedItems = combined;
        boostedLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching boosted items: $e');
      setState(() {
        boostedError = 'Failed to load boosted content';
        boostedLoading = false;
      });
    }
  }

  void _openItem(Map<String, dynamic> item) {
    // simple navigation: open posts_page for posts, activity_feed for activities
    if (item['__type'] == 'post') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PostsPage()));
    } else {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ActivitiesFeed()));
    }
  }

  Widget _buildBoostedSection() {
    if (boostedLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 12),
            Text('Loading boosted...')
          ],
        ),
      );
    }

    if (boostedError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Text(
          boostedError!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (boostedItems.isEmpty) {
      // no boosted = no section
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: Color(0xFFFF6B00)),
                const SizedBox(width: 8),
                Text(
                  '🔥 Boosted Experiences',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _fetchBoostedItems,
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Slider
          SizedBox(
            height: 160,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: boostedItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final it = boostedItems[index];
                final title =
                    (it['title'] ?? it['name'] ?? 'Untitled').toString();
                final imageUrl = (it['image_url'] ?? '').toString();
                final boostEnd = (it['boost_end'] ?? '').toString();

                final remaining = (() {
                  try {
                    final end = DateTime.parse(boostEnd).toLocal();
                    final diff = end.difference(DateTime.now());
                    if (diff.isNegative) return 'Expired';
                    if (diff.inDays >= 1) return '${diff.inDays}d left';
                    if (diff.inHours >= 1) return '${diff.inHours}h left';
                    return '${diff.inMinutes}m left';
                  } catch (_) {
                    return '';
                  }
                })();

                return GestureDetector(
                  onTap: () {
                    if (it['__type'] == 'post') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailsPage(post: it),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActivityDetailsPage(activity: it),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: 260,
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      image: imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imageUrl), fit: BoxFit.cover)
                          : null,
                      color: Colors.grey.shade300,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Dark overlay
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.45),
                                Colors.black.withOpacity(0.18),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'BOOSTED',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    remaining,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      it['__type'] == 'post'
                                          ? 'Tour'
                                          : 'Activity',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xfff9f9fc),
      body: Stack(
        children: [
          // Soft pastel background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xfffefefe), Color(0xfff7f9ff)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            colors: [
              Colors.pinkAccent.shade100,
              Colors.lightBlueAccent.shade100
            ],
            gravity: 0.2,
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                // NEW: Boosted section inserted here
                _buildBoostedSection(),

                _buildSectionHeader("Places in Kolkata"),
                const SizedBox(height: 10),
                const KolkataDestinations(),
                const SizedBox(height: 35),
                _buildSectionHeader("Activities", showButton: true),
                const SizedBox(height: 10),
                const SizedBox(height: 180, child: ActivitiesFeed()),
                _buildSectionHeader("Meet Our Guides"),
                const SizedBox(height: 10),
                const SizedBox(height: 180, child: GuidesList()),
                const SizedBox(height: 30),
                _buildSectionHeader("Featured Tours", showButton: true),
                const SizedBox(height: 10),
                const SizedBox(height: 150, child: PostsFeed()),
                const SizedBox(height: 30),
                _buildSectionHeader("Top Influencers"),
                const SizedBox(height: 10),
                const SizedBox(height: 180, child: InfluencersList()),
                const SizedBox(height: 30),
                const SizedBox(height: 30),
                const SizedBox(height: 30),
                const SizedBox(height: 30),
                _buildSectionHeader("Sponsored"),
                const SizedBox(height: 10),
                const AdsFeed(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Existing helper widgets kept unchanged ---
  // --- Header and other pieces follow exactly as before ---

  Widget _buildHeader() {
    return Stack(
      children: [
        // Background slideshow image
        AnimatedSwitcher(
          duration: const Duration(seconds: 1),
          child: Container(
            key: ValueKey<int>(_currentIndex),
            height: 460, // 🔥 increased height to fit category icons
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_slideshowImages[_currentIndex]),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
        ),

        // Foreground content (profile, caption, search bar, icons)
        Positioned(
          top: 70,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting and notification row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl!)
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Good Morning, ${fullName ?? "Guest"} 👋",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (locationName != null)
                            Text(
                              locationName!,
                              style: GoogleFonts.roboto(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: Colors.black87, size: 58),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsPage()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Caption with gradient
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                child: ShaderMask(
                  key: ValueKey(_captions[_currentIndex]),
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xffa2c2e2), Color(0xfff8cdda)],
                  ).createShader(bounds),
                  child: Text(
                    _captions[_currentIndex],
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // White glass search bar
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const GlobalSearchLivePage()),
                            ),
                            decoration: InputDecoration(
                              hintText: "Where to go?",
                              border: InputBorder.none,
                              hintStyle: GoogleFonts.roboto(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // 🔥 Category icons now appear INSIDE the header image
              _buildHeaderCategories(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCategories() {
    final categories = [
      {"icon": Icons.flight_takeoff_rounded, "title": "Tours"},
      {"icon": Icons.hotel_rounded, "title": "Activities"},
      {"icon": Icons.beach_access_rounded, "title": "Bookings"},
      {"icon": Icons.local_offer_rounded, "title": "Influencers"},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: categories.map((c) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(c["icon"] as IconData,
                          color: const Color(0xff2356ff), size: 26),
                      const SizedBox(height: 8),
                      Text(
                        c["title"] as String,
                        style: GoogleFonts.poppins(
                          color: const Color(0xff006eff),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, {bool showButton = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (showButton)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              ),
              label: const Text("See All"),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              style:
                  TextButton.styleFrom(foregroundColor: Colors.lightBlueAccent),
            ),
        ],
      ),
    );
  }

  Widget _adCard(String imagePath) {
    return GestureDetector(
      onTap: () {
        // Example: Navigate to a promotion page or open URL
        // Navigator.push(context, MaterialPageRoute(builder: (_) => const PromoPage()));
      },
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildTopDestinations() {
    final destinations = [
      {"image": "assets/paris.jpg", "title": "Paris"},
      {"image": "assets/dubai.jpg", "title": "Dubai"},
      {"image": "assets/newyork.jpg", "title": "New York"},
      {"image": "assets/rio.jpg", "title": "Rio de Janeiro"},
      {"image": "assets/bali.jpg", "title": "Bali"},
    ];

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: destinations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 15),
        itemBuilder: (context, i) {
          final d = destinations[i];
          return GestureDetector(
            onTap: () {
              switch (d["title"]) {
                case "Paris":
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ParisPage()));
                  break;
                case "Dubai":
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DubaiPage()));
                  break;
                case "New York":
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NewYorkPage()));
                  break;
                case "Rio de Janeiro":
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RioPage()));
                  break;
                case "Bali":
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BaliPage()));
                  break;
              }
            },
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: AssetImage(d["image"]!),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d["title"]!,
                  style: const TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
