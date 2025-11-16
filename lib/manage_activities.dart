import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageActivitiesPage extends StatefulWidget {
  const ManageActivitiesPage({super.key});

  @override
  State<ManageActivitiesPage> createState() => _ManageActivitiesPageState();
}

class _ManageActivitiesPageState extends State<ManageActivitiesPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = _loadActivities();
  }

  Future<List<Map<String, dynamic>>> _loadActivities() async {
    final activities = await supabase
        .from('activities')
        .select('id, title, description, image_url, created_at, user_id');

    final users = await supabase.from('profiles').select('id, full_name');
    final userMap = {for (var u in users) u['id']: u['full_name'] ?? 'Unknown'};

    String formatDate(dynamic date) {
      if (date == null) return "N/A";
      try {
        return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
      } catch (_) {
        return date.toString();
      }
    }

    return activities.map<Map<String, dynamic>>((act) {
      return {
        'id': act['id'],
        'title': act['title'] ?? 'Untitled',
        'description': act['description'] ?? '',
        'image_url': act['image_url'],
        'created_at': formatDate(act['created_at']),
        'user_name': userMap[act['user_id']] ?? 'Unknown',
      };
    }).toList();
  }

  Future<void> _deleteActivity(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete Activity"),
        content: const Text("Are you sure you want to delete this activity?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text("Delete"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('activities').delete().eq('id', id);
        setState(() => _activitiesFuture = _loadActivities());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Activity deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting activity: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      /*
      appBar: AppBar(
        title: const Text(
          "Manage Activities",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ), 

           
        ),
        

        backgroundColor: const Color(0xFF1565C0),
        elevation: 2,
      ),
      */
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _activitiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
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

          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return const Center(
              child: Text(
                "No activities found.",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          // ✅ Beautiful card-based display
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final act = activities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 5,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: act['image_url'] != null
                            ? Image.network(
                                act['image_url'],
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.image_not_supported,
                                      color: Colors.grey),
                                ),
                              )
                            : Container(
                                width: 90,
                                height: 90,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_outlined,
                                    color: Colors.grey),
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act['title'],
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              act['description'].isNotEmpty
                                  ? act['description']
                                  : "No description provided.",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "👤 ${act['user_name']}",
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "📅 ${act['created_at']}",
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.redAccent, size: 26),
                        tooltip: "Delete Activity",
                        onPressed: () => _deleteActivity(act['id']),
                      ),
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
