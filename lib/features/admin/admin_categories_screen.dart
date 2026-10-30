import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/text_input_dialog.dart';
import 'admin_data.dart';
import 'admin_widgets.dart';

/// Admins can add, rename and remove food categories. A category that still
/// has stalls cannot be removed.
class AdminCategoriesScreen extends StatefulWidget {
  final AdminSnapshot initialSnapshot;
  final AdminRepository repository;

  const AdminCategoriesScreen({
    super.key,
    required this.initialSnapshot,
    required this.repository,
  });

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  late AdminSnapshot snapshot = widget.initialSnapshot;

  bool busy = false;

  Future<void> _reload() async {
    final fresh = await widget.repository.load();

    if (!mounted) return;

    setState(() {
      snapshot = fresh;
    });
  }

  /// Runs a write, then reloads. Shows a message if it fails.
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => busy = true);

    try {
      await action();
      await _reload();

      if (mounted) showAppSnackBar(context, success);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Something went wrong. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _askName({
    required String title,
    required String actionLabel,
    String initial = '',
    String? ignore,
  }) {
    final existing = snapshot.categoryNames.values.toList();

    return showTextInputDialog(
      context,
      title: title,
      label: 'Category name',
      hint: 'e.g. Street Food',
      actionLabel: actionLabel,
      initialValue: initial,
      maxLength: 30,
      textCapitalization: TextCapitalization.words,
      validator: (text) => validateCategoryName(text, existing, ignore: ignore),
    );
  }

  Future<void> _add() async {
    final name = await _askName(title: 'New category', actionLabel: 'Add');

    if (name == null) return;

    await _run(() => widget.repository.addCategory(name), 'Category added.');
  }

  Future<void> _rename(MapEntry<String, String> category) async {
    final name = await _askName(
      title: 'Rename category',
      actionLabel: 'Save',
      initial: category.value,
      ignore: category.value,
    );

    if (name == null || name == category.value) return;

    await _run(
      () => widget.repository.renameCategory(category.key, name),
      'Category renamed.',
    );
  }

  Future<void> _delete(MapEntry<String, String> category) async {
    // Ask the database, not the cached list, so a stall added a moment ago
    // still blocks the delete.
    int count;

    try {
      count = await widget.repository.stallCountForCategory(category.key);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not check this category. Please try again.',
          isError: true,
        );
      }
      return;
    }

    if (!mounted) return;

    if (count > 0) {
      await _showCannotDelete(category.value, count);
      return;
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete "${category.value}"?',
      message: 'No stalls use this category. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) return;

    await _run(
      () => widget.repository.deleteCategory(category.key),
      'Category deleted.',
    );
  }

  Future<void> _showCannotDelete(String name, int count) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.block_rounded,
            size: 32,
            color: VendrgoColors.error,
          ),
          title: const Text('Cannot delete category'),
          content: Text(
            '"$name" is used by $count ${count == 1 ? 'stall' : 'stalls'}. '
            'Move ${count == 1 ? 'it' : 'them'} to another category first '
            '(Stalls tab, then Edit), then try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = snapshot.categories;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Food categories'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : _add,
        backgroundColor: VendrgoColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: categories.isEmpty
                ? const EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No categories yet',
                    message: 'Tap "Add category" to create the first one.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Text(
                          '${categories.length} '
                          '${categories.length == 1 ? 'category' : 'categories'}'
                          ' · a category with stalls cannot be deleted',
                          style: VendrgoText.caption,
                        );
                      }

                      final category = categories[index - 1];
                      final count = snapshot.stallCountForCategory(
                        category.key,
                      );

                      return AdminListCard(
                        title: category.value,
                        subtitle: count == 0
                            ? 'No stalls'
                            : '$count ${count == 1 ? 'stall' : 'stalls'}',
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: VendrgoColors.peach,
                            borderRadius: VendrgoRadius.mdAll,
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: VendrgoColors.primaryDark,
                          ),
                        ),
                        onTap: busy ? null : () => _rename(category),
                        trailing: PopupMenuButton<String>(
                          enabled: !busy,
                          onSelected: (value) {
                            if (value == 'rename') _rename(category);
                            if (value == 'delete') _delete(category);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
