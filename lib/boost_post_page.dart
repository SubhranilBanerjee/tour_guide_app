// boost_post_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoostPostPage extends StatefulWidget {
  final String userId;
  const BoostPostPage({super.key, required this.userId});

  @override
  State<BoostPostPage> createState() => _BoostPostPageState();
}

class _BoostPostPageState extends State<BoostPostPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isProcessing = false;
  String? errorMessage;

  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> activities = [];

  @override
  void initState() {
    super.initState();
    _fetchUserItems();
  }

  Future<void> _fetchUserItems() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final pResp = await supabase
          .from('posts')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      final aResp = await supabase
          .from('activities')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      setState(() {
        posts = (pResp is List) ? List<Map<String, dynamic>>.from(pResp) : [];
        activities =
            (aResp is List) ? List<Map<String, dynamic>>.from(aResp) : [];
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching items: $e');
      setState(() {
        errorMessage = 'Failed to load items.';
        isLoading = false;
      });
    }
  }

  Future<void> _openPlanSheet({
    required String table,
    required String itemId,
    required String title,
    required String? imageUrl,
  }) async {
    int selectedDays = 3;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          Widget planTile(int days, String label, bool popular) {
            final selected = selectedDays == days;
            return GestureDetector(
              onTap: () => setModalState(() => selectedDays = days),
              child: Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF1A1511), Color(0xFF0A0A0A)])
                      : const LinearGradient(
                          colors: [Color(0xFF0F0F0F), Color(0xFF111111)]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected
                          ? const Color(0xFFFFD700)
                          : Colors.grey.shade800,
                      width: selected ? 2 : 1),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (popular)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('MOST POPULAR',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                        ),
                      if (popular) const SizedBox(height: 8),
                      Text(label,
                          style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('$days day${days > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white70)),
                    ]),
              ),
            );
          }

          return Container(
            padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 18),
            decoration: const BoxDecoration(
                color: Color(0xFF0B0B0B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(imageUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: Colors.grey.shade900))
                          : Container(
                              width: 72,
                              height: 72,
                              color: Colors.grey.shade900,
                              child: const Icon(Icons.image_not_supported,
                                  color: Colors.white70)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        planTile(1, 'Quick', false),
                        planTile(3, 'Balanced', true),
                        planTile(7, 'Max', false),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                      child: Text('What you get',
                          style: TextStyle(color: Colors.grey.shade300))),
                  const SizedBox(height: 8),
                  const Text(
                      '• Increased visibility\n• Highlighted placement\n• More impressions',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: isProcessing
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              await _applyBoost(
                                  table: table,
                                  itemId: itemId,
                                  days: selectedDays);
                            },
                      child: Text(
                          isProcessing
                              ? 'Applying...'
                              : 'Confirm — $selectedDays day${selectedDays > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade700)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ]),
          );
        });
      },
    );
  }

  Future<void> _applyBoost(
      {required String table,
      required String itemId,
      required int days}) async {
    setState(() => isProcessing = true);

    final now = DateTime.now().toUtc();
    final end = now.add(Duration(days: days));

    try {
      await supabase.from(table).update({
        'is_boosted': true,
        'boost_start': now.toIso8601String(),
        'boost_end': end.toIso8601String(),
      }).eq('id', itemId);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ Boost applied')));
      Navigator.of(context).pop(true); // return true to caller
    } catch (e) {
      debugPrint('Boost error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to apply boost: $e')));
      setState(() => isProcessing = false);
    }
  }

  Widget _listItemCard(Map<String, dynamic> data, String table) {
    final title = (data['title'] ?? data['name'] ?? 'Untitled').toString();
    final imageUrl = (data['image_url'] ?? '').toString();
    final isBoosted = data['is_boosted'] == true;
    final boostEnd = data['boost_end'] != null
        ? data['boost_end'].toString().substring(0, 10)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB8860B).withOpacity(0.8)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: (imageUrl.isNotEmpty)
              ? Image.network(imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 72, height: 72, color: Colors.grey.shade900))
              : Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey.shade900,
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.white70)),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        subtitle: isBoosted
            ? Text('Boosted until $boostEnd',
                style: const TextStyle(color: Colors.white70))
            : null,
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor:
                  isBoosted ? Colors.grey : const Color(0xFFFFD700)),
          onPressed: isBoosted
              ? null
              : () {
                  _openPlanSheet(
                      table: table,
                      itemId: data['id'].toString(),
                      title: title,
                      imageUrl: imageUrl.isNotEmpty ? imageUrl : null);
                },
          child: Text(isBoosted ? 'Boosted' : 'Boost',
              style: TextStyle(
                  color: isBoosted ? Colors.white70 : Colors.black,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Boost Content',
            style: TextStyle(
                color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: RefreshIndicator(
                  onRefresh: _fetchUserItems,
                  child: ListView(
                    children: [
                      // header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0B0B0B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    const Color(0xFFB8860B).withOpacity(0.6))),
                        child: Row(
                          children: [
                            const Icon(Icons.campaign,
                                color: Color(0xFFFFD700)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text('Boost your posts & activities',
                                    style: TextStyle(
                                        color: Colors.grey.shade300))),
                            Text('${posts.length + activities.length}',
                                style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Posts section
                      const Text('Your Posts',
                          style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (posts.isEmpty)
                        Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: const Text('No posts yet',
                                style: TextStyle(color: Colors.white70)))
                      else
                        ...posts.map((p) => _listItemCard(p, 'posts')).toList(),

                      const SizedBox(height: 18),
                      const Text('Your Activities',
                          style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (activities.isEmpty)
                        Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: const Text('No activities yet',
                                style: TextStyle(color: Colors.white70)))
                      else
                        ...activities
                            .map((a) => _listItemCard(a, 'activities'))
                            .toList(),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
