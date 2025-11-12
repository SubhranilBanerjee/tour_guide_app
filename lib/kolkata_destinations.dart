import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_details_page.dart';
import 'activity_details_page.dart';

class KolkataDestinations extends StatelessWidget {
  const KolkataDestinations({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> topDestinations = [
      {
        "title": "Victoria Memorial",
        "image":
            "https://assets-news.housing.com/news/wp-content/uploads/2021/08/04205223/Victoria-Memorial-Kolkata-An-iconic-marble-structure-of-the-British-era-FB-1200x700-compressed.jpg",
      },
      {
        "title": "Howrah Bridge",
        "image":
            "https://wallup.net/wp-content/uploads/2018/03/19/587894-Kolkata-Howrah_Bridge-748x347.jpg",
      },
      {
        "title": "Dakshineswar Kali Temple",
        "image":
            "https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/Dakshineswar_Kali_Temple%2C_Kolkata.jpg/330px-Dakshineswar_Kali_Temple%2C_Kolkata.jpg",
      },
      {
        "title": "Park Street",
        "image":
            "https://www.holidify.com/images/cmsuploads/compressed/648352-park-street-calcutta-pti_20180529143719.jpg",
      },
      {
        "title": "Indian Museum",
        "image":
            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTIYvFJp4N2MxtxvKV8vYwuesdOd7ywn4cpPw&s",
      },
    ];

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: topDestinations.length,
        itemBuilder: (context, index) {
          final dest = topDestinations[index];
          final title = dest["title"] ?? "";
          final image = dest["image"] ?? "";

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DestinationDetailsPage(
                  title: title,
                  image: image,
                ),
              ),
            ),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🟣 Circular Image
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent, width: 2),
                      image: DecorationImage(
                        image: NetworkImage(image),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DestinationDetailsPage extends StatefulWidget {
  final String title;
  final String image;

  const DestinationDetailsPage({
    super.key,
    required this.title,
    required this.image,
  });

  @override
  State<DestinationDetailsPage> createState() => _DestinationDetailsPageState();
}

class _DestinationDetailsPageState extends State<DestinationDetailsPage> {
  String? wikiSummary;
  String? wikiImage;
  List<dynamic> tours = [];
  List<dynamic> activities = [];

  @override
  void initState() {
    super.initState();
    fetchWikipediaData();
    fetchTours();
    fetchActivities();
  }

  Future<void> fetchWikipediaData() async {
    final title = widget.title.replaceAll(" ", "_");
    final url =
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$title');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          wikiSummary = data["extract"];
          wikiImage = data["thumbnail"]?["source"];
        });
      } else {
        setState(() => wikiSummary = "No Wikipedia data found.");
      }
    } catch (e) {
      setState(() => wikiSummary = "Failed to load Wikipedia data.");
    }
  }

  Future<void> fetchTours() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('posts')
        .select()
        .ilike('title', '%${widget.title}%')
        .limit(3);
    setState(() {
      tours = response;
    });
  }

  Future<void> fetchActivities() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('activities')
          .select()
          .eq('location', widget.title)
          .order('created_at', ascending: false)
          .limit(5);
      setState(() {
        activities = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("❌ Error fetching activities: $e");
      setState(() {
        activities = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerImage =
        "https://picsum.photos/seed/${widget.title.replaceAll(' ', '')}/800/400";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              wikiImage ?? headerImage,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 240,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_not_supported),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                wikiSummary ?? "Loading description...",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            _buildSectionTitle("Available Tours"),
            _buildToursSection(),
            _buildSectionTitle("Popular Activities"),
            _buildActivitiesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildToursSection() {
    if (tours.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "No tours available at the moment.",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tours.length,
        itemBuilder: (context, index) {
          final tour = tours[index];
          final title = tour["title"] ?? "Untitled Tour";
          final imageUrl = tour["image_url"] ??
              "https://via.placeholder.com/200x120.png?text=No+Image";

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailsPage(post: tour),
                ),
              );
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔵 Circular Image
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivitiesSection() {
    if (activities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("No activities available."),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          final title = activity["title"] ?? "Unnamed Activity";
          final imageUrl = activity["image_url"] ??
              "https://via.placeholder.com/200x120.png?text=No+Image";

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityDetailsPage(activity: activity),
                ),
              );
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🔴 Circular Image
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.pinkAccent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
