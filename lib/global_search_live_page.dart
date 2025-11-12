import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'post_details_page.dart';
import 'activity_details_page.dart';

class GlobalSearchLivePage extends StatefulWidget {
  const GlobalSearchLivePage({super.key});

  @override
  State<GlobalSearchLivePage> createState() => _GlobalSearchLivePageState();
}

class _GlobalSearchLivePageState extends State<GlobalSearchLivePage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;
  bool isLoading = false;
  List<Map<String, dynamic>> results = [];

  Future<void> searchAll(String query) async {
    if (query.isEmpty) {
      setState(() => results = []);
      return;
    }

    setState(() => isLoading = true);

    try {
      final lowerQuery = query.toLowerCase();

      // ✅ Search only in posts + activities tables
      final responses = await Future.wait([
        supabase
            .from('posts')
            .select()
            .or('title.ilike.%$lowerQuery%,description.ilike.%$lowerQuery%'),
        supabase
            .from('activities')
            .select()
            .or('title.ilike.%$lowerQuery%,description.ilike.%$lowerQuery%'),
      ]);

      final posts = responses[0];
      final activities = responses[1];

      final combined = [
        ...List<Map<String, dynamic>>.from(posts)
            .map((e) => {...e, '_type': 'Post'}),
        ...List<Map<String, dynamic>>.from(activities)
            .map((e) => {...e, '_type': 'Activity'}),
      ];

      setState(() {
        results = combined;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Search error: $e');
      setState(() => isLoading = false);
    }
  }

  // 🟦 Handle tap on a search item
  void _handleTap(Map<String, dynamic> item) {
    final type = item['_type'];

    if (type == 'Post') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsPage(post: item),
        ),
      );
    } else if (type == 'Activity') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailsPage(activity: item),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text("Global Search"),
        backgroundColor: const Color(0xFF004AAD),
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  searchAll(value);
                });
              },
              decoration: InputDecoration(
                hintText: "Search posts or activities...",
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (isLoading)
            const LinearProgressIndicator(
              color: Color(0xFF004AAD),
              minHeight: 2,
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty && _controller.text.isNotEmpty
                    ? const Center(
                        child: Text(
                          "No results found",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : results.isEmpty && _controller.text.isEmpty
                        ? const Center(
                            child: Text(
                              "Start typing to search posts or activities",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final item = results[index];
                              final type = item['_type'] ?? 'Item';
                              final title = item['title'] ?? 'Untitled';
                              final description = item['description'] ?? '';
                              final image = item['image_url'] ??
                                  item['photo_url'] ??
                                  'https://via.placeholder.com/300x150?text=No+Image';

                              return GestureDetector(
                                onTap: () => _handleTap(item),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 4,
                                  shadowColor:
                                      Colors.blueAccent.withOpacity(0.3),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.network(
                                        image,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.black54),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  type == 'Post'
                                                      ? Icons.article_rounded
                                                      : Icons
                                                          .directions_walk_rounded,
                                                  size: 18,
                                                  color: type == 'Post'
                                                      ? Colors.pinkAccent
                                                      : Colors.green,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  type,
                                                  style: TextStyle(
                                                    color: type == 'Post'
                                                        ? Colors.pinkAccent
                                                        : Colors.green,
                                                    fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }
}
