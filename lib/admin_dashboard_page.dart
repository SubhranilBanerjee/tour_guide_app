import 'dart:ui';
import 'package:flutter/material.dart';
import 'manage_posts.dart';
import 'manage_users.dart';
import 'manage_ads.dart';
import 'manage_activities.dart';
import 'analytics_page.dart';
import 'settings_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    ManagePostsPage(),
    ManageUsersPage(),
    ManageActivitiesPage(),
    ManageAdsPage(),
    AnalyticsPage(),
    SettingsPage(),
  ];

  final List<String> titles = [
    "Manage Posts",
    "Manage Users",
    "Manage Activities",
    "Manage Advertisements",
    "Analytics",
    "Settings"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: Text(
          "Admin Dashboard - ${titles[selectedIndex]}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 6,
        shadowColor: Colors.blueAccent.withOpacity(0.3),
      ),

      // ************* MAIN BODY *************
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Container(
          key: ValueKey<int>(selectedIndex),

          // FULL SCREEN WHITE CARD
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.12),
                blurRadius: 25,
                offset: const Offset(0, -4),
              ),
            ],
          ),

          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: pages[selectedIndex],
            ),
          ),
        ),
      ),

      // 🌊 Bottom Navigation Bar
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) => setState(() => selectedIndex = index),
            backgroundColor: Colors.white.withOpacity(0.9),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF1565C0),
            unselectedItemColor: Colors.grey.shade500,
            showUnselectedLabels: true,
            elevation: 10,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.post_add_outlined),
                label: "Posts",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_outlined),
                label: "Users",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_outlined),
                label: "Activities",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.campaign_outlined),
                label: "Ads",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                label: "Analytics",
              ),
              //BottomNavigationBarItem(
              //icon: Icon(Icons.settings_outlined),
              //label: "Settings",
              //),
            ],
          ),
        ),
      ),
    );
  }
}
