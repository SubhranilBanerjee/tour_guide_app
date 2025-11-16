import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'admin_dashboard_page.dart';
import 'post_details_page.dart';
import 'activity_details_page.dart';
import 'home_page.dart';
import 'my_posts_page.dart';
import 'my_activities_page.dart';
import 'favorites_page.dart';
import 'bookings_page.dart';
import 'user_dashboard_page.dart';
import 'my_tickets_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId; // Optional userId parameter

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  String? imageUrl;
  bool uploading = false;
  bool editingBio = false;
  bool editingLinks = false;
  bool isOwner = false;
  String? userRole;

  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  late Future<Map<String, dynamic>> userDataFuture;

  @override
  void initState() {
    super.initState();
    userDataFuture = _loadUserData();
  }

  // Load user data from Supabase
  Future<Map<String, dynamic>> _loadUserData() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception("Not logged in");

    final profileUserId = widget.userId ?? currentUser.id;
    isOwner = profileUserId == currentUser.id;

    final profile = await supabase
        .from('profiles')
        .select(
            'full_name, username, role, profile_image_url, bio, facebook, instagram, youtube, website')
        .eq('id', profileUserId)
        .single();

    final posts =
        await supabase.from('posts').select('*').eq('user_id', profileUserId);
    final activities = await supabase
        .from('activities')
        .select('*')
        .eq('user_id', profileUserId);

    setState(() {
      userRole = profile['role'];
    });

    imageUrl = profile['profile_image_url'];
    _bioController.text = profile['bio'] ?? "";
    _facebookController.text = profile['facebook'] ?? "";
    _instagramController.text = profile['instagram'] ?? "";
    _youtubeController.text = profile['youtube'] ?? "";
    _websiteController.text = profile['website'] ?? "";

    return {
      "full_name": profile['full_name'] ?? "Unknown",
      "username": profile['username'] ?? "",
      "role": profile['role'] ?? "Traveler",
      "bio": profile['bio'] ?? "",
      "facebook": profile['facebook'] ?? "",
      "instagram": profile['instagram'] ?? "",
      "youtube": profile['youtube'] ?? "",
      "website": profile['website'] ?? "",
      "posts": posts,
      "activities": activities,
      "postCount": posts.length,
      "activityCount": activities.length,
    };
  }

  // Upload profile picture
  Future<void> uploadProfilePicture() async {
    if (!isOwner) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => uploading = true);

    String cloudName = "dledkzh8h";
    String uploadPreset = "flutter_profile_upload";

    try {
      final uri =
          Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'profile_images'
        ..fields['public_id'] = "${supabase.auth.currentUser!.id}_profile"
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        final imageUrl = data['secure_url'];

        await supabase
            .from('profiles')
            .update({'profile_image_url': imageUrl}).eq(
                'id', supabase.auth.currentUser!.id);

        setState(() {
          this.imageUrl = imageUrl;
          uploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile picture updated!')),
        );
      } else {
        print("❌ Cloudinary upload failed: $resBody");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $resBody')),
        );
        setState(() => uploading = false);
      }
    } catch (e) {
      print("❌ Error uploading to Cloudinary: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => uploading = false);
    }
  }

  // Launch URL
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  // Delete post or activity
  Future<void> deleteItem(String table, String id) async {
    await supabase.from(table).delete().eq('id', id);
    setState(() {
      userDataFuture = _loadUserData();
    });
  }

  // Sign out
  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
    }
  }

  // Social link widget
  Widget _buildSocialLink(IconData icon, String label, String url) {
    return InkWell(
      onTap: () => _launchURL(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$label: $url",
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: isOwner ? _buildDrawer(context) : null,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xff12002f),
        title: Text(
          isOwner ? "My Profile" : "Profile",
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Cover + Profile Picture
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 220,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage("assets/cover_image.jpg"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      height: 240,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  imageUrl != null && imageUrl!.isNotEmpty
                                      ? NetworkImage(imageUrl!)
                                      : const AssetImage(
                                              "assets/default_avatar.png")
                                          as ImageProvider,
                            ),
                            if (isOwner)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: uploadProfilePicture,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Text(data['full_name'],
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("@${data['username']}",
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),

                // Bio Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: editingBio
                      ? Column(
                          children: [
                            TextField(
                              controller: _bioController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: "Write something about yourself...",
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await supabase.from('profiles').update({
                                      'bio': _bioController.text.trim()
                                    }).eq('id', supabase.auth.currentUser!.id);

                                    setState(() {
                                      editingBio = false;
                                      userDataFuture = _loadUserData();
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Bio updated!')));
                                  },
                                  child: const Text("Save"),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: () =>
                                      setState(() => editingBio = false),
                                  child: const Text("Cancel"),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                data['bio'].isNotEmpty
                                    ? data['bio']
                                    : "No bio added yet.",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            if (isOwner)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () =>
                                    setState(() => editingBio = true),
                              ),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

                // Social Links Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: editingLinks && isOwner
                      ? Column(
                          children: [
                            _buildSocialField("Facebook", _facebookController),
                            _buildSocialField(
                                "Instagram", _instagramController),
                            _buildSocialField("YouTube", _youtubeController),
                            _buildSocialField("Website", _websiteController),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await supabase.from('profiles').update({
                                      'facebook':
                                          _facebookController.text.trim(),
                                      'instagram':
                                          _instagramController.text.trim(),
                                      'youtube': _youtubeController.text.trim(),
                                      'website': _websiteController.text.trim(),
                                    }).eq('id', supabase.auth.currentUser!.id);

                                    setState(() {
                                      editingLinks = false;
                                      userDataFuture = _loadUserData();
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Links updated!')));
                                  },
                                  child: const Text("Save"),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: () =>
                                      setState(() => editingLinks = false),
                                  child: const Text("Cancel"),
                                ),
                              ],
                            )
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Social Links",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            const SizedBox(height: 10),
                            if (data['facebook'].isNotEmpty)
                              _buildSocialLink(
                                  Icons.facebook, "Facebook", data['facebook']),
                            if (data['instagram'].isNotEmpty)
                              _buildSocialLink(Icons.camera_alt, "Instagram",
                                  data['instagram']),
                            if (data['youtube'].isNotEmpty)
                              _buildSocialLink(Icons.play_circle_fill,
                                  "YouTube", data['youtube']),
                            if (data['website'].isNotEmpty)
                              _buildSocialLink(
                                  Icons.language, "Website", data['website']),
                            if (isOwner)
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      setState(() => editingLinks = true),
                                ),
                              ),
                          ],
                        ),
                ),

                const SizedBox(height: 30),

                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(Icons.verified_user, "Role", data['role']),
                      _buildStat(
                          Icons.article, "Posts", data['postCount'].toString()),
                      _buildStat(Icons.event, "Activities",
                          data['activityCount'].toString()),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Posts and Activities
                _buildHorizontalSection(
                  title: "Posts",
                  dataList: data['posts'],
                  color: Colors.blueAccent,
                  onTap: (item) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailsPage(post: item),
                      ),
                    );
                  },
                  onDelete: (id) => isOwner ? deleteItem('posts', id) : null,
                ),
                const SizedBox(height: 20),
                _buildHorizontalSection(
                  title: "Activities",
                  dataList: data['activities'],
                  color: Colors.purple,
                  onTap: (item) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailsPage(activity: item),
                      ),
                    );
                  },
                  onDelete: (id) =>
                      isOwner ? deleteItem('activities', id) : null,
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // Social input fields for editing
  Widget _buildSocialField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text("Menu",
                style: TextStyle(color: Colors.white, fontSize: 22)),
          ),
          _buildDrawerItem(
              Icons.home, "Home", () => _navigateTo(context, const HomePage())),
          _buildDrawerItem(Icons.post_add, "My Posts",
              () => _navigateTo(context, const MyPostsPage())),
          _buildDrawerItem(Icons.explore, "My Activities",
              () => _navigateTo(context, const MyActivitiesPage())),
          _buildDrawerItem(Icons.favorite, "Favorites",
              () => _navigateTo(context, const FavoritesPage())),
          _buildDrawerItem(Icons.book_online, "Bookings",
              () => _navigateTo(context, const BookingsPage())),
          _buildDrawerItem(Icons.person, "Dashboard",
              () => _navigateTo(context, const UserDashboardPage())),
          _buildDrawerItem(Icons.confirmation_num, "My Tickets",
              () => _navigateTo(context, const MyTicketsPage())),
          if (userRole == 'admin')
            _buildDrawerItem(Icons.admin_panel_settings, "Admin Dashboard", () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
              );
            }),
          const Divider(),
          _buildDrawerItem(Icons.logout, "Sign Out", () => _signOut(context)),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(IconData icon, String text, VoidCallback onTap) {
    return ListTile(leading: Icon(icon), title: Text(text), onTap: onTap);
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 28),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildHorizontalSection({
    required String title,
    required List dataList,
    required Color color,
    required Function(Map<String, dynamic>) onTap,
    required Function(String) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: dataList.isEmpty
              ? const Center(child: Text("No items yet"))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dataList.length,
                  itemBuilder: (context, index) {
                    final item = dataList[index];
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: InkWell(
                        onTap: () => onTap(item),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        image: DecorationImage(
                                          image: item['image_url'] != null
                                              ? NetworkImage(item['image_url'])
                                              : const AssetImage(
                                                      'assets/default_image.jpg')
                                                  as ImageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['title'] ?? 'Untitled',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isOwner)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: () => onDelete(item['id']),
                                  child: const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.redAccent,
                                    child: Icon(Icons.delete,
                                        color: Colors.white, size: 14),
                                  ),
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
    );
  }
}
