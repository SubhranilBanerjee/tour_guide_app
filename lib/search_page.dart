import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'activity_details_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final supabase = Supabase.instance.client;
  String selectedSort = 'Newest';

  final List<String> categories = [
    'adventure',
    'food and drinks',
    'recreation',
    'fun and games',
    'educational',
    'services',
    'misc',
  ];

  String? selectedCategory; // store selected category

  // Form controllers
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final locationController = TextEditingController();
  final priceController = TextEditingController();
  final searchController = TextEditingController();

  // Image handling
  File? _fileImage;
  Uint8List? _webImage;

  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> filteredActivities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadActivities();
    searchController.addListener(_filterActivities);
  }

// Check if a specific activity is favourited by current user
  Future<bool> isFavourite(String activityId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    // Supabase RLS policies must allow SELECT on 'favourites_acts'
    final data = await supabase
        .from('favourites_acts')
        .select()
        .eq('user_id', user.id)
        .eq('activity_id', activityId);

    return data.isNotEmpty;
  }

// Toggle favourite (add or remove)
  Future<void> toggleFavourite(String activityId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ Please log in to manage favourites")),
        );
      }
      return;
    }

    // Optimistic UI update is generally preferred for instant feel,
    // but for simplicity, we'll refresh the state on success.

    // Check current state (we can use the isFavourite check again)
    final favData = await supabase
        .from('favourites_acts')
        .select()
        .eq('user_id', user.id)
        .eq('activity_id', activityId);

    bool isCurrentlyFavourited = favData.isNotEmpty;

    try {
      if (isCurrentlyFavourited) {
        // Already favourited → remove
        await supabase
            .from('favourites_acts')
            .delete()
            .eq('user_id', user.id)
            .eq('activity_id', activityId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("💔 Removed from Favourites")),
          );
        }
      } else {
        // Not favourited → add
        await supabase.from('favourites_acts').insert({
          'user_id': user.id,
          'activity_id': activityId,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❤️ Added to Favourites")),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error toggling favourite: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "❌ Failed to ${isCurrentlyFavourited ? 'remove' : 'add'} favourite."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Refresh the UI to reflect the change for this card
    setState(() {});
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    locationController.dispose();
    priceController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // Pick image (unchanged)
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

  // Upload image (unchanged)
  Future<String?> uploadImage() async {
    // 👇 Replace these with your own Cloudinary credentials
    String cloudName = "dledkzh8h";
    String uploadPreset = "flutter_profile_upload";

    try {
      if (_fileImage == null && _webImage == null) {
        if (kDebugMode) {
          print("⚠️ No image selected");
        }
        return null;
      }

      // Cloudinary upload URL
      final uri =
          Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      // Build the request
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset;

      // Attach file data
      if (kIsWeb && _webImage != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _webImage!,
          filename: 'activity_image.jpg',
        ));
      } else if (_fileImage != null) {
        request.files
            .add(await http.MultipartFile.fromPath('file', _fileImage!.path));
      }

      // Send request
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        if (kDebugMode) {
          print("✅ Cloudinary upload success: ${data['secure_url']}");
        }
        return data['secure_url']; // <-- Use this as your image URL
      } else {
        if (kDebugMode) {
          print("❌ Cloudinary upload failed: ${response.statusCode}");
          print("Response: $resBody");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error uploading image to Cloudinary: $e");
      }
      return null;
    }
  }

  // Load activities from Supabase (unchanged)
  Future<void> loadActivities() async {
    try {
      final data = await supabase
          .from('activities')
          .select('*, profiles(full_name, profile_image_url)')
          .order('created_at', ascending: false);

      setState(() {
        activities = List<Map<String, dynamic>>.from(data as List);
        filteredActivities = List.from(activities);
        isLoading = false;
        _sortActivities(selectedSort); // Apply current sort after loading
      });
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error fetching activities: $e");
      }
    }
  }

  // Filter activities based on search (unchanged)
  /// FILTER ACTIVITIES (Search + Category)
  void _filterActivities() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredActivities = activities.where((activity) {
        final title = (activity['title'] ?? '').toLowerCase();
        final desc = (activity['description'] ?? '').toLowerCase();
        final location = (activity['location'] ?? '').toLowerCase();

        // SEARCH FILTER
        final matchesSearch = title.contains(query) ||
            desc.contains(query) ||
            location.contains(query);

        // CATEGORY FILTER
        final activityCategory = (activity['category'] ?? '').toLowerCase();
        final matchesCategory = selectedCategory == null ||
            selectedCategory!.toLowerCase() == 'all' ||
            activityCategory == selectedCategory!.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();

      // After filtering, apply sorting to the results
      _sortActivities(selectedSort, shouldSetState: false);
    });
  }

  // Create new activity (unchanged)
  // --- UPDATED createActivity ---
