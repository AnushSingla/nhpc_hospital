import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class ReportErrorScreen extends StatefulWidget {
  const ReportErrorScreen({super.key});

  @override
  State<ReportErrorScreen> createState() => _ReportErrorScreenState();
}

class _ReportErrorScreenState extends State<ReportErrorScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Give Feedback'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Give your feedback here:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Enter details here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final feedback = _controller.text.trim();
                if (feedback.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your feedback.'),
                    ),
                  );
                  return;
                }

                try {
                  final Uri emailUri = Uri(
                    scheme: 'mailto' ,
                    path: 'beastanush007@gmail.com',
                     query: 'subject=App Feedback&body=${Uri.encodeComponent(feedback)}',
                  );
                  await launchUrl(emailUri);
                    
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email app opened.'),
                     ),
                    );

                 Navigator.pop(context);
                  
                  
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReportErrorFAB extends StatelessWidget {
  final VoidCallback onPressed;
  const ReportErrorFAB({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.chat, color: Colors.black),
      label: const Text('Give Feedback', style: TextStyle(color: Colors.black)),
      backgroundColor: const Color.fromARGB(255, 37, 218, 234),
      heroTag: 'report_error_fab',
    );
  }
}
