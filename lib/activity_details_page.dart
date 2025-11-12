import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// 🎨 Reusable Theme
class AppColors {
  static const Color primary = Color(0xFF6A1B9A); // Deep Purple 800
  static const Color accent = Color(0xFFE5B03E); // Gold/Amber
  static const Color background = Color(0xFFF7F7F7);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF888888);
}

class ActivityDetailsPage extends StatefulWidget {
  final Map<String, dynamic> activity;
  const ActivityDetailsPage({super.key, required this.activity});

  @override
  State<ActivityDetailsPage> createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  final supabase = Supabase.instance.client;

  bool isBooking = false;
  int _numberOfPeople = 1;

  List<Map<String, dynamic>> reviews = [];
  int _userRating = 5;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _showAllReviews = false;
  final int _maxReviewsInitially = 3;

  double get averageRating {
    if (reviews.isEmpty) return 0.0;
    final totalRating =
        reviews.map((r) => (r['rating'] ?? 0) as int).reduce((a, b) => a + b);
    return totalRating / reviews.length;
  }

  @override
  void initState() {
    super.initState();
    fetchReviews();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  // ---------------- Fetch Reviews ----------------
  Future<void> fetchReviews() async {
    try {
      final response = await supabase
          .from('reviews_acts') // updated table
          .select('*, user:profiles(full_name, profile_image_url)')
          .eq('activity_id', widget.activity['id'])
          .order('created_at', ascending: false);

      if (response is List) {
        setState(() => reviews =
            List<Map<String, dynamic>>.from(response.map((r) => r as Map)));
      }
    } catch (e) {
      print("❌ Error fetching reviews: $e");
    }
  }

  // ---------------- Submit Review ----------------
  Future<void> submitReview() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar("⚠️ Please log in to submit a review", Colors.orange);
      return;
    }

