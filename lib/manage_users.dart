import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final supabase = Supabase.instance.client;
  late Future<List<dynamic>> _futureUsers;

  @override
  void initState() {
    super.initState();
    _futureUsers = fetchUsers();
  }

  Future<List<dynamic>> fetchUsers() async {
    final response = await supabase
        .from('profiles')
        .select('id, full_name, username, bio, profile_image_url, role');
    return response;
  }

  Future<void> deleteUser(String id) async {
    await supabase.from('profiles').delete().eq('id', id);

    setState(() {
      _futureUsers = fetchUsers();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User deleted")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Manage Users"),
        backgroundColor: Colors.blueAccent,
      ),
      */
      body: FutureBuilder(
        future: _futureUsers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blue));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Text("No users found",
                  style: TextStyle(color: Colors.black, fontSize: 18)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              return Card(
                elevation: 3,
                color: Colors.white,
                margin: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -----------------------------------
                      // HEADER → Profile Picture + Name
                      // -----------------------------------
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundImage:
                                user['profile_image_url'] != null &&
                                        user['profile_image_url'] != ""
                                    ? NetworkImage(user['profile_image_url'])
                                    : null,
                            child: (user['profile_image_url'] == null ||
                                    user['profile_image_url'] == "")
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              user['full_name'] ?? "",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteUser(user['id']),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // -----------------------------------
                      // Username
                      // -----------------------------------
                      Text(
                        "@${user['username'] ?? ''}",
                        style: const TextStyle(
                            fontSize: 15, color: Colors.blueAccent),
                      ),

                      const SizedBox(height: 6),

                      // -----------------------------------
                      // Bio
                      // -----------------------------------
                      Text(
                        user['bio'] ?? "",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                      ),

                      const SizedBox(height: 10),

                      // -----------------------------------
                      // Role
                      // -----------------------------------
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Role: ${user['role'] ?? 'user'}",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue),
                        ),
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
