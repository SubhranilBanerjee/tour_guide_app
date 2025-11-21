import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_graph_page.dart';

class UserAnalyticsPage extends StatefulWidget {
  const UserAnalyticsPage({super.key});

  @override
  State<UserAnalyticsPage> createState() => _UserAnalyticsPageState();
}

class _UserAnalyticsPageState extends State<UserAnalyticsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> userPosts = [];
  List<Map<String, dynamic>> userActivities = [];

  String? userId;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    userId = user.id;

    final posts = await supabase
        .from('posts')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final activities = await supabase
        .from('activities')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    setState(() {
      userPosts = posts.map((e) => Map<String, dynamic>.from(e)).toList();
      userActivities =
          activities.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  Widget buildSection(
      String title, List<Map<String, dynamic>> items, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text("No items found"),
          ),
        ...items.map((item) {
          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: item['image_url'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item['image_url'],
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.image, size: 45),
              title: Text(item['title'] ?? 'Untitled'),
              subtitle: Text(type == 'post' ? 'Post' : 'Activity'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnalyticsGraphPage(
                      id: item['id'],
                      type: type,
                    ),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Analytics"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            buildSection("Your Posts", userPosts, "post"),
            buildSection("Your Activities", userActivities, "activity"),
          ],
        ),
      ),
    );
  }
}
