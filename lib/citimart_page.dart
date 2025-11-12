import 'package:flutter/material.dart';
import 'destination_page.dart';

class CitimartPage extends StatelessWidget {
  const CitimartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DestinationPage(
      title: 'Citimart Shopping Tour',
      image: 'assets/Citimart.jpg',
      location: 'Citimart, Global',
      description:
          'Enjoy a guided shopping tour, explore stores, and find exclusive deals at Citimart.',
    );
  }
}
