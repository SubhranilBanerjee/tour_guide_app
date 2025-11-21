import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'boost_post_page.dart';
import 'user_analytics_page.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> userPosts = [];
  List<Map<String, dynamic>> userActivities = [];
  List<Map<String, dynamic>> userAds = []; // 🎯 NEW: List to hold user's ads
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile =
          await supabase.from('profiles').select().eq('id', user.id).single();

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

      // 🎯 NEW: Fetch user's ads
      final ads = await supabase
          .from('ads')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        userData = profile;
        userPosts = List<Map<String, dynamic>>.from(posts);
        userActivities = List<Map<String, dynamic>>.from(activities);
        userAds = List<Map<String, dynamic>>.from(ads); // 🎯 NEW: Update state
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching user data: $e');
      // In a real app, show a SnackBar or error message here.
      setState(() => isLoading = false);
    }
  }

  // NOTE: The _showAdForm method remains unchanged for brevity, but it should be modified
  // to call fetchUserData() after a successful ad post so the list updates automatically.

  Future<void> _showAdForm(BuildContext context) async {
    final linkController = TextEditingController();
    File? imageFile;
    Uint8List? webImageBytes;
    String? fileName;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Post an Ad",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: StatefulBuilder(
            builder: (context, setModalState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (kIsWeb) {
                        // 🖥️ File Picker for Web
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          setModalState(() {
                            webImageBytes = result.files.single.bytes!;
                            fileName = result.files.single.name;
                          });
                        }
                      } else {
                        // 📱 Image Picker for Mobile
                        final picker = ImagePicker();
                        final picked =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setModalState(() => imageFile = File(picked.path));
                          fileName = picked.name;
                        }
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Builder(builder: (context) {
                        if (imageFile != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(imageFile!, fit: BoxFit.cover),
                          );
                        } else if (webImageBytes != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                Image.memory(webImageBytes!, fit: BoxFit.cover),
                          );
                        } else {
                          return const Center(
                            child: Text(
                              "Tap to upload picture",
                              style: TextStyle(color: Colors.black54),
                            ),
                          );
                        }
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: linkController,
                    decoration: InputDecoration(
                      labelText: "Website / Link",
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if ((!kIsWeb && imageFile == null) ||
                    (kIsWeb && webImageBytes == null) ||
                    linkController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Please upload an image and link")),
                  );
                  return;
                }

                try {
                  final user = supabase.auth.currentUser;
                  if (user == null) return;

                  final path =
                      'ads/${DateTime.now().millisecondsSinceEpoch}_$fileName';

                  // Upload to Supabase Storage
                  if (kIsWeb) {
                    await supabase.storage.from('public_files').uploadBinary(
                          path,
                          webImageBytes!,
                          fileOptions:
                              const FileOptions(contentType: 'image/jpeg'),
                        );
                  } else {
                    await supabase.storage
                        .from('public_files')
                        .upload(path, imageFile!);
                  }

                  final imageUrl =
                      supabase.storage.from('public_files').getPublicUrl(path);

                  await supabase.from('ads').insert({
                    'user_id': user.id,
                    'image_url': imageUrl,
                    'link': linkController.text.trim(),
                  });

                  // 🎯 NEW: Refresh data after successful post
                  await fetchUserData();

                  if (context.mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ Ad posted successfully!")),
                  );
                } catch (e) {
                  print("❌ Error posting ad: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to post ad")),
                  );
                }
              },
              child: const Text("Post Ad"),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // 🎯 NEW: Widget to display the list of user's ads
  // ==========================================================
  Widget _buildAdsList() {
    if (userAds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 20, bottom: 40),
          child: Text("You haven't posted any ads yet."),
        ),
      );
    }

    return ListView.builder(
      physics:
          const NeverScrollableScrollPhysics(), // Important for SingleChildScrollView
      shrinkWrap: true,
      itemCount: userAds.length,
      itemBuilder: (context, index) {
        final ad = userAds[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  ad['image_url'],
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: Colors.red.shade100,
                    child: const Center(child: Text("Image Load Failed 😔")),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Link:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad['link'],
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Posted on: ${ad['created_at'].toString().substring(0, 10)}", // Display date only
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // 🎯 NEW: Updated build method to include Ads section
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Dashboard 🚀",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
        backgroundColor: const Color(0xFFB3E5FC),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text("Post Ads", style: TextStyle(color: Colors.white)),
        onPressed: () => _showAdForm(context),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3E5FC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : userData == null
                  ? const Center(child: Text("No profile found"))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 🧍 Profile Header (Unchanged)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundImage: userData!['avatar_url'] !=
                                            null
                                        ? NetworkImage(userData!['avatar_url'])
                                        : const AssetImage(
                                                'assets/default_avatar.png')
                                            as ImageProvider,
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userData!['full_name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF01579B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          userData!['email'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Joined: ${userData!['joined_on']?.toString().substring(0, 10) ?? 'N/A'}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 📊 Stats Section (Updated to include Ads)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatCard(
                                "Posts",
                                "${userPosts.length}",
                                Icons.post_add,
                                Colors.blueAccent,
                              ),
                              _buildStatCard(
                                "Activities",
                                "${userActivities.length}",
                                Icons.event_available,
                                Colors.green,
                              ),
                              // 🎯 NEW: Ad Count Stat Card
                              _buildStatCard(
                                "Ads",
                                "${userAds.length}",
                                Icons.campaign,
                                Colors
                                    .teal, // Use the FAB color for consistency
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),
                          // 🚀 Boost a Post Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.bolt, color: Colors.white),
                              label: const Text(
                                "Boost a Post",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                final user =
                                    Supabase.instance.client.auth.currentUser;

                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Please login first")),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BoostPostPage(userId: user.id),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 15),

// 📊 Analytics Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.analytics,
                                  color: Colors.white),
                              label: const Text(
                                "View Analytics",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const UserAnalyticsPage()),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 📰 Ads Section Header
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Your Posted Ads (${userAds.length})",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF01579B),
                              ),
                            ),
                          ),
                          const Divider(color: Colors.blueGrey),
                          const SizedBox(height: 10),

                          // 🖼️ Ads List
                          _buildAdsList(),

                          // Placeholder sections for Posts and Activities (as they were in the original)
                          // In a real app, you would add _buildPostsList() and _buildActivitiesList() here.
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  void _showBoostPostDialog() {
    if (userPosts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You don't have any posts to boost!")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Boost a Post"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select a post to boost:"),
              const SizedBox(height: 10),
              ...userPosts.map((post) {
                return ListTile(
                  title: Text(post['title'] ?? "Untitled Post"),
                  trailing: const Icon(Icons.bolt, color: Colors.deepOrange),
                  onTap: () async {
                    await _boostPost(post['id']);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _boostPost(String postId) async {
    try {
      await supabase.from('posts').update({
        'is_boosted': true,
        'boost_end':
            DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      }).eq('id', postId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔥 Post boosted for 3 days!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to boost post: $e")),
      );
    }
  }

  // _buildStatCard helper method (Unchanged)
  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 100, // Reduced width to fit 3 cards
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18, // Reduced font size for 3 cards
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
