import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart'; // replace with your main page import

class SplashSlideshowPage extends StatefulWidget {
  const SplashSlideshowPage({super.key});

  @override
  State<SplashSlideshowPage> createState() => _SplashSlideshowPageState();
}

class _SplashSlideshowPageState extends State<SplashSlideshowPage> {
  @override
  void initState() {
    super.initState();

    // Wait 1 second then go to main screen
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 600),
          child: SizedBox(
            width: 120,
            height: 120,
            child: Image.network(
              "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif",
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
