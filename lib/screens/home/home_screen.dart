/// Home Screen for Sourcely.
/// Displays the user's knowledge spaces with create functionality.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/spaces_provider.dart';
import '../../widgets/loading_shimmer.dart';
import '../auth/login_screen.dart';
import '../space/space_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpacesProvider>().loadSpaces();
    });
  }

  void _showCreateDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: SourcelyColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('New Knowledge Space'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Machine Learning Research',
          ),
          style: Theme.of(context).textTheme.bodyLarge,
          onSubmitted: (_) async {
            if (controller.text.trim().isNotEmpty) {
              Navigator.of(ctx).pop();
              final space = await context
                  .read<SpacesProvider>()
                  .createSpace(controller.text.trim());
              if (space != null && mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SpaceScreen(spaceId: space.id, spaceName: space.name),
                  ),
                );
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                final space = await context
                    .read<SpacesProvider>()
                    .createSpace(controller.text.trim());
                if (space != null && mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SpaceScreen(spaceId: space.id, spaceName: space.name),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GradientText(
                          'Sourcely',
                          gradient: SourcelyColors.primaryGradient,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your Knowledge Spaces',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // User menu
                  PopupMenuButton<String>(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: SourcelyColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SourcelyColors.glassBorder),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: SourcelyColors.textSecondary,
                      ),
                    ),
                    onSelected: (value) async {
                      if (value == 'logout') {
                        final navigator = Navigator.of(context);
                        await context.read<AuthProvider>().signOut();
                        if (mounted) {
                          navigator.pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'email',
                        enabled: false,
                        child: Text(
                          context.read<AuthProvider>().user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 18, color: SourcelyColors.error),
                            SizedBox(width: 8),
                            Text('Sign Out'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // Spaces list
            Expanded(
              child: Consumer<SpacesProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.spaces.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: LoadingShimmer(),
                    );
                  }

                  if (provider.spaces.isEmpty) {
                    return _EmptyState(onCreateTap: _showCreateDialog);
                  }

                  return RefreshIndicator(
                    onRefresh: () => provider.loadSpaces(),
                    color: SourcelyColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: provider.spaces.length,
                      itemBuilder: (context, index) {
                        final space = provider.spaces[index];
                        return _SpaceCard(
                          name: space.name,
                          sourceCount: space.sourceCount,
                          createdAt: space.createdAt,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SpaceScreen(
                                  spaceId: space.id,
                                  spaceName: space.name,
                                ),
                              ),
                            );
                          },
                          onDelete: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Knowledge Space?'),
                                content: Text(
                                  'This will permanently delete "${space.name}" and all its sources.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: SourcelyColors.error,
                                    ),
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              provider.deleteSpace(space.id);
                            }
                          },
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 100 * index),
                              duration: 400.ms,
                            )
                            .slideY(begin: 0.05, end: 0);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: SourcelyColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: SourcelyColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Space',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ).animate().scale(delay: 600.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

class _SpaceCard extends StatelessWidget {
  final String name;
  final int sourceCount;
  final String createdAt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SpaceCard({
    required this.name,
    required this.sourceCount,
    required this.createdAt,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: glassCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Space icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: SourcelyColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_special,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.description_outlined,
                              size: 13, color: SourcelyColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '$sourceCount source${sourceCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: SourcelyColors.textMuted, size: 20),
                  onPressed: onDelete,
                ),
                const Icon(
                  Icons.chevron_right,
                  color: SourcelyColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SourcelyColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.folder_open,
                size: 40,
                color: SourcelyColors.primaryLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Knowledge Spaces Yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first knowledge space to start\nuploading sources and chatting with your AI assistant.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: SourcelyColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Create Knowledge Space',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms),
      ),
    );
  }
}
