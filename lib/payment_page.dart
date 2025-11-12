import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentPage extends StatefulWidget {
  final String bookingId;
  final String bookingType; // 🎯 CHANGE 1: Add the new required field

  const PaymentPage({
    super.key,
    required this.bookingId,
    this.bookingType =
        'post', // 🎯 CHANGE 1: Set a default for safety (assuming 'post' is the default booking table)
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final supabase = Supabase.instance.client;
  late Razorpay _razorpay;

  Map<String, dynamic>? booking;
  Map<String, dynamic>? item; // Renamed 'post' to 'item' for generic use
  double basePrice = 0;
  bool isLoading = true;

  // Helper to determine the correct table and foreign key column
  String get _tableName =>
      widget.bookingType == 'post' ? 'bookings' : 'bookings_acts';
  String get _itemRelation =>
      widget.bookingType == 'post' ? 'posts' : 'activities';

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
    _fetchBooking();
  }

  // 🎯 CHANGE 2: Use dynamic table name and relation for fetching
  Future<void> _fetchBooking() async {
    try {
      final selectQuery = '*, $_itemRelation(*)';

      final data = await supabase
          .from(_tableName) // Use the correct table (bookings or bookings_acts)
          .select(selectQuery)
          .eq('id', widget.bookingId)
          .single();

      setState(() {
        booking = data;
        item = data[
            _itemRelation]; // Use the correct nested object (posts or activities)
        basePrice = double.tryParse(data['total_price'].toString()) ??
            double.tryParse(data['price'].toString()) ??
            0.0;

        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching booking from $_tableName: $e");
      // Handle the case where the booking might be in the other table or doesn't exist.
      // For a robust app, you might try the other table if the first one fails,
      // but for this fix, we rely on the passed bookingType.
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _openCheckout() async {
    if (booking == null) return;
    final int amount = (basePrice * 100).toInt();

    var options = {
      'key': 'rzp_live_RAf3WEmOlBr73S', // replace with your actual key
      'amount': amount,
      'name':
          widget.bookingType == 'post' ? 'Tour Booking' : 'Activity Booking',
      'description': item?['title'] ?? 'Booking Package', // Use 'item'
      'theme': {'color': '#0A73FF'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("⚠️ Error opening Razorpay: $e");
    }
  }

  // 🎯 CHANGE 3: Use dynamic table name for status update
  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Payment Successful: ${response.paymentId}")),
    );

    await supabase
        .from(_tableName) // Use the correct table name for the update
        .update({'status': 'paid'}).eq('id', widget.bookingId);

    if (mounted) Navigator.pop(context);
  }

  void _handleError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ Payment Failed: ${response.message}")),
    );
  }

  void _handleExternal(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("💳 Wallet: ${response.walletName}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (booking == null) {
      return const Scaffold(body: Center(child: Text("⚠️ No booking found.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("💰 Payment Details"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Use 'item' for image
            if (item?['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(item!['image_url'],
                    height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            // Use 'item' for title
            Text(item?['title'] ?? 'Booking Package',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Use 'item' for description
            Text(item?['description'] ?? 'No description'),
            const SizedBox(height: 16),
            Text("💰 Amount: ₹$basePrice",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _openCheckout,
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text("Proceed to Pay",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
