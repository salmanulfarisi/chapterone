import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
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
              '1. Introduction',
              'ChapterOne ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
            ),
            _buildSection(
              context,
              '2. Information We Collect',
              'We may collect information about you in a variety of ways:\n\n• Personal Data: Email address, username, and password when you create an account\n• Reading Data: Your reading history, bookmarks, and preferences\n• Device Information: Device type, operating system, and unique device identifiers\n• Usage Data: Information about how you interact with the app, including features used and content accessed',
            ),
            _buildSection(
              context,
              '3. How We Use Your Information',
              'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Personalize your reading experience\n• Analyze usage patterns to improve app functionality\n• Detect and prevent fraud or abuse\n• Comply with legal obligations',
            ),
            _buildSection(
              context,
              '4. Data Storage and Security',
              'We implement appropriate technical and organizational security measures to protect your personal information. However, no method of transmission over the internet or electronic storage is 100% secure. While we strive to use commercially acceptable means to protect your data, we cannot guarantee absolute security.',
            ),
            _buildSection(
              context,
              '5. Data Sharing and Disclosure',
              'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:\n\n• With your explicit consent\n• To comply with legal obligations or court orders\n• To protect our rights, privacy, safety, or property\n• In connection with a business transfer or merger',
            ),
            _buildSection(
              context,
              '6. Third-Party Services',
              'Our app may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to read their privacy policies before providing any information.',
            ),
            _buildSection(
              context,
              '7. Cookies and Tracking Technologies',
              'We may use cookies and similar tracking technologies to track activity on our app and store certain information. You can instruct your device to refuse all cookies or to indicate when a cookie is being sent.',
            ),
            _buildSection(
              context,
              '8. Your Rights',
              'You have the right to:\n\n• Access and receive a copy of your personal data\n• Rectify inaccurate or incomplete data\n• Request deletion of your personal data\n• Object to processing of your personal data\n• Request restriction of processing\n• Data portability\n• Withdraw consent at any time',
            ),
            _buildSection(
              context,
              '9. Children\'s Privacy',
              'Our service is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately.',
            ),
            _buildSection(
              context,
              '10. Data Retention',
              'We will retain your personal information only for as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law.',
            ),
            _buildSection(
              context,
              '11. Changes to This Privacy Policy',
              'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.',
            ),
            _buildSection(
              context,
              '12. Contact Us',
              'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us through the app or our support channels.',
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

