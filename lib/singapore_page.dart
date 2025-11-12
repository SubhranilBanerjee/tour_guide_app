import 'package:flutter/material.dart';
import 'destination_page.dart';

class SingaporePage extends StatelessWidget {
  const SingaporePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DestinationPage(
      title: 'Singapore Highlights',
      image: 'assets/Singapore.jpg',
      location: 'Singapore',
      description:
          'See Marina Bay Sands, Gardens by the Bay, Sentosa Island, and city attractions.',
    );
  }
}
