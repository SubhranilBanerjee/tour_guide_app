// home_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'activity_details_page.dart';
import 'post_details_page.dart';
import 'search_page.dart';
import 'posts_page.dart';
import 'notifications_page.dart';
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String? fullName;
  String? locationName;
  String? profileImageUrl;

  int _currentIndex = 0;
  late final List<String> _slideshowImages;
  late final List<String> _captions;
  late final Timer _timer;

  bool boostedLoading = true;
  String? boostedError;
  List<Map<String, dynamic>> boostedItems = [];

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
      "Find Peace by the Sea",
      "Conquer the Peaks",
      "Breathe in the Mountains",
      "Explore Victoria Memorial",
      "Discover Pareshnath Temple",
    ];

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() =>
            _currentIndex = (_currentIndex + 1) % _slideshowImages.length);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchUserName();
    await _fetchLocation();
    await _fetchBoostedItems();
  }

  Future<void> _fetchUserName() async {
    try {
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
    } catch (_) {
      setState(() => fullName = "Guest");
    }
  }

  Future<void> _fetchLocation() async {
    try {
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
    } catch (_) {
      setState(() => locationName = null);
    }
  }

  Future<void> _fetchBoostedItems() async {
    setState(() {
      boostedLoading = true;
      boostedError = null;
    });

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final boostedPostsResp = await supabase
          .from('posts')
          .select()
          .eq('is_boosted', true)
          .gt('boost_end', nowIso)
          .order('boost_end', ascending: false);

      final boostedActsResp = await supabase
          .from('activities')
          .select()
          .eq('is_boosted', true)
          .gt('boost_end', nowIso)
          .order('boost_end', ascending: false);

      final postsList = boostedPostsResp is List
          ? List<Map<String, dynamic>>.from(boostedPostsResp)
          : <Map<String, dynamic>>[];
      final actsList = boostedActsResp is List
          ? List<Map<String, dynamic>>.from(boostedActsResp)
          : <Map<String, dynamic>>[];

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
    if (item['__type'] == 'post') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PostDetailsPage(post: item)));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ActivityDetailsPage(activity: item)));
    }
  }

  // Helper: format remaining time text
  String _formatRemaining(String boostEnd) {
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
  }

  // Category actions map - keeps your original navigation intent
  void _onCategoryTap(String key) {
    switch (key) {
      case 'Tours':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const PostsPage()));
        break;
      case 'Activities':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ActivitiesFeed()));
        break;
      case 'Bookings':
        // If you have a bookings page, navigate to it. For now open search.
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchPage()));
        break;
      case 'Guides':
        // If you keep GuidesList, import/navigation apply
        // Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesList()));
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchPage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Rounded header card (matches uploaded design)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Hero image with rounded top corners
                        SizedBox(
                          height: 280,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 700),
                                child: Image.asset(
                                  _slideshowImages[_currentIndex],
                                  key: ValueKey<int>(_currentIndex),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // dark gradient to improve text contrast
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.28),
                                      Colors.transparent,
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              // Top row: small circular avatar (left) and notif icon (right)
                              Positioned(
                                left: 18,
                                top: 14,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: profileImageUrl != null
                                          ? NetworkImage(profileImageUrl!)
                                          : const AssetImage(
                                                  'assets/default_avatar.png')
                                              as ImageProvider,
                                      backgroundColor: Colors.grey[200],
                                    ),
                                    const SizedBox(width: 12),
                                    // small location line (optional)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Good Morning, ${fullName ?? 'Guest'} 👋",
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (locationName != null)
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  color: Colors.white70,
                                                  size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                locationName!,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 14,
                                top: 8,
                                child: Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 6,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const NotificationsPage())),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.notifications,
                                          color: Color(0xffff0037)),
                                    ),
                                  ),
                                ),
                              ),

                              // Centered large title
                              Positioned.fill(
                                top: 40,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28.0),
                                    child: Text(
                                      _captions[_currentIndex],
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.cinzel(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        height: 1.02,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Floating white search bar overlapping image bottom
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Material(
                              borderRadius: BorderRadius.circular(28),
                              elevation: 8,
                              shadowColor: Colors.black,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const GlobalSearchLivePage())),
                                borderRadius: BorderRadius.circular(28),
                                child: Container(
                                  height: 54,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Color(0xffffffff),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search,
                                          color: Color(0xff8b96a8)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Where to go, what to do?',
                                          style: GoogleFonts.inter(
                                              color: const Color(0xff9aa6b8),
                                              fontSize: 15),
                                        ),
                                      ),
                                      //const Icon(Icons.mic,
                                      // color: Color(0xffc6d0dd)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Category row (circular blue-outlined chips)
                        Transform.translate(
                          offset: const Offset(0, -18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildCategoryChip(
                                    icon: Icons.flight_takeoff_rounded,
                                    label: 'Tours'),
                                _buildCategoryChip(
                                    icon: Icons.directions_run_rounded,
                                    label: 'Activities'),
                                _buildCategoryChip(
                                    icon: Icons.book_online_rounded,
                                    label: 'Bookings'),
                                _buildCategoryChip(
                                    icon: Icons.search_rounded,
                                    label: 'Guides'),
                              ],
                            ),
                          ),
                        ),

                        // small bottom spacing inside card
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),

              // Main page content (below rounded header)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Boosted experiences header + See All
                    if (boostedLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: const [
                          CircularProgressIndicator(),
                          SizedBox(width: 12),
                          Text('Loading boosted...')
                        ]),
                      )
                    else if (boostedError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(boostedError!,
                            style: const TextStyle(color: Colors.redAccent)),
                      )
                    else if (boostedItems.isNotEmpty) ...[
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Text('Top Picks',
                              style: GoogleFonts.waterfall(
                                  fontSize: 58, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          TextButton(
                              onPressed: _fetchBoostedItems,
                              child: Text('See All',
                                  style: GoogleFonts.inter(
                                      color: const Color(0xff4b8bff)))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: boostedItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final it = boostedItems[index];
                            final title =
                                (it['title'] ?? it['name'] ?? 'Untitled')
                                    .toString();
                            final imageUrl = (it['image_url'] ?? '').toString();
                            final boostEnd = (it['boost_end'] ?? '').toString();
                            return GestureDetector(
                              onTap: () => _openItem(it),
                              child: Container(
                                width: 260,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8))
                                  ],
                                  image: imageUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(imageUrl),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: Stack(
                                  children: [
                                    // dark overlay for text legibility
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withOpacity(0.42),
                                            Colors.transparent
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment: Alignment.topRight,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFF6B00),
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: const Text('BOOSTED',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time,
                                                  size: 12,
                                                  color: Colors.white70),
                                              const SizedBox(width: 6),
                                              Text(_formatRemaining(boostEnd),
                                                  style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: Colors.white70)),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color: Colors.white24,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: Text(
                                                    it['__type'] == 'post'
                                                        ? 'Tour'
                                                        : 'Activity',
                                                    style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: Colors.white70)),
                                              )
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
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox.shrink(),

                    // Places in Kolkata
                    _sectionTitle('Places in Kolkata'),
                    const SizedBox(height: 10),
                    const KolkataDestinations(),
                    const SizedBox(height: 20),

                    // Activities
                    _sectionTitle('Activities', showButton: true),
                    const SizedBox(height: 10),
                    const SizedBox(height: 180, child: ActivitiesFeed()),
                    const SizedBox(height: 18),

                    // Featured Tours
                    _sectionTitle('Featured Tours', showButton: true),
                    const SizedBox(height: 10),
                    const SizedBox(height: 150, child: PostsFeed()),
                    const SizedBox(height: 20),

                    // Sponsored (ads)
                    _sectionTitle('Sponsored'),
                    const SizedBox(height: 10),
                    const AdsFeed(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small helper to build the round outlined category chips from screenshot
  Widget _buildCategoryChip({
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      width: 80, // fixed width so all fit in one line
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xff0062ff),
                width: 2.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: const Color(0xff2b6df6), size: 22),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff466079),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Section title helper matching screenshot style
  Widget _sectionTitle(String title, {bool showButton = false}) {
    return Row(
      children: [
        Text(title,
            style: GoogleFonts.waterfall(
                fontSize: 58, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (showButton)
          TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SearchPage())),
            child: Text('See All',
                style: GoogleFonts.inter(color: const Color(0xff4b8bff))),
          ),
      ],
    );
  }
}