// NOTE: Return bool to indicate success (true) or failure (false).
  Future<bool> createActivity() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final title = titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Title is required")),
        );
      }
      return false;
    }

    try {
      final imageUrl = await uploadImage();

      await supabase.from('activities').insert({
        'user_id': user.id,
        'title': title,
        'description': descController.text.trim(),
        'location': locationController.text.trim(),
        'price': priceController.text.isEmpty
            ? null
            : double.tryParse(priceController.text),
        'image_url': imageUrl,
        'category': selectedCategory,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Clear form and refresh list on success
      clearForm();
      await loadActivities();

      // Show success snack (you said createActivity already shows success; keep it)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Activity created successfully")),
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error creating activity: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Failed to create activity")),
        );
      }
      return false;
    }
  }

  // Delete activity (unchanged)
  Future<void> deleteActivity(String activityId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('activities')
          .delete()
          .eq('id', activityId)
          .eq('user_id', user.id);

      setState(() {
        activities.removeWhere((a) => a['id'].toString() == activityId);
        filteredActivities.removeWhere((a) => a['id'].toString() == activityId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Activity deleted successfully")),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error deleting activity: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Failed to delete activity")),
        );
      }
    }
  }

  // Sort activities (unchanged)
  void _sortActivities(String sortType, {bool shouldSetState = true}) {
    if (shouldSetState) {
      setState(() {
        selectedSort = sortType;
      });
    } else {
      selectedSort = sortType;
    }

    // Sort the filtered list, not the main activities list
    // Filter activities based on search AND category
    void _filterActivities() {
      final query = searchController.text.toLowerCase();

      // Clear selected category if the user starts typing a search query,
      // or handle both simultaneously. We'll handle both simultaneously for flexibility.

      setState(() {
        filteredActivities = activities.where((activity) {
          final title = (activity['title'] ?? '').toLowerCase();
          final desc = (activity['description'] ?? '').toLowerCase();
          final location = (activity['location'] ?? '').toLowerCase();

          // --- Search Filter Check ---
          final matchesSearch = title.contains(query) ||
              desc.contains(query) ||
              location.contains(query);

          // --- Category Filter Check ---
          // If selectedCategory is null or 'All', this check is true (no filter applied)
          // Otherwise, it checks if the activity's category matches the selected one.
          final activityCategory = (activity['category'] ?? '').toLowerCase();
          final matchesCategory = selectedCategory == null ||
              selectedCategory!.toLowerCase() == 'all' ||
              activityCategory == selectedCategory!.toLowerCase();

          // Only include the activity if it passes BOTH filters
          return matchesSearch && matchesCategory;
        }).toList();

        // Re-sort the newly filtered list
        _sortActivities(selectedSort, shouldSetState: false);
      });
    }

    ;

    if (shouldSetState) {
      setState(() {});
    }
  }

  // Reset form (unchanged)
  void clearForm() {
    titleController.clear();
    descController.clear();
    locationController.clear();
    priceController.clear();
    setState(() {
      _fileImage = null;
      _webImage = null;
    });
  }

  // Bottom sheet for creating activity (unchanged)
  // --- UPDATED centered dialog: _openCreateActivitySheet ---
  void _openCreateActivitySheet() {
    // Reset any previous modal-only error state
    String? titleError;
    bool isCreating = false;

    // Ensure category is initialised (keeps class-level selectedCategory)
    // Do NOT clear selectedCategory here so user choice persists across opens if desired.
    // (You stated selectedCategory is a State variable and you want clearing after success.)

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          Future<void> pickImageModal() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery);

            if (picked != null) {
              if (kIsWeb) {
                final bytes = await picked.readAsBytes();
                setModalState(() => _webImage = bytes);
                setState(() => _webImage = bytes);
              } else {
                setModalState(() => _fileImage = File(picked.path));
                setState(() => _fileImage = File(picked.path));
              }
            }
          }

          // Local helper for Add button press
          Future<void> onAddPressed() async {
            // Validate title locally and show inline error
            final title = titleController.text.trim();
            if (title.isEmpty) {
              setModalState(() => titleError = "Title is required");
              return;
            } else {
              if (titleError != null) setModalState(() => titleError = null);
            }

            // Start loading
            setModalState(() => isCreating = true);

            // Call createActivity (await its boolean result)
            bool success = await createActivity();

            // Stop loading
            if (mounted) setModalState(() => isCreating = false);

            if (success) {
              // Clear the selectedCategory state (you asked to clear form after success)
              if (mounted) setState(() => selectedCategory = null);

              // Close dialog immediately (you asked for immediate close)
              if (mounted) Navigator.of(context).pop();
              // createActivity already showed success snackbar per your setup
            } else {
              // keep dialog open (createActivity already showed failure snackbar)
              // Optionally, you could highlight fields here if desired
            }
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: EdgeInsets.zero,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sky-blue header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.shade400,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.explore, color: Colors.white, size: 26),
                        SizedBox(width: 10),
                        Text(
                          "Create Activity",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Form body
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Title
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: "Title *",
                            border: const OutlineInputBorder(),
                            errorText: titleError,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                              labelText: "Description",
                              border: OutlineInputBorder()),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),

                        // Location + Price row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: locationController,
                                decoration: const InputDecoration(
                                    labelText: "Location",
                                    border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: priceController,
                                decoration: const InputDecoration(
                                    labelText: "Price",
                                    border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Category dropdown (hardcoded list)
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: "Category",
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map((cat) => DropdownMenuItem(
                                  value: cat, child: Text(cat)))
                              .toList(),
                          onChanged: (value) {
                            // update both modal and page state so selection persists where appropriate
                            setModalState(() => selectedCategory = value);
                            setState(() => selectedCategory = value);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Image preview (if any)
                        if (_webImage != null || _fileImage != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb && _webImage != null
                                ? Image.memory(_webImage!,
                                    height: 150, fit: BoxFit.cover)
                                : Image.file(_fileImage!,
                                    height: 150, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Pick Image button
                        TextButton.icon(
                          onPressed: pickImageModal,
                          icon:
                              const Icon(Icons.image, color: Colors.lightBlue),
                          label: Text(
                            _webImage != null || _fileImage != null
                                ? "Change Image"
                                : "Pick Image",
                            style: const TextStyle(color: Colors.lightBlue),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Add Activity button (replaces text with spinner while creating)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isCreating ? null : onAddPressed,
                            icon: isCreating
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: isCreating
                                ? const Text("Creating...")
                                : const Text("Add Activity"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // --- Helper: get average rating from reviews_acts ---
  Future<double> getActivityRating(String activityId) async {
    try {
      final response = await supabase
          .from('reviews_acts')
          .select('rating')
          .eq('activity_id', activityId);

      if (response == null || (response is List && response.isEmpty)) {
        return 0.0;
      }

      double total = 0;
      int count = 0;
      for (var r in response as List) {
        if (r == null) continue;
        final val = (r['rating'] ?? 0);
        if (val is num) {
          total += val.toDouble();
          count++;
        }
      }
      if (count == 0) return 0.0;
      return total / count;
    } catch (e) {
      if (kDebugMode) print("Error fetching rating for $activityId -> $e");
      return 0.0;
    }
  }

// --- Pastel color map for Title Case categories ---
  Color _categoryColor(String rawCategory) {
    final c = (rawCategory ?? '').toString().trim().toLowerCase();
    switch (c) {
      case 'adventure':
        return const Color(0xFFB3E5FC); // pastel blue
      case 'food and drinks':
        return const Color(0xFFFFF3BF); // pastel yellow
      case 'recreation':
        return const Color(0xFFD7FFD9); // pastel green
      case 'fun and games':
        return const Color(0xFFE7D7FF); // pastel purple
      case 'educational':
        return const Color(0xFFFFE0CC); // pastel peach
      case 'services':
        return const Color(0xFFDCE7FF); // pastel light blue
      case 'misc':
      case 'misc.':
        return const Color(0xFFF5F5F5); // pastel gray
      default:
        return const Color(0xFFF0F0F0);
    }
  }

// --- Helper to build star icons row ---
  Widget _buildStarRow(double rating) {
    // rating 0.0..5.0
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (i <= rating.floor()) {
        stars.add(const Icon(Icons.star,
            size: 16, color: Color(0xFFFFC857))); // amber
      } else if (i - rating <= 0.5) {
        stars.add(
            const Icon(Icons.star_half, size: 16, color: Color(0xFFFFC857)));
      } else {
        stars.add(
            const Icon(Icons.star_border, size: 16, color: Color(0xFFFFC857)));
      }
    }
    return Row(children: stars);
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final activityId = activity['id']?.toString() ?? '';
    final title = (activity['title'] ?? 'Untitled Activity').toString();
    final imageUrl = activity['image_url']?.toString();

    // ✅ Extract profile info
    final profile = activity['profiles'] ?? {};
    final fullName = (profile['full_name'] ?? 'Unknown User').toString();
    final avatarUrl = profile['profile_image_url']?.toString();
    final profileId = profile['id']; // 'id' from profiles table

    // ✅ Logged-in user ID
    final currentUserId = supabase.auth.currentUser?.id;

    // ✅ Category label
    String rawCategory = (activity['category'] ?? '').toString();
    String categoryLabel = rawCategory.isEmpty
        ? 'Misc'
        : rawCategory.splitMapJoin(
            RegExp(r'\b\w+\b'),
            onMatch: (m) =>
                '${m[0]![0].toUpperCase()}${m[0]!.substring(1).toLowerCase()}',
          );

    final chipColor = _categoryColor(categoryLabel);
    final futureIsFav = isFavourite(activityId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header — profile info + optional delete button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  backgroundColor: Colors.grey.shade300,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),

                // ✅ Clickable username
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final userId = activity['user_id'];
                      if (userId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfilePage(userId: userId),
                          ),
                        );
                      }
                    },
                    child: Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ),

                // ✅ Delete button only for owner
                if (activity['user_id'] == currentUserId)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 22),
                    onPressed: () => _confirmDelete(activityId),
                  ),
              ],
            ),
          ),

          // ✅ Post Image
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 170,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 40, color: Colors.grey),
                      ),
                    ),
                  )
                : Container(
                    height: 170,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image, size: 40, color: Colors.grey),
                    ),
                  ),
          ),

          // ✅ Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  (activity['description'] ?? 'No description available')
                      .toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xbf868686),
                  ),
                ),
                Text(
                  (activity['location'] ?? 'No specific location').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Color(0xffff0000),
                  ),
                ),

                const SizedBox(height: 8),

                // Category Chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    categoryLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Rating + Favourite
                Row(
                  children: [
                    FutureBuilder<double>(
                      future: getActivityRating(activityId),
                      builder: (context, snapshot) {
                        final avg = (snapshot.data ?? 0.0);
                        return Row(
                          children: [
                            _buildStarRow(avg),
                            const SizedBox(width: 8),
                            Text(
                              "${avg.toStringAsFixed(1)}/5",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    FutureBuilder<bool>(
                      future: futureIsFav,
                      builder: (context, snapFav) {
                        final isFav = snapFav.data ?? false;
                        if (snapFav.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.redAccent : Colors.black54,
                          ),
                          onPressed: () async {
                            await toggleFavourite(activityId);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String activityId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Activity"),
        content: const Text("Are you sure you want to delete this post?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('activities').delete().eq('id', activityId);
        setState(() {
          activities.removeWhere((a) => a['id'].toString() == activityId);
          filteredActivities
              .removeWhere((a) => a['id'].toString() == activityId);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const String aestheticFont = 'Montserrat';
    final double topPadding = MediaQuery.of(context).padding.top;

    // The final categories list
    final List<String> categories = [
      'All',
      'adventure',
      'food and drinks',
      'recreation',
      'fun and games',
      'educational',
      'services',
      'misc',
    ];

    return Scaffold(
      backgroundColor: const Color(0xc36bb2f4),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Small, Aesthetic Heading
          Padding(
            padding: EdgeInsets.fromLTRB(25, topPadding + 20, 25, 15),
            child: const Text(
              "Activities",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: 0.8,
                fontFamily: aestheticFont,
              ),
            ),
          ),

          // 2. Category Filter Buttons Section 🏷️
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final categoryName = categories[index];
                final displayCategory = categoryName
                    .split(' ')
                    .map((word) => word[0].toUpperCase() + word.substring(1))
                    .join(' ');

                final isSelected = categoryName == selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // This is where the filter action happens
                      setState(() {
                        selectedCategory = categoryName;
                        _filterActivities();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSelected ? const Color(0xFF1E88E5) : Colors.white,
                      foregroundColor:
                          isSelected ? Colors.white : Colors.black87,
                      elevation: isSelected ? 4 : 0,
                      shadowColor: isSelected
                          ? const Color(0xFF1E88E5).withOpacity(0.5)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(
                      displayCategory,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 3. Search Bar Section 🔍
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              onChanged: (value) => _filterActivities(),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: "Search activities...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1E88E5)),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          searchController.clear();
                          _filterActivities();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide:
                      const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // 4. Activities List
          Expanded(
            // ... (Rest of your list view logic remains here)
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
                : RefreshIndicator(
                    onRefresh: loadActivities,
                    color: const Color(0xff003cff),
                    child: filteredActivities.isEmpty
                        ? Center(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                color: Color(0xca0071f4),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sentiment_dissatisfied,
                                      size: 40, color: Colors.grey),
                                  SizedBox(height: 10),
                                  Text(
                                    "No activities found matching your criteria.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            itemCount: filteredActivities.length,
                            itemBuilder: (context, index) {
                              final activity = filteredActivities[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: _buildActivityCard(activity),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),

      // ➕ Floating Action Button (No change)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateActivitySheet,
        label: const Text(
          "Create New",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add_rounded, size: 28),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8,
      ),
    );
  }
}
