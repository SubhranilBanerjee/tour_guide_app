import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_activity_data_page.dart';

class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({super.key});

  @override
  State<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends State<MyActivitiesPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyActivities();
  }

  Future<void> fetchMyActivities() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('activities')
          .select()
          .eq('user_id', user.id) // only user’s activities
          .order('created_at', ascending: false);

      setState(() {
        activities = response as List<dynamic>;
      });
    } catch (e) {
      print("Error fetching activities: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎯 My Activities"),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activities.isEmpty
              ? const Center(
                  child: Text("You haven't created any activities yet."),
                )
              : ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (_, index) {
                    final activity = activities[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(activity['title'] ?? 'Untitled Activity'),
                        subtitle: Text(activity['description'] ?? ''),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyActivityDataPage(
                                activityId: activity['id'],
                                activityTitle: activity['title'] ?? '',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
