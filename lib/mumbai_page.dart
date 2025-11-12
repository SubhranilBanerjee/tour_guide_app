
import 'package:flutter/material.dart';
import 'destination_page.dart';

class MumbaiPage extends StatelessWidget {
  const MumbaiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DestinationPage(
      title: 'Mumbai City Tour',
      image: 'assets/Mumbai.jpg',
      location: 'Mumbai, India',
      description: 'Visit Gateway of India, Marine Drive, Bollywood spots, and local markets in Mumbai.',
    );
  }
}
