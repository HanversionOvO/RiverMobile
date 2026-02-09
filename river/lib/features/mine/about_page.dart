import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'River\n\n基于 Flutter 开发的社区客户端。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
