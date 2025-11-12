import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'payment_page.dart';
import 'ticket_page.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> filteredBookings = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  Set<String> expandedCards = {};

  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  Future<void> loadBookings() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }

    try {
      final bookingsResp = await supabase.from('bookings').select('''
        id,
        post_id,
        user_id,
        status,
        price,
        number_of_people,
        total_price,
        created_at,
        posts (
          id,
          title,
          description,
          image_url,
          price
        )
      ''').eq('user_id', user.id);

      final actsResp = await supabase.from('bookings_acts').select('''
        id,
        activity_id,
        user_id,
        status,
        price,
        number_of_people,
        total_price,
        created_at,
        activities!bookings_acts_activity_id_fkey (
          id,
          title,
          description,
          image_url,
          price
        )
      ''').eq('user_id', user.id);

      final bookingsList = List<Map<String, dynamic>>.from(bookingsResp)
          .map((b) => {...b, 'type': 'post', 'item': b['posts']})
          .toList();
      final actsList = List<Map<String, dynamic>>.from(actsResp)
          .map((b) => {...b, 'type': 'activity', 'item': b['activities']})
          .toList();

      final combined = [...bookingsList, ...actsList];

      // Sort bookings by status
      combined.sort((a, b) {
        final aStatus = (a['status'] ?? '').toString().toLowerCase();
        final bStatus = (b['status'] ?? '').toString().toLowerCase();
        return aStatus.compareTo(bStatus);
      });

      if (!mounted) return;
      setState(() {
        bookings = combined;
        filteredBookings = combined;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading bookings: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load bookings: $e")),
      );
      setState(() => isLoading = false);
    }
  }

  void filterByStatus(String status) {
    setState(() {
      selectedFilter = status;

      if (status == 'All') {
        filteredBookings = [...bookings];
        // sort newest first
        filteredBookings.sort((a, b) => DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at'])));
      } else {
        filteredBookings = bookings
            .where((b) =>
                (b['status'] ?? '').toString().toLowerCase() ==
                status.toLowerCase())
            .toList();

        // also sort filtered ones by time
        filteredBookings.sort((a, b) => DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at'])));
      }
    });
  }

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> cancelBooking(String id, String type) async {
    try {
      final tableName = type == 'post' ? 'bookings' : 'bookings_acts';
      await supabase.from(tableName).delete().eq('id', id);
      if (!mounted) return;
      setState(() {
        bookings.removeWhere((b) => b['id'].toString() == id);
        filteredBookings.removeWhere((b) => b['id'].toString() == id);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Booking cancelled")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to cancel")));
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final item = booking['item'] ?? {};
    final itemType = booking['type'] ?? 'post';
    final imageUrl = item['image_url'];
    final title = item['title'] ?? 'Untitled';
    final location = item['description'] ?? 'Unknown location';
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final total = booking['total_price'] ?? booking['price'] ?? 0;
    final id = booking['id'].toString();
    final isExpanded = expandedCards.contains(id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            expandedCards.remove(id);
          } else {
            expandedCards.add(id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl ?? '',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[200],
                      child: const Icon(Icons.photo, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text("Status: ${status.toUpperCase()}",
                            style: TextStyle(
                                fontSize: 13,
                                color: status == 'paid'
                                    ? Colors.green
                                    : Colors.orange)),
                      ]),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.black54,
                ),
              ],
            ),
            // Expanded details
            if (isExpanded) ...[
              const SizedBox(height: 10),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text("Booking ID: $id",
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
              Text("Total Price: ₹$total",
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
              Text("Date: ${_formatCreatedAt(booking['created_at'])}",
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (status == 'paid')
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  TicketPage(booking: booking)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff007BFF),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("View Ticket",
                          style: TextStyle(fontSize: 13)),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PaymentPage(
                                    bookingId: booking['id'].toString(),
                                    bookingType: itemType,
                                  )),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff007BFF),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Pay", style: TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        cancelBooking(booking['id'].toString(), itemType),
                    style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: Color(0xff007BFF), width: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Cancel Booking",
                        style:
                            TextStyle(fontSize: 13, color: Color(0xff007BFF))),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FBFF),
        elevation: 0,
        centerTitle: true,
        title: const Text('Bookings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadBookings,
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['Pending', 'Paid', 'All']
                        .map((status) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: selectedFilter == status,
                                selectedColor: const Color(0xff007BFF),
                                labelStyle: TextStyle(
                                  color: selectedFilter == status
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                                onSelected: (_) => filterByStatus(status),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (filteredBookings.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text("No bookings found",
                          style:
                              TextStyle(fontSize: 16, color: Colors.black54)),
                    ))
                  else
                    ...filteredBookings.map(_buildBookingCard),
                ],
              ),
            ),
    );
  }
}
