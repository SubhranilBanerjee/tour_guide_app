import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_post_data.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyPosts();
  }

  Future<void> fetchMyPosts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('posts')
        .select()
        .eq('user_id', user.id) // only posts by this user
        .order('created_at', ascending: false);

    setState(() {
      posts = response as List<dynamic>;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📝 My Posts"),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(child: Text("You haven't posted anything yet."))
              : ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (_, index) {
                    final post = posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(post['title'] ?? 'Untitled'),
                        subtitle: Text(post['created_at'] != null
                            ? DateTime.parse(post['created_at'])
                                .toLocal()
                                .toString()
                            : ''),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyPostDataPage(
                                  postId: post['id'], postTitle: post['title']),
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
