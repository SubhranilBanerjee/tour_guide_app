import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_slideshow_page.dart';

//import 'chat_page.dart';
import 'auth_gate.dart';
import 'home_page.dart';
import 'search_page.dart';
import 'favorites_page.dart';
import 'bookings_page.dart';
import 'profile_page.dart';
import 'posts_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ehhzpedqvwvqwaauubit.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoaHpwZWRxdnd2cXdhYXV1Yml0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc4MjU4ODIsImV4cCI6MjA3MzQwMTg4Mn0.QLQu3W4wy0Bc08GaXa8D6yhGa8heIZsaFbmKNRhQXhk',
  );

  runApp(const TourGuideApp());
}

class TourGuideApp extends StatelessWidget {
  const TourGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: const SplashSlideshowPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    SearchPage(),
    PostsPage(),
    FavoritesPage(),
    BookingsPage(),
    const ProfilePage(),
  ];

  void _onTabTapped(int index) async {
    // Profile tab check
    if (index == 5) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );

        final userAfter = Supabase.instance.client.auth.currentUser;
        if (userAfter != null && mounted) {
          setState(() => _currentIndex = 5);
        }
      } else {
        setState(() => _currentIndex = 5);
      }
      return;
    }

    // Chats tab → open separately instead of direct page

    // Regular navigation
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.0,
            colors: [
              Color(0xffffffff),
              Color(0xc8ffffff),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x42ffffff),
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: const Color(0xff8400fe),
          unselectedItemColor: const Color(0x6d00a3ff),
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Explore"),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore), label: "Activities"),
            BottomNavigationBarItem(icon: Icon(Icons.post_add), label: "Tours"),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border), label: "Favorites"),
            BottomNavigationBarItem(icon: Icon(Icons.book), label: "Bookings"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            //BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chats"),
          ],
        ),
      ),
    );
  }
}
