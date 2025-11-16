import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;

  int totalUsers = 0;
  int totalActivities = 0;
  int totalPosts = 0;
  int boostedCount = 0;

  Map<String, int> categoryDistribution = {};
  Map<String, int> monthlyUserGrowth = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      // Get total counts
      final users = await supabase.from('profiles').select('id, created_at');
      final activities =
          await supabase.from('activities').select('id, category, is_boosted');
      final posts = await supabase.from('posts').select('id');

      // Quick stats
      totalUsers = users.length;
      totalActivities = activities.length;
      totalPosts = posts.length;
      boostedCount = activities.where((a) => a['is_boosted'] == true).length;

      // Category breakdown
      categoryDistribution = {};
      for (var act in activities) {
        final cat = (act['category'] ?? 'Unknown').toString();
        categoryDistribution[cat] = (categoryDistribution[cat] ?? 0) + 1;
      }

      // Monthly user growth (last 6 months)
      final now = DateTime.now();
      final formatter = DateFormat('MMM');
      monthlyUserGrowth = {
        for (int i = 5; i >= 0; i--)
          formatter.format(DateTime(now.year, now.month - i)): 0
      };

      for (var u in users) {
        try {
          final createdAt = DateTime.parse(u['created_at']);
          final label =
              formatter.format(DateTime(createdAt.year, createdAt.month));
          if (monthlyUserGrowth.containsKey(label)) {
            monthlyUserGrowth[label] = monthlyUserGrowth[label]! + 1;
          }
        } catch (_) {}
      }

      setState(() => loading = false);
    } catch (e) {
      debugPrint("Error fetching analytics: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F8FF),
        body:
            Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final summaryCards = [
      {
        'title': 'Total Users',
        'value': '$totalUsers',
        'icon': Icons.people,
        'color': Colors.blueAccent,
      },
      {
        'title': 'Total Activities',
        'value': '$totalActivities',
        'icon': Icons.map_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Total Posts',
        'value': '$totalPosts',
        'icon': Icons.post_add,
        'color': Colors.orange,
      },
      {
        'title': 'Boosted',
        'value': '$boostedCount',
        'icon': Icons.rocket_launch,
        'color': Colors.purple,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      /*
      appBar: AppBar(
        title: const Text(
          "Analytics Dashboard",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 2,
      ),
    */
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📊 Quick Stats
            GridView.builder(
              shrinkWrap: true,
              itemCount: summaryCards.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final card = summaryCards[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (card['color'] as Color).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor:
                            (card['color'] as Color).withOpacity(0.15),
                        child: Icon(card['icon'] as IconData,
                            color: card['color'] as Color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(card['value'] as String,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1))),
                          Text(card['title'] as String,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // 📈 Line Chart: User Growth
            const Text(
              "User Growth (Last 6 Months)",
              style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildLineChart(),

            const SizedBox(height: 24),

            // 🥧 Pie Chart: Category Breakdown
            const Text(
              "Activity Category Distribution",
              style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildPieChart(),
          ],
        ),
      ),
    );
  }

  // 📈 Line Chart Widget
  Widget _buildLineChart() {
    final months = monthlyUserGrowth.keys.toList();
    final values = monthlyUserGrowth.values.toList();

    return SizedBox(
      height: 250,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < months.length) {
                        return Text(months[value.toInt()],
                            style: const TextStyle(fontSize: 12));
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (int i = 0; i < values.length; i++)
                      FlSpot(i.toDouble(), values[i].toDouble())
                  ],
                  isCurved: true,
                  gradient:
                      const LinearGradient(colors: [Colors.blue, Colors.cyan]),
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.3),
                        Colors.transparent
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🥧 Pie Chart Widget
  Widget _buildPieChart() {
    if (categoryDistribution.isEmpty) {
      return const Center(
        child: Text(
          "No category data found.",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.cyan,
    ];

    return SizedBox(
      height: 250,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 40,
            sections: [
              for (int i = 0; i < categoryDistribution.length; i++)
                PieChartSectionData(
                  color: colors[i % colors.length],
                  value: categoryDistribution.values.elementAt(i).toDouble(),
                  title:
                      "${categoryDistribution.keys.elementAt(i)}\n${categoryDistribution.values.elementAt(i)}",
                  radius: 70,
                  titleStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
