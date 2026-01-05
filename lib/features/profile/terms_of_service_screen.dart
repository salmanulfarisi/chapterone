import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Acceptance of Terms',
              'By accessing and using ChapterOne, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
            ),
            _buildSection(
              context,
              '2. Use License',
              'Permission is granted to temporarily download one copy of ChapterOne for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title, and under this license you may not:\n\n• Modify or copy the materials\n• Use the materials for any commercial purpose or for any public display\n• Attempt to decompile or reverse engineer any software\n• Remove any copyright or other proprietary notations from the materials',
            ),
            _buildSection(
              context,
              '3. User Account',
              'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account. You must notify us immediately of any unauthorized use of your account.',
            ),
            _buildSection(
              context,
              '4. Content Usage',
              'ChapterOne provides access to manga and comic content. You agree to use this content only for personal, non-commercial purposes. You may not:\n\n• Reproduce, distribute, or transmit any content without permission\n• Use automated systems to access or download content\n• Share your account credentials with others',
            ),
            _buildSection(
              context,
              '5. Intellectual Property',
              'All content, features, and functionality of ChapterOne, including but not limited to text, graphics, logos, and software, are the property of ChapterOne or its content suppliers and are protected by international copyright, trademark, and other intellectual property laws.',
            ),
            _buildSection(
              context,
              '6. Prohibited Uses',
              'You may not use ChapterOne:\n\n• In any way that violates any applicable law or regulation\n• To transmit any malicious code or viruses\n• To impersonate or attempt to impersonate the company\n• In any way that infringes upon the rights of others',
            ),
            _buildSection(
              context,
              '7. Disclaimer',
              'The materials on ChapterOne are provided on an "as is" basis. ChapterOne makes no warranties, expressed or implied, and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights.',
            ),
            _buildSection(
              context,
              '8. Limitations',
              'In no event shall ChapterOne or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the materials on ChapterOne, even if ChapterOne or an authorized representative has been notified orally or in writing of the possibility of such damage.',
            ),
            _buildSection(
              context,
              '9. Revisions',
              'ChapterOne may revise these terms of service at any time without notice. By using this service, you are agreeing to be bound by the then current version of these terms of service.',
            ),
            _buildSection(
              context,
              '10. Contact Information',
              'If you have any questions about these Terms of Service, please contact us through the app or our support channels.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

