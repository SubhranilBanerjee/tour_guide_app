import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 🎯 Import the page we just created for navigation
import 'collection_details_page.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> collections = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Fetch collections from the 'user_collections' table
      // We select the ID, Name, and Created_at time.
      final data = await supabase
          .from('user_collections')
          .select('id, name, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        collections = List<Map<String, dynamic>>.from(data as List);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching collections: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load collections.")),
        );
      }
      setState(() => isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return "Created: ${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return 'Unknown date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Saved Collections 📚"),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : collections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_off,
                            size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          "You haven't created any collections yet.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Go to your Favorites to start organizing!",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.folder_open,
                            color: Colors.indigo, size: 30),
                        title: Text(
                          collection['name'] ?? 'Untitled Collection',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        subtitle: Text(
                          _formatDate(collection['created_at']),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                        onTap: () {
                          // 🎯 Navigation to the CollectionDetailsPage
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CollectionDetailsPage(
                                collectionId: collection['id'] as String,
                                collectionName: collection['name'] as String,
                              ),
                            ),
                          ).then((_) {
                            // Optionally refresh the list when returning from details page
                            _fetchCollections();
                          });
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
