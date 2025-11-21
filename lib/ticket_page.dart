import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SendEmailPage.dart';
import 'bookings_page.dart';

class TicketPage extends StatelessWidget {
  final Map<String, dynamic> booking;

  const TicketPage({super.key, required this.booking});

  // --- Helper: Format Date ---
  String _formatDate(dynamic dateInput) {
    if (dateInput == null || dateInput.toString().isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateInput.toString());
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (e) {
      return dateInput.toString();
    }
  }

  // --- Helper: Ticket Detail Row ---
  Widget _buildTicketDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      color: valueColor ?? Colors.black,
                      fontWeight: valueWeight ?? FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper: Dotted Divider ---
  Widget _buildDottedDivider() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return const SizedBox(
                width: dashWidth,
                height: 1.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = booking['posts'] ?? {};

    final String title = post['title']?.toString() ?? 'Booking Ticket';
    final String description =
        post['description']?.toString() ?? 'No description provided.';
    final String location = post['location']?.toString() ?? 'N/A';

    // Safe type conversions
    final double paidAmount =
        double.tryParse(booking['price']?.toString() ?? '0') ?? 0.0;
    final int numberOfPeople =
        int.tryParse(booking['number_of_people']?.toString() ?? '1') ?? 1;

    // Dates
    final String bookingId = booking['id']?.toString() ?? 'N/A';
    final String bookedDate = _formatDate(booking['created_at']);
    final String fromDate = _formatDate(post['from_date']);
    final String toDate = _formatDate(post['to_date']);
    final String activityDates =
        (fromDate == toDate) ? fromDate : '$fromDate - $toDate';

    // Calculate total
    final double total = paidAmount * numberOfPeople;

    const primaryColor = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Header ---
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(30)),
                    gradient: LinearGradient(
                      colors: [primaryColor, Color(0xFF42A5F5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.airplane_ticket,
                            size: 70, color: Colors.white),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    blurRadius: 5.0,
                                    color: Colors.black.withOpacity(0.2)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    title: const Text('Booking Confirmation',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    centerTitle: true,
                  ),
                ),
              ],
            ),

            // --- Main Ticket Card ---
            Transform.translate(
              offset: const Offset(0, -50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ID: $bookingId',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor)),
                            Text('Booked On: $bookedDate',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                        _buildDottedDivider(),
                        _buildTicketDetailRow(
                            Icons.event, 'Activity Dates:', activityDates),
                        _buildTicketDetailRow(
                            Icons.location_on, 'Location:', location),
                        _buildTicketDetailRow(
                            Icons.group, 'People:', '$numberOfPeople'),
                        _buildDottedDivider(),
                        _buildTicketDetailRow(
                          Icons.payments,
                          'Price per Person:',
                          '₹${paidAmount.toStringAsFixed(2)}',
                        ),
                        _buildTicketDetailRow(
                          Icons.calculate,
                          'Total Paid:',
                          '₹${total.toStringAsFixed(2)}',
                          valueColor: Colors.green.shade700,
                          valueWeight: FontWeight.bold,
                        ),
                        const SizedBox(height: 20),

                        // --- Send Email Button ---
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SendEmailPage(booking: booking),
                              ),
                            );
                          },
                          icon: const Icon(Icons.celebration,
                              color: Color(0xffffda00)),
                          label: const Text(
                            "Ben Voyage",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 80, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Text('Tour Details:',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                        const SizedBox(height: 6),
                        Text(description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black54)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
