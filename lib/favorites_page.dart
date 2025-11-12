import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_details_page.dart';
import 'activity_details_page.dart';
import 'collectionsPage.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> combinedFavorites = [];
  List<Map<String, dynamic>> userCollections = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFavoritesAndCollections();
  }

  Future<void> loadFavoritesAndCollections() async {
    setState(() => isLoading = true);
    await loadFavorites();
    await loadCollections();
    setState(() => isLoading = false);
  }

  Future<void> loadCollections() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('user_collections')
          .select('id, name')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        userCollections = List<Map<String, dynamic>>.from(data as List);
      });
    } catch (e) {
      debugPrint("❌ Error loading collections: $e");
    }
  }

  Future<void> loadFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final favPostsData = await supabase
          .from('favorites')
          .select('id, created_at, posts(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> favPosts =
          List<Map<String, dynamic>>.from(favPostsData as List)
              .map((e) => {
                    'type': 'post',
                    'fav_id': e['id'].toString(),
                    'created_at': e['created_at'],
                    'data': e['posts'],
                  })
              .toList();

      final favActsData = await supabase
          .from('favourites_acts')
          .select('id, created_at, activities(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> favActs =
          List<Map<String, dynamic>>.from(favActsData as List)
              .map((e) => {
                    'type': 'activity',
                    'fav_id': e['id'].toString(),
                    'created_at': e['created_at'],
                    'data': e['activities'],
                  })
              .toList();

      combinedFavorites = [...favPosts, ...favActs];
      combinedFavorites.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
    } catch (e) {
      debugPrint("❌ Error loading favorites: $e");
    }
  }

  Future<void> addToCollection(
      String collectionId, String favId, String itemType) async {
    try {
      final parsedFavId = itemType == 'activity'
          ? int.tryParse(favId) // activity favs are int
          : favId; // post favs are uuid

      await supabase.from('collection_items').insert({
        'collection_id': collectionId,
        'fav_id': parsedFavId,
        'item_type': itemType,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✨ Added to collection!")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error adding to collection: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Failed to add to collection (might already exist).")),
        );
      }
    }
  }

  void _showCollectionSelectorDialog(
      BuildContext context, Map<String, dynamic> fav) {
    final favId = fav['fav_id'].toString();
    final itemType = fav['type'];
    final itemTitle = fav['data']['title'] ?? 'this item';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add '$itemTitle' to Collection",
                      style: Theme.of(context).textTheme.titleLarge),
                  const Divider(),
                  ...userCollections.map((collection) => ListTile(
                        title: Text(collection['name']),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () {
                          Navigator.pop(context);
                          addToCollection(
                              collection['id'].toString(), favId, itemType);
                        },
                      )),
                  ListTile(
                    leading: const Icon(Icons.create_new_folder,
                        color: Colors.blueAccent),
                    title: const Text("Create New Collection"),
                    onTap: () {
                      Navigator.pop(context);
                      _showNewCollectionDialog(fav);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNewCollectionDialog(Map<String, dynamic> fav) {
    final TextEditingController nameController = TextEditingController();
    final user = supabase.auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Create New Collection"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Collection Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                try {
                  final response = await supabase
                      .from('user_collections')
                      .insert({
                        'user_id': user.id,
                        'name': newName,
                      })
                      .select()
                      .single();

                  final newCollectionId = response['id'].toString();

                  await addToCollection(
                      newCollectionId, fav['fav_id'].toString(), fav['type']);

                  await loadCollections();

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Collection '$newName' created successfully!")),
                    );
                  }
                } catch (e) {
                  debugPrint("❌ Error creating collection: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Failed to create collection.")),
                    );
                  }
                }
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeFavorite(String type, String favId) async {
    try {
      final table = type == 'post' ? 'favorites' : 'favourites_acts';
      await supabase.from(table).delete().eq('id', favId);
      setState(() {
        combinedFavorites
            .removeWhere((fav) => fav['fav_id'].toString() == favId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removed from favorites")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error removing favorite: $e");
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return 'Unknown';
    }
  }

  Widget buildFavoriteCard(Map<String, dynamic> fav) {
    final type = fav['type'];
    final data = fav['data'] ?? {};
    final favId = fav['fav_id'].toString();
    final title =
        data['title'] ?? "Untitled ${type == 'post' ? "Post" : "Activity"}";
    final imageUrl = data['image_url'];
    final description = data['description'] ?? '';
    final location = data['location'];
    final price = data['price'];
    final addedDate = formatDate(fav['created_at']);

    bool isExpanded = false; // local, will be captured by StatefulBuilder below

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      child: StatefulBuilder(builder: (context, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: tappable area (navigates) + chevron + delete icon
            InkWell(
              onTap: () {
                // Entire header tap opens details
                if (type == 'post') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PostDetailsPage(post: data)),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ActivityDetailsPage(activity: data)),
                  );
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                child: Row(
                  children: [
                    // image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl,
                              width: 60, height: 60, fit: BoxFit.cover)
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade300,
                              child:
                                  const Icon(Icons.photo, color: Colors.white),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text("Added on $addedDate",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    // delete icon (always visible)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () => removeFavorite(type, favId),
                      tooltip: 'Remove from favorites',
                    ),
                    // chevron to expand/collapse
                    IconButton(
                      icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => isExpanded = !isExpanded),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content area
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty)
                      Text(description, style: const TextStyle(fontSize: 14)),
                    if (location != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(location,
                                style: const TextStyle(fontSize: 14))),
                      ]),
                    ],
                    if (price != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.currency_rupee,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text("$price",
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showCollectionSelectorDialog(context, fav),
                        icon: const Icon(Icons.folder_open,
                            color: Color(0xff007BFF)),
                        label: const Text("Add to Collection",
                            style: TextStyle(color: Color(0xff007BFF))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xff007BFF)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Favorites"),
        backgroundColor: Colors.lightBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined,
                color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CollectionsPage()),
              );
            },
          )
        ],
      ),
      backgroundColor: const Color(0xFFE8F4FF), // 🌟 Light blue page background
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            )
          : combinedFavorites.isEmpty
              ? const Center(
                  child: Text(
                    "No favorites yet 💔",
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: combinedFavorites.length,
                  itemBuilder: (context, index) {
                    final fav = combinedFavorites[index];
                    return buildFavoriteCard(fav);
                  },
                ),
    );
  }
}
