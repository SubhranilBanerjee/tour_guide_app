import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class SendEmailPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const SendEmailPage({super.key, required this.booking});

  @override
  _SendEmailPageState createState() => _SendEmailPageState();
}

class _SendEmailPageState extends State<SendEmailPage> {
  final TextEditingController _recipientController = TextEditingController();
  String _status = '';

  void sendEmail() async {
    final String username = 'YOUR_EMAIL@gmail.com';
    final String password = 'YOUR_APP_PASSWORD'; // Not Gmail password

    final smtpServer = gmail(username, password);

    // Compose message
    final message = Message()
      ..from = Address(username, 'Your App Name')
      ..recipients.add(_recipientController.text)
      ..subject = 'Booking Confirmation'
      ..text = '''
Booking Details:
Activity ID: ${widget.booking['activity_id']}
Booking ID: ${widget.booking['id']}
User ID: ${widget.booking['user_id']}
Price: ${widget.booking['price']}
Created At: ${widget.booking['created_at']}
Post ID: ${widget.booking['post_id']}
Number of People: ${widget.booking['number_of_people']}
Total Price: ${widget.booking['total_price']}
Booking Type: ${widget.booking['booking_type']}
Status: ${widget.booking['status']}
''';

    try {
      final sendReport = await send(message, smtpServer);
      setState(() {
        _status = 'Email sent successfully: ' + sendReport.toString();
      });
    } on MailerException catch (e) {
      setState(() {
        _status = 'Email not sent. \n${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Booking Email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'Recipient Email',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendEmail,
              child: const Text('Send Email'),
            ),
            const SizedBox(height: 20),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
