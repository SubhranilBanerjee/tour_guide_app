import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ticket_page.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchUserTickets() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    // Fetch paid bookings from posts
    final postsResponse = await supabase
        .from('bookings')
        .select('*, posts(title, location)')
        .eq('user_id', user.id)
        .eq('status', 'paid')
        .order('created_at', ascending: false);

    // Fetch paid bookings from activities
    final actsResponse = await supabase
        .from('bookings_acts')
        .select(
            '*, activities!bookings_acts_activity_id_fkey(title, location)') // ✅ Explicit FK to avoid PGRST201
        .eq('user_id', user.id)
        .eq('status', 'paid')
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> postBookings =
        List<Map<String, dynamic>>.from(postsResponse);
    final List<Map<String, dynamic>> actBookings =
        List<Map<String, dynamic>>.from(actsResponse);

    // Tag the types
    for (var b in postBookings) b['type'] = 'post';
    for (var b in actBookings) b['type'] = 'activity';

    // Merge and sort by created_at descending
    final allBookings = [...postBookings, ...actBookings];
    allBookings.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    return allBookings;
  }

  @override
  Widget build(BuildContext context) {
    const magenta = Color(0xFFF800FF); // 💜 Neon magenta accent

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background
      appBar: AppBar(
        title: const Text(
          "My Tickets",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: magenta,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUserTickets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: magenta),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading tickets: ${snapshot.error}",
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final tickets = snapshot.data ?? [];

          if (tickets.isEmpty) {
            return const Center(
              child: Text(
                "No paid tickets found.",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            itemCount: tickets.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final type = ticket['type'];
              final isPost = type == 'post';

              final item =
                  isPost ? ticket['posts'] ?? {} : ticket['activities'] ?? {};
              final title = item['title'] ?? 'Unknown';
              final location = item['location'] ?? '';
              final date = ticket['created_at'] ?? '';
              final bookingId = ticket['id'].toString();

              return Card(
                color: const Color(0xFF1E1E1E), // Slightly lighter than bg
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: magenta, width: 0.8),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      if (location.isNotEmpty)
                        Text(
                          location,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Booking ID: $bookingId\nDate: $date",
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white60),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 18, color: magenta),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketPage(booking: ticket),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
