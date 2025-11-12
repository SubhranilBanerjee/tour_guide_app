import 'package:flutter/material.dart';
import 'destination_page.dart';

class SumatraPage extends StatelessWidget {
  const SumatraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DestinationPage(
      title: 'Sumatra Exploration',
      image: 'assets/Sumatra.jpg',
      location: 'Sumatra, Indonesia',
      description:
          'Explore jungles, volcanoes, and wildlife in the exotic island of Sumatra.',
    );
  }
}
