import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/menu_tile.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign in to unlock full services',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access personalized services, track your reports, and receive updates.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push('/signin'),
                        child: const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        MenuTile(
          icon: Icons.palette_outlined,
          title: 'Appearance',
          onTap: () => context.push('/appearance'),
        ),
        MenuTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          onTap: () => context.push('/notifications'),
        ),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        const Text('Legal', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        MenuTile(
          icon: Icons.gavel_outlined,
          title: 'Terms of Service',
          onTap: () => context.push('/terms'),
        ),
        MenuTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () => context.push('/privacy'),
        ),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        const Text('Support', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        MenuTile(
          icon: Icons.support_agent_outlined,
          title: 'Support',
          onTap: () => context.push('/support'),
        ),
        MenuTile(
          icon: Icons.info_outline,
          title: 'About Us',
          onTap: () => context.push('/about'),
        ),
      ],
    );
  }
}
