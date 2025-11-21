import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsGraphPage extends StatefulWidget {
  final int id; // post or activity id
  final String type; // "post" or "activity"

  const AnalyticsGraphPage({super.key, required this.id, required this.type});

  @override
  State<AnalyticsGraphPage> createState() => _AnalyticsGraphPageState();
}

class _AnalyticsGraphPageState extends State<AnalyticsGraphPage> {
  final supabase = Supabase.instance.client;

  int totalBookings = 0;
  int paidBookings = 0;
  int pendingBookings = 0;
  int cancelledBookings = 0;
  int favourites = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    final columnName = widget.type == "post" ? "post_id" : "activity_id";

    final bookingData = await supabase
        .from('bookings')
        .select('status')
        .eq(columnName, widget.id);

    final favData = await supabase
        .from('favorites')
        .select('id')
        .eq('item_type', widget.type)
        .eq('item_id', widget.id);

    int t = bookingData.length;
    int paid = 0;
    int pending = 0;
    int cancelled = 0;

    for (final b in bookingData) {
      final status = b['status'];
      if (status == 'paid')
        paid++;
      else if (status == 'pending')
        pending++;
      else if (status == 'cancelled') cancelled++;
    }

    setState(() {
      totalBookings = t;
      paidBookings = paid;
      pendingBookings = pending;
      cancelledBookings = cancelled;
      favourites = favData.length;
      loading = false;
    });
  }

  Widget statCard(String title, int value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                Text(
                  value.toString(),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.type == "post" ? "Post Analytics" : "Activity Analytics"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  statCard("Total Bookings", totalBookings,
                      Icons.event_available, Colors.blue),
                  statCard("Paid Bookings", paidBookings, Icons.check_circle,
                      Colors.green),
                  statCard("Pending Payments", pendingBookings,
                      Icons.hourglass_bottom, Colors.orange),
                  statCard("Cancellations", cancelledBookings, Icons.cancel,
                      Colors.red),
                  statCard(
                      "Favourites", favourites, Icons.favorite, Colors.pink),
                ],
              ),
            ),
    );
  }
}
