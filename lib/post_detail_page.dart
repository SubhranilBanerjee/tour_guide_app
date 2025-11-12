import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostDetailsPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailsPage({super.key, required this.post});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final supabase = Supabase.instance.client;
  bool isBooking = false;

  Future<void> createBooking() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please log in to book this tour")),
      );
      return;
    }

    setState(() => isBooking = true);

    try {
      await supabase.from('bookings').insert({
        'user_id': user.id,
        'post_id': widget.post['id'],
        'created_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Tour booked successfully!")),
      );
    } catch (e) {
      print("❌ Error creating booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to book the tour.")),
      );
    } finally {
      setState(() => isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    final fromDate =
        post['from_date'] != null ? DateTime.tryParse(post['from_date']) : null;
    final toDate =
        post['to_date'] != null ? DateTime.tryParse(post['to_date']) : null;

    return Scaffold(
      body: Stack(
        children: [
          // 🖼️ Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/login.jpg"), // 🔹 background image
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🔹 Semi-transparent overlay
          Container(color: Colors.black.withOpacity(0.1)),

          // 🔹 Foreground content (card style)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🏞️ Tour image
                    if (post['image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post['image_url'],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 📍 Title
                    Text(
                      post['title'] ?? "Untitled Tour",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff0905f1),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // 📅 Dates
                    if (fromDate != null && toDate != null)
                      Text(
                        "📆 ${fromDate.day}/${fromDate.month}/${fromDate.year} → ${toDate.day}/${toDate.month}/${toDate.year}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    const SizedBox(height: 10),

                    // 💰 Price
                    if (post['price'] != null)
                      Text(
                        "💰 ₹${post['price']}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 📝 Description
                    if (post['description'] != null)
                      Text(
                        post['description'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 30),

                    // 🟦 “Book Now” Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isBooking ? null : createBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff6200ee),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: isBooking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "Book Now",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔙 Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
