import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagePostsPage extends StatefulWidget {
  const ManagePostsPage({super.key});

  @override
  State<ManagePostsPage> createState() => _ManagePostsPageState();
}

class _ManagePostsPageState extends State<ManagePostsPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  Future<List<Map<String, dynamic>>> _loadPosts() async {
    // Get posts
    final posts = await supabase
        .from('posts')
        .select('id, title, description, image_url, user_id');

    // Get users to map post creators
    final users = await supabase.from('profiles').select('id, full_name');
    final userMap = {for (var u in users) u['id']: u['full_name'] ?? 'Unknown'};

    final totalUsers = users.length;

    return posts.map<Map<String, dynamic>>((post) {
      return {
        'id': post['id'],
        'title': post['title'] ?? 'Untitled',
        'description': post['description'] ?? '',
        'image_url': post['image_url'],
        'user_name': userMap[post['user_id']] ?? 'Unknown',
        'reach': totalUsers,
      };
    }).toList();
  }

  Future<void> _deletePost(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🗑 Delete Post"),
        content: const Text(
            "Are you sure you want to delete this post permanently?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            label: const Text("Delete"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('posts').delete().eq('id', id);
        setState(() => _postsFuture = _loadPosts());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Post deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting post: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return const Center(
              child: Text(
                "No posts found.",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.separated(
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Card(
                    elevation: 5,
                    shadowColor: Colors.blueAccent.withOpacity(0.15),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: post['image_url'] != null
                            ? Image.network(
                                post['image_url'],
                                width: 65,
                                height: 65,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported,
                                        color: Colors.grey, size: 40),
                              )
                            : const Icon(Icons.image_outlined,
                                color: Colors.grey, size: 40),
                      ),
                      title: Text(
                        post['title'],
                        style: const TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "By: ${post['user_name']}",
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Reach (estimated): ${post['reach']} users",
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.redAccent),
                        tooltip: "Delete Post",
                        onPressed: () => _deletePost(post['id']),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
