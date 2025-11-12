import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class BaliPage extends StatefulWidget {
  const BaliPage({super.key});

  @override
  State<BaliPage> createState() => _BaliPageState();
}

class _BaliPageState extends State<BaliPage> {
  final supabase = Supabase.instance.client;

  String wikiTitle = 'Bali';
  String wikiSummary = '';
  String? wikiImageUrl;
  List<String> galleryImages = [];
  List<Map<String, dynamic>> baliPosts = [];
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    loadBaliData();
  }

  Future<void> loadBaliData() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    try {
      await Future.wait([
        fetchWikipediaSummary(),
        fetchLoremPicsumImages(),
        fetchBaliPosts(),
      ]);
    } catch (e) {
      errorMsg = 'Error loading data: $e';
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Fetch Wikipedia summary & image for Bali
  Future<void> fetchWikipediaSummary() async {
    try {
      final url =
          Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/Bali');
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        wikiTitle = data['title'] ?? 'Bali';
        wikiSummary = data['extract'] ?? '';
        // originalimage may or may not be present
        if (data['originalimage'] != null &&
            data['originalimage']['source'] != null) {
          wikiImageUrl = data['originalimage']['source'];
        } else if (data['thumbnail'] != null &&
            data['thumbnail']['source'] != null) {
          wikiImageUrl = data['thumbnail']['source'];
        } else {
          wikiImageUrl = null;
        }
      } else {
        wikiSummary =
            'Failed to load Wikipedia summary (status ${res.statusCode}).';
      }
    } catch (e) {
      wikiSummary = 'Error fetching Wikipedia data: $e';
    }
  }

  /// Build gallery using Lorem Picsum seeds (no API key required)
  Future<void> fetchLoremPicsumImages() async {
    // Just generate seeded picsum images - deterministic
    galleryImages = List.generate(
      12,
      (i) => 'https://picsum.photos/seed/bali${i + 1}/600/400',
    );
  }

  /// Fetch posts from Supabase where location = 'Bali'
  Future<void> fetchBaliPosts() async {
    try {
      final response = await supabase
          .from('posts')
          .select(
              'id, title, description, image_url, price, location, created_at')
          .eq('location', 'Bali')
          .order('created_at', ascending: false);

      if (response is List) {
        baliPosts = response.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        baliPosts = [];
      }
    } catch (e) {
      // keep posts empty and log
      baliPosts = [];
      debugPrint('Error fetching Bali posts: $e');
    }
  }

  Widget buildGallery() {
    if (galleryImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: galleryImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final url = galleryImages[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 300,
              height: 180,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 300,
                  height: 180,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, st) {
                return Container(
                  width: 300,
                  height: 180,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 48),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget buildPostCard(Map<String, dynamic> post) {
    final imageUrl = post['image_url'] as String?;
    final title = post['title'] ?? 'Untitled';
    final desc = post['description'] ?? '';
    final price = post['price'];
    final location = post['location'] ?? 'Bali';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, prog) {
                  if (prog == null) return child;
                  return Container(
                    height: 260,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (ctx, err, st) {
                  return Container(
                    height: 260,
                    color: Colors.grey[200],
                    child:
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  );
                },
              ),
            )
          else
            Container(
              height: 180,
              color: Colors.grey[200],
              child: const Center(
                  child: Icon(Icons.image_not_supported, size: 48)),
            ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(desc,
                    style:
                        const TextStyle(fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (price != null)
                      Text('💰 ₹$price',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green)),
                    Text('📍 $location',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🇮🇩 Explore Bali'),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
              ? Center(
                  child: Text(errorMsg!,
                      style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: loadBaliData,
                  child: ListView(
                    children: [
                      // Wikipedia hero
                      if (wikiImageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(0),
                          child: Image.network(
                            wikiImageUrl!,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(wikiTitle,
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              wikiSummary,
                              style: const TextStyle(fontSize: 16, height: 1.4),
                            ),
                          ],
                        ),
                      ),

                      const Divider(),

                      // Gallery
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: const Text('📸 Bali Gallery',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      buildGallery(),
                      const SizedBox(height: 12),
                      const Divider(),

                      // Posts
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: const Text('🧭 Posts about Bali',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      if (baliPosts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child:
                              Center(child: Text('No posts found for Bali.')),
                        )
                      else
                        ...baliPosts.map((p) => buildPostCard(p)).toList(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
