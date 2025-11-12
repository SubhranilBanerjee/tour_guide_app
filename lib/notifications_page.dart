import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'post_details_page.dart';
import 'activity_details_page.dart';

// 🎨 Match app color theme
class AppColors {
  static const Color primary = Color(0xFFBB86FC); // Soft neon purple
  static const Color accent = Color(0xFFFFC107); // Gold accent
  static const Color background = Color(0xFF121212); // True dark
  static const Color card = Color(0xFF1E1E1E); // Dark surface
  static const Color textDark = Colors.white; // White text
  static const Color textLight = Color(0xFFB0B0B0); // Greyed text
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch data from all three tables
      final posts = await supabase
          .from('posts')
          .select('id, title, created_at, image_url, description')
          .order('created_at', ascending: false);

      final activities = await supabase
          .from('activities')
          .select('id, title, created_at, image_url, description')
          .order('created_at', ascending: false);

      final bookings = await supabase
          .from('bookings')
          .select('id, status, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> all = [];

      // Format all into unified notification list
      for (final p in posts) {
        all.add({
          'type': 'post',
          'id': p['id'],
          'title': '📰 New Post: ${p['title']}',
          'subtitle': 'Someone shared a new experience!',
          'created_at': DateTime.parse(p['created_at']),
          'post_data': p, // ✅ added
        });
      }

      for (final a in activities) {
        all.add({
          'type': 'activity',
          'id': a['id'],
          'title': '🎯 New Activity: ${a['title']}',
          'subtitle': 'Discover something new to do!',
          'created_at': DateTime.parse(a['created_at']),
          'activity_data': a,
        });
      }

      for (final b in bookings) {
        final status = b['status'];
        all.add({
          'type': 'booking',
          'id': b['id'],
          'title': status == 'pending'
              ? '🕒 Booking Pending'
              : '✅ Booking Confirmed',
          'subtitle': status == 'pending'
              ? 'Your booking is awaiting confirmation.'
              : 'Your booking has been confirmed!',
          'created_at': DateTime.parse(b['created_at']),
        });
      }

      // Sort by time (newest first)
      all.sort(
          (a, b) => (b['created_at']).compareTo(a['created_at'] as DateTime));

      setState(() {
        notifications = all;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      setState(() => isLoading = false);
    }
  }

  void _handleTap(Map<String, dynamic> item) {
    if (item['type'] == 'post') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsPage(post: item['post_data']),
        ),
      );
    } else if (item['type'] == 'activity') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailsPage(activity: item['activity_data']),
        ),
      );
    }
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.card,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : notifications.isEmpty
              ? const Center(
                  child: Text(
                    "No notifications yet 📭",
                    style: TextStyle(color: AppColors.textLight, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: notifications.length,
                    itemBuilder: (context, i) {
                      final n = notifications[i];
                      final isBooking = n['type'] == 'booking';

                      return Card(
                        color: AppColors.card,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        shadowColor: AppColors.primary.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Icon(
                              n['type'] == 'post'
                                  ? Icons.article_rounded
                                  : n['type'] == 'activity'
                                      ? Icons.directions_run_rounded
                                      : Icons.book_online_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            n['title'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                n['subtitle'],
                                style: const TextStyle(
                                    color: AppColors.textLight, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _timeAgo(n['created_at']),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          onTap: isBooking ? null : () => _handleTap(n),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
