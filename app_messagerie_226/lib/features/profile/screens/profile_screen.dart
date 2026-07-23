import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final uid = user?.uid ?? '';
    final profileAsync = uid.isNotEmpty ? ref.watch(userProfileProvider(uid)) : null;
    final profile = profileAsync?.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                    ? NetworkImage(user.photoURL!)
                    : null,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                    ? const Icon(Icons.person, size: 48, color: AppTheme.primary)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                profile != null
                    ? '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim()
                    : user?.displayName ?? '',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              if (profile != null) ...[
                const SizedBox(height: 8),
                Chip(
                  label: Text(profile['accountStatus'] ?? ''),
                  backgroundColor: profile['accountStatus'] == 'active'
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
