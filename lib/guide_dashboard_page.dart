import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_details_page.dart';
import 'activity_details_page.dart';

class GuideDashboardPage extends StatefulWidget {
  final String userId;
  const GuideDashboardPage({super.key, required this.userId});

  @override
  State<GuideDashboardPage> createState() => _GuideDashboardPageState();
}

class _GuideDashboardPageState extends State<GuideDashboardPage> {
  final supabase = Supabase.instance.client;
  List posts = [], activities = [], ads = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final p =
          await supabase.from('posts').select('*').eq('user_id', widget.userId);
      final a = await supabase
          .from('activities')
          .select('*')
          .eq('user_id', widget.userId);
      final ad =
          await supabase.from('ads').select('*').eq('user_id', widget.userId);

      setState(() {
        posts = p;
        activities = a;
        ads = ad;
        loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading guide data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading guide data')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Guide Dashboard"),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(context, "Posts", posts,
                clickable: true, isPost: true),
            _buildSection(context, "Activities", activities,
                clickable: true, isPost: false),
            _buildSection(context, "Ads", ads, clickable: false),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List data,
      {required bool clickable, bool isPost = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (data.isEmpty)
          const Text(
            "No data available",
            style: TextStyle(color: Colors.black54),
          )
        else
          Column(
            children: data.map((item) {
              final imageUrl = item['image_url'] ?? '';
              final titleText = item['title'] ?? 'Untitled';
              final desc = (item['description'] ?? '').toString();

              final cardContent = Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

              // Make posts & activities clickable
              if (clickable) {
                return InkWell(
                  onTap: () {
                    if (isPost) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailsPage(post: item),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActivityDetailsPage(activity: item),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: cardContent,
                );
              } else {
                return cardContent;
              }
            }).toList(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