    final comment = _reviewController.text.trim();
    if (comment.isEmpty) {
      _showSnackBar("⚠️ Please write a review comment", Colors.orange);
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      await supabase.from('reviews_acts').insert({
        // updated table
        'activity_id': widget.activity['id'],
        'user_id': user.id,
        'rating': _userRating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });

      _reviewController.clear();
      _userRating = 5;

      _showSnackBar("✅ Review submitted!", Colors.green);
      await fetchReviews();
    } catch (e) {
      print("❌ Error submitting review: $e");
      _showSnackBar("❌ Failed to submit review.", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  // ---------------- Booking Logic ----------------
  Future<void> createBooking() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar("⚠️ Please log in to book this activity", Colors.orange);
      return;
    }

    setState(() => isBooking = true);

    try {
      final activityPrice = widget.activity['price'] ?? 0;
      final totalPrice = activityPrice * _numberOfPeople;

      await supabase.from('bookings_acts').insert({
        'user_id': user.id,
        'activity_id': widget.activity['id'],
        'number_of_people': _numberOfPeople,
        'price': activityPrice,

        'status': 'pending', // optional
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSnackBar("✅ Activity booked successfully!", Colors.green);
    } catch (e) {
      print("❌ Error creating booking: $e");
      _showSnackBar("❌ Failed to book the activity.", Colors.red);
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------- Stars ----------------
  Widget buildStars(double rating,
      {double size = 20, Color color = AppColors.accent}) {
    int full = rating.floor();
    bool half = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return Icon(Icons.star_rounded, color: color, size: size);
        if (i == full && half)
          return Icon(Icons.star_half_rounded, color: color, size: size);
        return Icon(Icons.star_border_rounded, color: color, size: size);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final act = widget.activity;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(act['title'] ?? "Activity Details",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textDark)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageAndInfo(act),
              const SizedBox(height: 24),
              _buildActivityDetails(act),
              const SizedBox(height: 32),
              _buildBookingCard(),
              const SizedBox(height: 32),
              _buildReviewsSection(),
              const SizedBox(height: 24),
              _buildSubmitReviewSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Image and Main Info ----------------
  Widget _buildImageAndInfo(Map<String, dynamic> act) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (act['image_url'] != null && act['image_url'] != '')
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                act['image_url'],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: Center(
                      child: Icon(Icons.photo_size_select_actual_outlined,
                          size: 80, color: Colors.grey.shade400)),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(act['title'] ?? "Activity Title",
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 8),
        Row(
          children: [
            buildStars(averageRating, size: 24),
            const SizedBox(width: 10),
            Text(averageRating.toStringAsFixed(1),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textDark)),
            Text(" (${reviews.length} reviews)",
                style: const TextStyle(color: AppColors.textLight)),
          ],
        ),
        const SizedBox(height: 16),
        Text(act['description'] ?? 'No description available.',
            style: const TextStyle(
                fontSize: 16, color: AppColors.textLight, height: 1.5)),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------- Activity Details ----------------
  Widget _buildActivityDetails(Map<String, dynamic> act) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Key Activity Details",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              if (act['price'] != null)
                _buildDetailRow(
                  icon: Icons.attach_money_rounded,
                  label: "Price:",
                  value: "₹${act['price']}",
                  color: Colors.green.shade700,
                ),
              if (act['location'] != null)
                _buildDetailRow(
                  icon: Icons.location_on_rounded,
                  label: "Location:",
                  value: act['location'],
                  color: Colors.redAccent,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  // ---------------- Booking Section ----------------
  Widget _buildBookingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Secure Your Spot Now",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Number of Guests:",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.primary),
                    onPressed: () {
                      if (_numberOfPeople > 1) {
                        setState(() => _numberOfPeople--);
                      }
                    },
                  ),
                  Text(
                    '$_numberOfPeople',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.primary),
                    onPressed: () {
                      setState(() => _numberOfPeople++);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: isBooking ? null : () async => await createBooking(),
              icon: isBooking
                  ? const SizedBox.shrink()
                  : const Icon(Icons.luggage_outlined, color: AppColors.card),
              label: isBooking
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.card, strokeWidth: 2),
                      ),
                    )
                  : const Text("Confirm Booking",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.card)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Reviews Section ----------------
  Widget _buildReviewsSection() {
    final reviewsToShow =
        _showAllReviews || reviews.length <= _maxReviewsInitially
            ? reviews
            : reviews.take(_maxReviewsInitially).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Customer Reviews",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 16),
        if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                "No reviews yet. Be the first to share your experience! 📝",
                style: TextStyle(color: AppColors.textLight)),
          )
        else
          ...reviewsToShow.map((r) {
            final user = r['user'] ?? {};
            final fullName = user['full_name'] ?? 'Anonymous';
            final profileUrl = user['profile_image_url'];
            final createdAt = r['created_at'] != null
                ? DateFormat.yMMMd()
                    .format(DateTime.parse(r['created_at']).toLocal())
                : '';
            return _buildReviewItem(r, fullName, profileUrl, createdAt);
          }).toList(),
        if (reviews.length > _maxReviewsInitially)
          Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _showAllReviews = !_showAllReviews),
              child: Text(
                _showAllReviews
                    ? 'Show Less (${reviews.length})'
                    : 'See All ${reviews.length - _maxReviewsInitially} More Reviews',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review, String name,
      String? profileUrl, String date) {
    final rating = (review['rating'] ?? 0).toDouble();
    final comment = review['comment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                    ? NetworkImage(profileUrl)
                    : null,
                child: (profileUrl == null || profileUrl.isEmpty)
                    ? const Icon(Icons.person_rounded, color: AppColors.card)
                    : null,
                backgroundColor: AppColors.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text(date,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
              buildStars(rating, size: 18, color: AppColors.accent),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 8),
            child: Divider(height: 1),
          ),
          Text(comment,
              style: const TextStyle(fontSize: 15, color: AppColors.textDark)),
        ],
      ),
    );
  }

  // ---------------- Submit Review ----------------
  Widget _buildSubmitReviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textLight.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Share Your Experience ✨",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Rate this activity",
            style: TextStyle(fontSize: 16, color: AppColors.textLight),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return IconButton(
                icon: Icon(
                  _userRating >= starValue
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _userRating = starValue;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            maxLines: 4,
            style: const TextStyle(fontSize: 16, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: "Write your review here...",
              hintStyle:
                  const TextStyle(color: AppColors.textLight, fontSize: 15),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.textLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.textLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isSubmittingReview ? null : submitReview,
              icon: _isSubmittingReview
                  ? const SizedBox.shrink()
                  : const Icon(Icons.send_rounded, color: AppColors.card),
              label: _isSubmittingReview
                  ? const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.card,
                        ),
                      ),
                    )
                  : const Text(
                      "Submit Review",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.card,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
