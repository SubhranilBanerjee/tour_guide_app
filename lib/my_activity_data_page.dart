import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Data model to combine booking + user profile
class ActivityBookingDetails {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> userProfile;

  ActivityBookingDetails({
    required this.booking,
    required this.userProfile,
  });
}

class MyActivityDataPage extends StatefulWidget {
  final String activityId;
  final String activityTitle;

  const MyActivityDataPage({
    super.key,
    required this.activityId,
    required this.activityTitle,
  });

  @override
  State<MyActivityDataPage> createState() => _MyActivityDataPageState();
}

class _MyActivityDataPageState extends State<MyActivityDataPage> {
  final supabase = Supabase.instance.client;

  List<ActivityBookingDetails> bookingDetailsList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch all bookings for the selected activity
      final bookingResponse = await supabase
          .from('bookings_acts')
          .select('*, user_id')
          .eq('activity_id', widget.activityId)
          .order('created_at', ascending: true);

      if (bookingResponse is! List) {
        throw Exception("Invalid response format for bookings_acts.");
      }

      final rawBookings = List<Map<String, dynamic>>.from(bookingResponse);

      if (rawBookings.isEmpty) {
        setState(() {
          bookingDetailsList = [];
          isLoading = false;
        });
        return;
      }

      // Collect unique user IDs
      final userIds = rawBookings
          .map((b) => b['user_id'])
          .whereType<String>()
          .toSet()
          .toList();

      // Fetch related profiles
      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username')
          .inFilter('id', userIds);

      if (profilesResponse is! List) {
        throw Exception("Invalid response format for profiles.");
      }

      // Map user IDs → profile data
      final profileMap = {
        for (var profile in profilesResponse)
          profile['id']: Map<String, dynamic>.from(profile)
      };

      // Combine booking + profile
      final combinedData = rawBookings.map((b) {
        final userId = b['user_id'] as String?;
        final profile = userId != null ? profileMap[userId] : null;
        return ActivityBookingDetails(
          booking: b,
          userProfile: profile ?? {},
        );
      }).toList();

      setState(() {
        bookingDetailsList = combinedData;
      });
    } on PostgrestException catch (e) {
      setState(() {
        errorMessage =
            "Database error: ${e.message}. Check 'user_id' and 'profiles' relationship.";
        print("PostgrestException: $e");
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load bookings: $e";
        print("General Exception: $e");
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat.yMMMd().add_jm().format(date);
    } catch (_) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bookings for ${widget.activityTitle}"),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: fetchBookings,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (bookingDetailsList.isEmpty) {
      return const Center(child: Text("No bookings yet."));
    }

    // Scrollable DataTable to display bookings
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(Colors.deepPurpleAccent.shade100),
          columns: const [
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('Activity ID')),
            DataColumn(label: Text('User ID')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Number of People')),
            DataColumn(label: Text('Total Price')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Created At')),
          ],
          rows: bookingDetailsList.map((details) {
            final b = details.booking;
            final username = details.userProfile['username'] ?? 'Unknown';
            final price = (b['price'] ?? 0).toDouble();
            final numPeople = (b['number_of_people'] ?? 1).toInt();
            final totalPrice = price * numPeople;
            final createdAt = formatDate(b['created_at']);

            return DataRow(cells: [
              DataCell(Text(username)),
              DataCell(Text(b['activity_id'].toString())),
              DataCell(Text(b['user_id'].toString())),
              DataCell(Text("₹${price.toStringAsFixed(2)}")),
              DataCell(Text(numPeople.toString())),
              DataCell(Text("₹${totalPrice.toStringAsFixed(2)}")),
              DataCell(Text(b['status'] ?? 'N/A')),
              DataCell(Text(createdAt)),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
