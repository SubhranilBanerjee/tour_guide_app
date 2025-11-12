import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ParisPage extends StatefulWidget {
  const ParisPage({super.key});

  @override
  State<ParisPage> createState() => _ParisPageState();
}

class _ParisPageState extends State<ParisPage> {
  final supabase = Supabase.instance.client;
  String wikiSummary = '';
  List<String> galleryImages = [];
  List<Map<String, dynamic>> parisPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadParisData();
  }

  /// 🔄 Load everything together
  Future<void> loadParisData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchWikipediaSummary(),
      fetchLoremPicsumImages(),
      fetchParisPosts(),
    ]);
    setState(() => isLoading = false);
  }

  /// 🏛️ Wikipedia Summary
  Future<void> fetchWikipediaSummary() async {
    try {
      final url =
          Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/Paris');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        wikiSummary = data['extract'] ?? 'No summary available.';
      } else {
        wikiSummary = 'Failed to load Wikipedia summary.';
      }
    } catch (e) {
      wikiSummary = 'Error fetching Wikipedia data: $e';
    }
  }

  /// 🖼️ Lorem Picsum Gallery
  Future<void> fetchLoremPicsumImages() async {
    try {
      galleryImages = List.generate(
        10,
        (index) => 'https://picsum.photos/seed/paris$index/400/300',
      );
    } catch (e) {
      print("Error loading images: $e");
    }
  }

  /// 📦 Fetch Paris posts from Supabase
  Future<void> fetchParisPosts() async {
    try {
      final data = await supabase
          .from('posts')
          .select()
          .eq('location', 'Paris')
          .order('created_at', ascending: false);

      parisPosts = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("❌ Error fetching posts: $e");
    }
  }

  /// 🧱 Build a Post Card
  Widget buildPostCard(Map<String, dynamic> post) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['image_url'] != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                post['image_url'],
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title'] ?? 'Untitled',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  post['description'] ?? 'No description provided.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                if (post['price'] != null)
                  Text(
                    "💰 Price: ₹${post['price']}",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green),
                  ),
                if (post['location'] != null)
                  Text(
                    "📍 Location: ${post['location']}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🏙️ Main Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🇫🇷 Discover Paris"),
        backgroundColor: Colors.indigoAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadParisData,
              child: ListView(
                children: [
                  // 🏛️ Wikipedia Summary
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      wikiSummary,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ),

                  const Divider(),

                  // 🖼️ Image Gallery
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text(
                      "📸 Paris Gallery",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: galleryImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              galleryImages[index],
                              width: 300,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 30),

                  // 📋 Posts Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text(
                      "🧭 Paris Tours & Experiences",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (parisPosts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text("No Paris posts available.")),
                    )
                  else
                    Column(
                      children: parisPosts
                          .map((post) => buildPostCard(post))
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
