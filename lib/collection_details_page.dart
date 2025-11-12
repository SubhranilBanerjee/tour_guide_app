import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_details_page.dart';
import 'activity_details_page.dart';

class CollectionDetailsPage extends StatefulWidget {
  final String collectionId;
  final String collectionName;

  const CollectionDetailsPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  State<CollectionDetailsPage> createState() => _CollectionDetailsPageState();
}

class _CollectionDetailsPageState extends State<CollectionDetailsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> collectionItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollectionItems();
  }

  Future<void> _fetchCollectionItems() async {
    setState(() => isLoading = true);
    try {
      // Fetch all collection_items for this collection
      final itemsData = await supabase
          .from('collection_items')
          .select('id, fav_id, item_type')
          .eq('collection_id', widget.collectionId);

      final List<Map<String, dynamic>> fetchedItems = [];
      final List<String> postFavIds = [];
      final List<String> activityFavIds = [];

      for (var item in itemsData as List) {
        final String? favId = item['fav_id']?.toString();
        final String type = item['item_type'] ?? '';
        if (favId == null || favId.isEmpty) continue;

        if (type == 'post') {
          postFavIds.add(favId);
        } else if (type == 'activity') {
          activityFavIds.add(favId);
        }
      }

      // --- Fetch posts ---
      if (postFavIds.isNotEmpty) {
        final postFavorites = await supabase
            .from('favorites')
            .select('id, created_at, posts(*)')
            .inFilter('id', postFavIds);

        for (var fav in postFavorites) {
          if (fav['posts'] != null) {
            fetchedItems.add({
              'type': 'post',
              'fav_id': fav['id'].toString(),
              'data': fav['posts'],
            });
          }
        }
      }

      // --- Fetch activities ---
      if (activityFavIds.isNotEmpty) {
        // Here we assume collection_items.fav_id points to `favourites_acts.id`
        final activityFavorites = await supabase
            .from('favourites_acts')
            .select('id, created_at, activities(*)')
            .inFilter('id', activityFavIds);

        for (var fav in activityFavorites) {
          if (fav['activities'] != null) {
            fetchedItems.add({
              'type': 'activity',
              'fav_id': fav['id'].toString(),
              'data': fav['activities'],
            });
          }
        }
      }

      setState(() {
        collectionItems = fetchedItems;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching collection details: $e");
      setState(() => isLoading = false);
    }
  }

  Widget _buildCollectionItemCard(Map<String, dynamic> item) {
    final String type = item['type'] ?? '';
    final Map<String, dynamic> data = item['data'] ?? {};
    final String favId = item['fav_id']?.toString() ?? '';

    final typeLabel = type == 'post' ? 'Tour' : 'Activity';
    final typeIcon = type == 'post' ? Icons.public : Icons.pool;
    final typeColor =
        type == 'post' ? Colors.blue.shade800 : Colors.orange.shade800;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: (data['image_url'] != null)
              ? Image.network(
                  data['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: Icon(typeIcon, color: Colors.grey)),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: Icon(typeIcon, color: Colors.grey),
                ),
        ),
        title: Text(
          data['title'] ?? 'Untitled Item',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(data['location'] ?? 'Unknown location',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Row(
              children: [
                Icon(typeIcon, size: 14, color: typeColor),
                const SizedBox(width: 4),
                Text(typeLabel,
                    style: TextStyle(
                        fontSize: 13,
                        color: typeColor,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: () {
          if (type == 'post') {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => PostDetailsPage(post: data)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ActivityDetailsPage(activity: data)));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collectionName),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : collectionItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_off,
                            size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          "This collection is empty. Add items from your favorites!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: collectionItems.length,
                  itemBuilder: (context, index) =>
                      _buildCollectionItemCard(collectionItems[index]),
                ),
    );
  }
}
