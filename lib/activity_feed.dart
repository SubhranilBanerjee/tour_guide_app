import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts for better typography
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For formatting the date nicely
import 'activity_details_page.dart'; // ✅ Make sure this file exists

class ActivitiesFeed extends StatefulWidget {
  const ActivitiesFeed({super.key});

  @override
  State<ActivitiesFeed> createState() => _ActivitiesFeedState();
}

class _ActivitiesFeedState extends State<ActivitiesFeed> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> activities = [];

  // Define a fresh, attractive color palette
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color darkText = Color(0xFF263238);
  static const Color lightText = Color(0xFF78909C);
  static const Color cardBackground = Colors.white;

  @override
  void initState() {
    super.initState();
    loadActivities();
  }

  Future<void> loadActivities() async {
    try {
      final data = await supabase
          .from('activities')
          .select()
          .order('created_at', ascending: false)
          .limit(10); // Limit to 10 for better feed performance

      setState(() {
        // Safe cast from dynamic List to List<Map<String, dynamic>>
        activities = (data as List).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      // In a real app, you'd log this error to a service like Sentry
      debugPrint("❌ Error loading activities: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Attraction Improvement: Card Redesign ---
  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final title = activity['title'] ?? "Untitled Activity";
    final description = activity['description'] ?? "No description available";
    final location = activity['location'] ?? "Unknown";
    // Ensure price is treated as a double/num for formatting
    final price = activity['price'] is num
        ? NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
            .format(activity['price'])
        : "Free";

    final createdAt = DateTime.tryParse(activity['created_at'] ?? '');
    final formattedDate =
        createdAt != null ? DateFormat.yMMMd().format(createdAt) : "Date N/A";

    return Container(
      width: 260, // Wider card for a more magazine-like look
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActivityDetailsPage(activity: activity),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📸 Image Section with Gradient Overlay
            if (activity['image_url'] != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      activity['image_url'],
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 140,
                          color: Colors.grey[200],
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: primaryBlue, strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        height: 140,
                        color: Colors.grey[300],
                        child: const Center(
                            child: Icon(Icons.image_not_supported,
                                size: 40, color: lightText)),
                      ),
                    ),
                  ),
                  // Price Tag Overlay
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentTeal.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        price,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // 📝 Content Section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: darkText,
                    ),
                  ),

                  // Location
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: primaryBlue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.roboto(
                                fontSize: 13,
                                color: lightText,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Description Snippet
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(color: lightText, fontSize: 13),
                  ),

                  const SizedBox(height: 12),

                  // Date and Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date
                      Flexible(
                        child: Text(
                          "Posted: $formattedDate",
                          style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: lightText,
                              fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // "Know More" Button (Styled as TextButton for space)
                      SizedBox(
                        height: 32,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                  color: primaryBlue, width: 1),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ActivityDetailsPage(activity: activity),
                              ),
                            );
                          },
                          child: Text(
                            "View Details",
                            style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          height: 50,
          width: 50,
          child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3),
        ),
      );
    }
    if (activities.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "No recent activities found! Time to post some adventures. 🚀",
            textAlign: TextAlign.center,
            style: TextStyle(color: lightText),
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: activities.length,
      padding: const EdgeInsets.symmetric(
          horizontal: 20), // Use 20 for consistency with home page padding
      itemBuilder: (context, index) {
        return _buildActivityCard(activities[index]);
      },
    );
  }
}
