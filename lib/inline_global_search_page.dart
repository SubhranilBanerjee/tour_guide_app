import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InlineGlobalSearch extends StatefulWidget {
  const InlineGlobalSearch({super.key});

  @override
  State<InlineGlobalSearch> createState() => _InlineGlobalSearchState();
}

class _InlineGlobalSearchState extends State<InlineGlobalSearch> {
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

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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

        // 🧩 Live Results (inline)
        if (results.isNotEmpty)
          SizedBox(
            height: 300, // or make it flexible
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                final type = item['_type'] ?? 'Item';
                final title = item['title'] ?? 'Untitled';
                final description = item['description'] ?? '';
                final image = item['image_url'] ??
                    item['photo_url'] ??
                    'https://via.placeholder.com/300x150?text=No+Image';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  elevation: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(image,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type,
                              style: TextStyle(
                                  color: type == 'Post'
                                      ? Colors.pinkAccent
                                      : Colors.green,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
