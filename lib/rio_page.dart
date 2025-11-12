import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class RioPage extends StatefulWidget {
  const RioPage({super.key});

  @override
  State<RioPage> createState() => _RioPageState();
}

class _RioPageState extends State<RioPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? cityInfo;
  List<String> galleryImages = [];
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRioData();
  }

  Future<void> fetchRioData() async {
    try {
      // 🧠 Fetch Wikipedia summary for Rio de Janeiro
      final wikiResponse = await http.get(
        Uri.parse(
            'https://en.wikipedia.org/api/rest_v1/page/summary/Rio_de_Janeiro'),
      );

      if (wikiResponse.statusCode == 200) {
        cityInfo = json.decode(wikiResponse.body);
      }

      // 🖼️ Fetch gallery images from Lorem Picsum
      final picsumResponse = await http.get(
        Uri.parse('https://picsum.photos/v2/list?page=2&limit=6'),
      );

      if (picsumResponse.statusCode == 200) {
        final List data = json.decode(picsumResponse.body);
        galleryImages =
            data.map((img) => img['download_url'] as String).toList();
      }

      // 🪶 Fetch related posts from Supabase where location == 'Rio de Janeiro'
      final postsResponse = await supabase
          .from('posts')
          .select()
          .eq('location', 'Rio de Janeiro')
          .order('created_at', ascending: false);

      posts = List<Map<String, dynamic>>.from(postsResponse);

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading Rio data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌴 Rio de Janeiro'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🏙️ City Info Section
            if (cityInfo != null) ...[
              Text(
                cityInfo!['title'] ?? 'Rio de Janeiro',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (cityInfo!['thumbnail'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(cityInfo!['thumbnail']['source']),
                ),
              const SizedBox(height: 10),
              Text(
                cityInfo!['extract'] ?? 'No information available.',
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ],

            const SizedBox(height: 24),

            // 🖼️ Gallery Section
            const Text(
              '📸 Gallery',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: galleryImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        galleryImages[index],
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 📰 Posts Section
            const Text(
              '🗞️ Related Posts',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (posts.isEmpty)
              const Text('No posts available for Rio de Janeiro.')
            else
              Column(
                children: posts.map((post) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post['image_url'] != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: Image.network(
                              post['image_url'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['title'] ?? 'Untitled Post',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post['description'] ??
                                    'No description available.',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  "📍 Location: ${post['location'] ?? 'Unknown'}"),
                              Text("🕒 Posted on: ${post['created_at'] ?? ''}"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
