import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Define a structure for combined data
class BookingDetails {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> userProfile;

  BookingDetails({required this.booking, required this.userProfile});
}

class MyPostDataPage extends StatefulWidget {
  final int postId;
  final String postTitle;

  const MyPostDataPage({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  @override
  State<MyPostDataPage> createState() => _MyPostDataPageState();
}

class _MyPostDataPageState extends State<MyPostDataPage> {
  final supabase = Supabase.instance.client;
  List<BookingDetails> bookingDetailsList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  // ✅ Fetch all bookings (paid + unpaid)
  Future<void> fetchBookings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1️⃣ Fetch all bookings for this post
      final bookingResponse = await supabase
          .from('bookings')
          .select('*, user_id')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (bookingResponse is! List) {
        throw Exception("Invalid response format for bookings.");
      }

      final rawBookings = List<Map<String, dynamic>>.from(bookingResponse);

      if (rawBookings.isEmpty) {
        setState(() {
          bookingDetailsList = [];
          isLoading = false;
        });
        return;
      }

      // 2️⃣ Extract unique user IDs
      final userIds = rawBookings
          .map((b) => b['user_id'])
          .whereType<String>()
          .toSet()
          .toList();

      // 3️⃣ Fetch related user profiles

      final profilesResponse = await supabase
          .from('profiles')
          .select('id, username')
          .inFilter('id', userIds);

      if (profilesResponse is! List) {
        throw Exception("Invalid response format for profiles.");
      }

      // 4️⃣ Create a lookup map for user profiles
      final profileMap = {
        for (var profile in profilesResponse)
          profile['id']: Map<String, dynamic>.from(profile)
      };

      // 5️⃣ Combine bookings and profiles
      final List<BookingDetails> combinedData = rawBookings.map((booking) {
        final userId = booking['user_id'] as String?;
        final profile = userId != null ? profileMap[userId] : null;
        return BookingDetails(
          booking: booking,
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
        print('PostgrestException: $e');
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load bookings: $e";
        print('General Exception fetching bookings: $e');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return '';
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
        title: Text("Bookings for ${widget.postTitle}"),
        backgroundColor: Colors.blueAccent,
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

    // ✅ Table display
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blueAccent.shade100),
          columns: const [
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('Post ID')),
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
            final createdAt = b['created_at'] != null
                ? DateFormat('MMM d, yyyy h:mm a')
                    .format(DateTime.parse(b['created_at']).toLocal())
                : '-';

            return DataRow(cells: [
              DataCell(Text(username)),
              DataCell(Text(b['post_id'].toString())),
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

    if (bookingDetailsList.isEmpty) {
      return const Center(child: Text("No bookings yet."));
    }

    // ✅ Display data in a table
    final allKeys =
        bookingDetailsList.expand((d) => d.booking.keys).toSet().toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blueAccent.shade100),
          columns: [
            const DataColumn(label: Text('Username')),
            ...allKeys.map((key) => DataColumn(label: Text(key))),
          ],
          rows: bookingDetailsList.map((details) {
            final booking = details.booking;
            final username = details.userProfile['username'] ?? 'Unknown';

            return DataRow(
              cells: [
                DataCell(Text(username)),
                ...allKeys.map((key) {
                  final value = booking[key];
                  if (value == null) return const DataCell(Text('-'));

                  if (key.contains('created_at') || key.contains('date')) {
                    try {
                      final date = DateTime.parse(value).toLocal();
                      return DataCell(
                          Text(DateFormat('MMM d, yyyy h:mm a').format(date)));
                    } catch (_) {
                      return DataCell(Text(value.toString()));
                    }
                  }

                  return DataCell(Text(value.toString()));
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );

    if (bookingDetailsList.isEmpty) {
      return const Center(child: Text("No bookings yet."));
    }

    // ✅ Display all bookings
    return ListView.builder(
      itemCount: bookingDetailsList.length,
      itemBuilder: (_, index) {
        final details = bookingDetailsList[index];
        final booking = details.booking;
        final user = details.userProfile;

        final createdAt = formatDate(booking['created_at']);
        final status = booking['status'] ?? 'unpaid';
        final numPeople = booking['num_people'] ?? 1;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              user['username'] ??
                  'Unknown User (ID: ${booking['user_id'] ?? 'N/A'})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Status: $status | Booked on: $createdAt\nPeople: $numPeople",
            ),
            leading: Icon(
              status == 'paid'
                  ? Icons.check_circle
                  : status == 'pending'
                      ? Icons.hourglass_bottom
                      : Icons.cancel,
              color: status == 'paid'
                  ? Colors.green
                  : status == 'pending'
                      ? Colors.orange
                      : Colors.grey,
            ),
          ),
        );
      },
    );
  }
}
