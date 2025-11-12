import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';

class GuidesList extends StatefulWidget {
  const GuidesList({super.key});

  @override
  State<GuidesList> createState() => _GuidesListState();
}

class _GuidesListState extends State<GuidesList> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> guides = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadGuides();
  }

  Future<void> loadGuides() async {
    try {
      // ✅ Fetch only users with role = 'guide'
      final response = await supabase
          .from('profiles')
          .select('id, full_name, profile_image_url')
          .eq('role', 'guide')
          .order('full_name', ascending: false);

      setState(() {
        guides = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading guides: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load guides')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (guides.isEmpty) {
      return const Center(child: Text('No guides available'));
    }

    return SizedBox(
      height: 160,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: guides.map((guide) {
            final imageUrl = guide['profile_image_url'] ?? '';
            final fullName = guide['full_name'] ?? 'Unknown';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: guide['id']),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
