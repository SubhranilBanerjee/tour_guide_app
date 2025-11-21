import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

import 'bookings_page.dart'; // Ensure this exists
import 'post_details_page.dart'; // Ensure this exists

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final supabase = Supabase.instance.client;

  final titleController = TextEditingController();
  final descController = TextEditingController();
  final locationController = TextEditingController();
  final priceController = TextEditingController();
  final searchController = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  final startTimeController = TextEditingController();

  File? _fileImage;
  Uint8List? _webImage;
  String? _uploadedImageUrl;

  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> filteredPosts = [];
  Set<String> favoritePostIds = {};
  bool isLoading = true;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _initData(); // Combined initialization for better control
  }

  Future<void> _initData() async {
    setState(() => isLoading = true);
    await Future.wait([
      loadPosts(),
      loadFavorites(),
      loadUserRole(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> loadUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() => currentUserRole = data['role']);
      }
    } catch (e) {
      print("❌ Error fetching user role: $e");
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _webImage = bytes);
      } else {
        setState(() => _fileImage = File(picked.path));
      }
    }
  }

// Add your Cloudinary credentials
  String cloudName = "dledkzh8h";
  String uploadPreset = "flutter_profile_upload";

  Future<String?> uploadImage() async {
    try {
      if (_fileImage == null && _webImage == null) return null;

      final uri =
          Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb && _webImage != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _webImage!,
          filename: 'upload.jpg',
        ));
      } else if (_fileImage != null) {
        request.files
            .add(await http.MultipartFile.fromPath('file', _fileImage!.path));
      }

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        return data['secure_url']; // ✅ This is your Cloudinary image URL
      } else {
        print("❌ Cloudinary upload failed: ${response.statusCode}");
        print("Response: $resBody");
        return null;
      }
    } catch (e) {
      print("❌ Error uploading image to Cloudinary: $e");
      return null;
    }
  }

  Future<void> loadPosts() async {
    try {
      final data = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          posts = List<Map<String, dynamic>>.from(data as List);
          filteredPosts = posts;
        });
      }
    } catch (e) {
      print("❌ Error fetching posts: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching posts: $e")),
        );
      }
    }
  }

  Future<void> loadFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data =
          await supabase.from('favorites').select().eq('user_id', user.id);
      final favorites = List<Map<String, dynamic>>.from(data as List);
      if (mounted) {
        setState(() {
          favoritePostIds =
              favorites.map((f) => f['post_id'].toString()).toSet();
        });
      }
    } catch (e) {
      print("❌ Error loading favorites: $e");
    }
  }

  Future<void> createPost() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final title = titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Title is required")),
        );
      }
      return;
    }

    try {
      final imageUrl = await uploadImage();

      await supabase.from('posts').insert({
        'user_id': user.id,
        'title': title,
        'description': descController.text.trim(),
        'location': locationController.text.trim(),
        'price': priceController.text.isEmpty
            ? null
            : double.tryParse(priceController.text),
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
        'from_date':
            fromDateController.text.isNotEmpty ? fromDateController.text : null,
        'to_date':
            toDateController.text.isNotEmpty ? toDateController.text : null,
        'start_time': startTimeController.text.isNotEmpty
            ? startTimeController.text
            : null,
      });

      clearForm();
      await loadPosts(); // Reload posts to show the new one
      if (mounted) {
        Navigator.pop(context); // Close the bottom sheet

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Post created successfully")),
        );
      }
    } catch (e) {
      print("❌ Error creating post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Failed to create post: $e")),
        );
      }
    }
  }

  Future<void> toggleFavorite(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isFavorite = favoritePostIds.contains(postId);
    try {
      if (isFavorite) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
        favoritePostIds.remove(postId);
      } else {
        await supabase.from('favorites').insert({
          'user_id': user.id,
          'post_id': postId,
          'created_at': DateTime.now().toIso8601String(),
        });
        favoritePostIds.add(postId);
      }
      if (mounted) {
        setState(() {}); // Rebuild to update favorite icon
      }
    } catch (e) {
      print("❌ Error updating favorites: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update favorite: $e")),
        );
      }
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await supabase.from('posts').delete().eq('id', postId);
      if (mounted) {
        setState(() {
          posts.removeWhere((post) => post['id'].toString() == postId);
          filteredPosts.removeWhere((post) => post['id'].toString() == postId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Post deleted")),
        );
      }
    } catch (e) {
      print("❌ Error deleting post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete post: $e")),
        );
      }
    }
  }

  Future<void> createBooking(Map<String, dynamic> post) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to book")),
      );
      return;
    }

    // Ask user for number of people before creating booking
    int? numberOfPeople = await showDialog<int>(
      context: context,
      builder: (context) {
        int tempValue = 1;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Select number of people"),
          content: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$tempValue",
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (tempValue > 1) setState(() => tempValue--);
                      },
                      icon: const Icon(Icons.remove_circle_outline, size: 28),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () {
                        setState(() => tempValue++);
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempValue),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );

    if (numberOfPeople == null) return; // Cancelled

    try {
      // Check if already booked
      final existingBooking = await supabase
          .from('bookings')
          .select('id')
          .eq('user_id', user.id)
          .eq('post_id', post['id'])
          .maybeSingle();

      if (existingBooking != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ You have already booked this post.")),
        );
        return;
      }

      // ✅ Insert booking with selected number of people
      await supabase.from('bookings').insert({
        'user_id': user.id,
        'post_id': post['id'],
        'created_at': DateTime.now().toIso8601String(),
        'price': post['price'],
        'status': 'pending',
        'number_of_people': numberOfPeople, // 🧩 Add this
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Booking created successfully")),
      );
    } catch (e) {
      print("❌ Error creating booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Failed to create booking: $e")),
      );
    }
  }

  void clearForm() {
    titleController.clear();
    descController.clear();
    locationController.clear();
    priceController.clear();
    fromDateController.clear();
    toDateController.clear();

    if (mounted) {
      setState(() {
        _fileImage = null;
        _webImage = null;
        _uploadedImageUrl = null;
      });
    }
  }

  void searchPosts(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredPosts = posts.where((post) {
        final title = (post['title'] ?? '').toString().toLowerCase();
        final desc = (post['description'] ?? '').toString().toLowerCase();
        final location = (post['location'] ?? '').toString().toLowerCase();
        return title.contains(lowerQuery) ||
            desc.contains(lowerQuery) ||
            location.contains(lowerQuery);
      }).toList();
    });
  }

  // Helper for formatted date
  String _formatDate(dynamic dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (e) {
      return dateString.toString(); // Return original if parsing fails
    }
  }

  void _openCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Floating style
      builder: (context) {
        return Center(
          child: FractionallySizedBox(
            widthFactor: 0.9,
            heightFactor: 0.7,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xff000000),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                ),
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setModalState) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔹 Header
                          // 🌍 Travel Icon Header
                          Container(
                            padding: const EdgeInsets.only(top: 10, bottom: 15),
                            child: Column(
                              children: [
                                // ✈️ Plane inside blue circle
                                Container(
                                  height: 70,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent, // circle color
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.flight_takeoff,
                                    color: Colors.white,
                                    size: 35,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 🔹 Title text
                                Text(
                                  "Post a Tour",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent.shade700,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),

                          // 📝 Fields
                          _buildInputField(
                            controller: titleController,
                            label: "Title *",
                            icon: Icons.title,
                          ),
                          _buildInputField(
                            controller: descController,
                            label: "Description",
                            icon: Icons.description,
                          ),
                          _buildInputField(
                            controller: locationController,
                            label: "Location",
                            icon: Icons.location_on,
                          ),
                          _buildDateField(
                            context,
                            setModalState,
                            controller: fromDateController,
                            label: "From Date",
                            icon: Icons.date_range,
                          ),
                          _buildTimeField(
                            context,
                            controller: startTimeController,
                            label: "Start Time",
                          ),
                          _buildDateField(
                            context,
                            setModalState,
                            controller: toDateController,
                            label: "To Date",
                            icon: Icons.date_range,
                          ),
                          _buildInputField(
                            controller: priceController,
                            label: "Price (optional)",
                            icon: Icons.currency_rupee,
                            keyboardType: TextInputType.number,
                          ),

                          const SizedBox(height: 20),

                          // 🖼️ Image preview
                          if (_webImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _webImage!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else if (_fileImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _fileImage!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 10),

                          // 📸 Pick Image
                          ElevatedButton.icon(
                            onPressed: () async {
                              await pickImage();
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.image, color: Colors.white),
                            label: const Text("Pick Image",
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // ✅ Submit
                          ElevatedButton(
                            onPressed: () => createPost(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff5fc8ff),
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Create Post",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Single-line text field with underline style
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade700),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent, width: 1.3),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
      ),
    );
  }

  /// 🔹 Date picker with underline style
  Widget _buildDateField(BuildContext context, StateSetter setModalState,
      {required TextEditingController controller,
      required String label,
      required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade700),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent, width: 1.3),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            setModalState(() {
              controller.text =
                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            });
          }
        },
      ),
    );
  }

  /// 🔹 Time picker with underline style
  Widget _buildTimeField(BuildContext context,
      {required TextEditingController controller, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade700),
          prefixIcon: const Icon(Icons.access_time, color: Colors.blueAccent),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent, width: 1.3),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (time != null) controller.text = time.format(context);
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchProfileData(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('full_name, profile_image_url')
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint("Error fetching profile data: $e");
      return null;
    }
  }

  // Helper widget for detail rows within a card
  Widget _buildDetailRow(IconData icon, String value,
      {Color? color, FontWeight? fontWeight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                color: color ?? Colors.black87,
                fontWeight: fontWeight ?? FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final user = supabase.auth.currentUser;
    final isFavorite = favoritePostIds.contains(post['id'].toString());
    final isOwner = user != null && post['user_id'] == user.id;
    final isAdmin = currentUserRole == "admin";

    final imageUrl = post['image_url'];
    final postTitle = post['title'] ?? "Untitled Post";
    final postDescription = post['description'] ?? "No description available.";
    final postLocation = post['location'] ?? "Unknown Location";
    final postPrice = post['price'] != null ? "₹${post['price']}" : "Free";
    final postFromDate = _formatDate(post['from_date']);
    final postToDate = _formatDate(post['to_date']);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchProfileData(post['user_id']),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final profileName = profile?['full_name'] ?? "Unknown User";
        final profileImage = profile?['profile_image_url'];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PostDetailsPage(post: post)),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PROFILE HEADER SECTION ---
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            (profileImage != null && profileImage.isNotEmpty)
                                ? NetworkImage(profileImage)
                                : const AssetImage('assets/default_.png')
                                    as ImageProvider,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          profileName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color:
                              isFavorite ? Colors.redAccent : Colors.grey[600],
                        ),
                        onPressed: () => toggleFavorite(post['id'].toString()),
                      ),
                    ],
                  ),
                ),

                // --- POST IMAGE ---
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(0),
                    ),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child:
                              const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),

                // --- POST DETAILS ---
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        postDescription,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.location_on, postLocation),
                      _buildDetailRow(
                          Icons.calendar_today, "$postFromDate - $postToDate"),
                      _buildDetailRow(Icons.access_time,
                          "Start Time: ${post['start_time'] ?? 'N/A'}"),
                      _buildDetailRow(Icons.money, postPrice,
                          color: Colors.green),
                      const SizedBox(height: 10),

                      // --- ACTION BUTTONS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => createBooking(post),
                              icon: const Icon(Icons.book_online,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                "Book Now",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (isOwner || isAdmin) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  deletePost(post['id'].toString()),
                            ),
                          ]
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F3FF), // Light blue background
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _initData,
          color: Colors.blueAccent,
          child: Column(
            children: [
              // 🌟 Floating Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: searchPosts,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: "Search activities, places or categories...",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(left: 8, right: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.search_rounded,
                            color: Colors.blueAccent, size: 26),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.filter_alt_rounded,
                            color: Colors.blueAccent),
                        onPressed: () {
                          // TODO: Add category filter logic
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 16.0),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

// 🌟 Heading Section (same style as Activities Page)
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Explore Tours",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: 0.8,
                        fontFamily: GoogleFonts.waterfall()
                            .fontFamily, // If using GoogleFonts, replace with GoogleFonts.waterfall().fontFamily
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Expanded(
                          child: Divider(
                            thickness: 1.5,
                            color: Colors.black54,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "✦",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            thickness: 1.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Discover the best experiences around you",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 🌸 Posts List
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredPosts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.sentiment_dissatisfied,
                                    size: 80, color: Colors.grey),
                                const SizedBox(height: 15),
                                const Text(
                                  "No activities found!",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Try a different search or add your own post.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 30),
                                ElevatedButton.icon(
                                  onPressed: _openCreatePostSheet,
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: Colors.white),
                                  label: const Text("Create New Post",
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            itemCount: filteredPosts.length,
                            itemBuilder: (context, index) {
                              final post = filteredPosts[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: _buildPostCard(post),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),

      // 🧭 Floating Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePostSheet,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 26),
        label: const Text(
          "Post New Tour",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
