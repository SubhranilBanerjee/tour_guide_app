import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageAdsPage extends StatefulWidget {
  const ManageAdsPage({super.key});

  @override
  State<ManageAdsPage> createState() => _ManageAdsPageState();
}

class _ManageAdsPageState extends State<ManageAdsPage> {
  final supabase = Supabase.instance.client;
  late Future<List<dynamic>> _futureAds;

  @override
  void initState() {
    super.initState();
    _futureAds = fetchAds();
  }

  Future<List<dynamic>> fetchAds() async {
    final result = await supabase
        .from('ads')
        .select('id, image_url, user_id, link')
        .order('id');
    return result as List<dynamic>;
  }

  Future<void> _confirmAndDelete(dynamic id) async {
    final doDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ad?'),
        content: const Text('This will permanently delete the ad. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (doDelete != true) return;
    await deleteAd(id);
  }

  Future<void> deleteAd(dynamic id) async {
    // show a blocking progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Attempt to convert id to int if possible (some schemas use integer PK)
      dynamic eqValue = id;
      if (id is String) {
        final intId = int.tryParse(id);
        if (intId != null) eqValue = intId;
      }

      // Perform delete and capture response
      final response = await supabase.from('ads').delete().eq('id', eqValue);

      // close progress dialog
      if (mounted) Navigator.of(context).pop();

      // Debug/log response (look at console)
      // response often returns the deleted rows (list) or null on error
      // Print to debug console so you can inspect the returned value
      // ignore: avoid_print
      print('Supabase delete response: $response');

      // Determine success: if response is a non-empty List => delete succeeded
      bool success = false;
      if (response is List && response.isNotEmpty) {
        success = true;
      } else if (response == null) {
        // null response — could indicate error depending on client version
        success = false;
      } else if (response is Map && response.containsKey('error')) {
        success = false;
      } else {
        // fallback: if returned something, treat as success
        success = true;
      }

      if (success) {
        if (!mounted) return;
        setState(() {
          _futureAds = fetchAds();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad deleted successfully')),
        );
      } else {
        // If not successful, show an error with helpful suggestions
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete failed — check console / RLS')),
        );
      }
    } catch (e, st) {
      if (mounted) Navigator.of(context).pop(); // close progress
      // ignore: avoid_print
      print('deleteAd error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Manage Ads"),
        backgroundColor: Colors.blueAccent,
      ),
      */
      body: FutureBuilder(
        future: _futureAds,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final ads = snapshot.data ?? [];

          if (ads.isEmpty) {
            return const Center(
              child: Text(
                "No ads found",
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];

              return Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AD IMAGE
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ad['image_url'] != null &&
                                ad['image_url'].toString().isNotEmpty
                            ? Image.network(
                                ad['image_url'],
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 180,
                                  color: Colors.grey[300],
                                  child:
                                      const Icon(Icons.broken_image, size: 50),
                                ),
                              )
                            : Container(
                                height: 180,
                                width: double.infinity,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, size: 50),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // LINK
                      Text(
                        ad['link'] ?? "No link",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // USER ID
                      Text(
                        "Uploaded by: ${ad['user_id'] ?? 'Unknown'}",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),

                      // DELETE BUTTON
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmAndDelete(ad['id']),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
