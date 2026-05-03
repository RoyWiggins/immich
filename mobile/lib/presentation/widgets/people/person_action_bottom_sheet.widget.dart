import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/utils/debug_print.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

Future<void> showPersonActionBottomSheet(
  BuildContext context,
  DriftPerson person, {
  void Function(String)? onNameChanged,
  void Function(DateTime)? onBirthdayChanged,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (_) => _PersonActionBottomSheet(
      person: person,
      onNameChanged: onNameChanged,
      onBirthdayChanged: onBirthdayChanged,
    ),
  );
}

class _PersonActionBottomSheet extends ConsumerWidget {
  final DriftPerson person;
  final void Function(String)? onNameChanged;
  final void Function(DateTime)? onBirthdayChanged;

  const _PersonActionBottomSheet({
    required this.person,
    this.onNameChanged,
    this.onBirthdayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        ref.invalidate(driftGetAllPeopleProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        dPrint(() => 'Person action error: $e');
        if (!context.mounted) return;
        ImmichToast.show(
          context: context,
          msg: 'scaffold_body_error_occurred'.t(context: context),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.error,
        );
      }
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // person header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Material(
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image(
                      image: RemoteImageProvider(url: getFaceThumbnailUrl(person.id)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    person.name.isEmpty ? 'add_a_name'.tr() : person.name,
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text('edit_name'.tr()),
            onTap: () async {
              context.pop();
              final newName = await showNameEditModal(context, person);
              if (newName != null && newName.isNotEmpty) {
                onNameChanged?.call(newName);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: Text((person.birthDate != null ? 'edit_birthday' : 'add_birthday').tr()),
            onTap: () async {
              context.pop();
              final birthday = await showBirthdayEditModal(context, person);
              if (birthday != null) {
                onBirthdayChanged?.call(birthday);
              }
            },
          ),
          ListTile(
            leading: Icon(person.isFavorite ? Icons.star : Icons.star_border),
            title: Text(
              person.isFavorite ? 'person_remove_favorite'.tr() : 'person_add_favorite'.tr(),
            ),
            onTap: () => run(
              () => ref.read(driftPeopleServiceProvider).updateFavorite(person.id, !person.isFavorite),
            ),
          ),
          if (person.isHidden)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: Text('person_unhide'.tr()),
              onTap: () => run(
                () => ref.read(driftPeopleServiceProvider).updateHidden(person.id, hidden: false),
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text('person_hide'.tr()),
              onTap: () => run(
                () => ref.read(driftPeopleServiceProvider).updateHidden(person.id),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.merge),
            title: const Text('Combine people'),
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                builder: (_) => _CombinePeopleSheet(person: person),
              );
              ref.invalidate(driftGetAllPeopleProvider);
              if (context.mounted) context.pop();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CombinePeopleSheet extends ConsumerStatefulWidget {
  final DriftPerson person;

  const _CombinePeopleSheet({required this.person});

  @override
  ConsumerState<_CombinePeopleSheet> createState() => _CombinePeopleSheetState();
}

class _CombinePeopleSheetState extends ConsumerState<_CombinePeopleSheet> {
  final Set<String> _selected = {};
  bool _isCombining = false;

  String _resolveWinningName(List<DriftPerson> others) {
    for (final id in _selected) {
      final person = others.firstWhere((p) => p.id == id, orElse: () => widget.person);
      if (person.name.isNotEmpty) return person.name;
    }
    return widget.person.name;
  }

  Future<void> _combine(List<DriftPerson> others) async {
    if (_selected.isEmpty || _isCombining) return;
    setState(() => _isCombining = true);
    try {
      final winningName = _resolveWinningName(others);
      await ref.read(driftPeopleServiceProvider).mergePeople(
        widget.person.id,
        _selected.toList(),
        winningName: winningName.isEmpty ? null : winningName,
      );
      if (mounted) context.pop();
    } catch (e) {
      dPrint(() => 'Combine people error: $e');
      if (!mounted) return;
      ImmichToast.show(
        context: context,
        msg: 'scaffold_body_error_occurred'.t(context: context),
        gravity: ToastGravity.BOTTOM,
        toastType: ToastType.error,
      );
      setState(() => _isCombining = false);
    }
  }

  Widget _buildAvatar(DriftPerson person, {double size = 48}) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.375),
        ),
        clipBehavior: Clip.antiAlias,
        color: context.colorScheme.surfaceContainerHighest,
        child: Image(
          image: RemoteImageProvider(url: getFaceThumbnailUrl(person.id)),
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return Icon(Icons.person_rounded, size: size * 0.6);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPeopleAsync = ref.watch(driftGetAllPeopleProvider);
    final others = allPeopleAsync.valueOrNull
            ?.where((p) => p.id != widget.person.id && !p.isHidden)
            .toList() ??
        [];

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  _buildAvatar(widget.person, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Combine people',
                          style: context.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Select people to merge with '
                          '${widget.person.name.isEmpty ? "this person" : widget.person.name}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            // People list
            Expanded(
              child: allPeopleAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (_) => others.isEmpty
                    ? const Center(child: Text('No other people found'))
                    : ListView.builder(
                        itemCount: others.length,
                        itemBuilder: (context, index) {
                          final other = others[index];
                          final isSelected = _selected.contains(other.id);
                          return ListTile(
                            leading: Stack(
                              children: [
                                _buildAvatar(other),
                                if (isSelected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: context.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 12,
                                        color: context.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              other.name.isEmpty ? 'Unnamed person' : other.name,
                            ),
                            subtitle: other.isFavorite
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: context.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('Favorite'),
                                    ],
                                  )
                                : null,
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : context.colorScheme.outline,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selected.remove(other.id);
                                } else {
                                  _selected.add(other.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ),
            // Combine button
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: (_selected.isEmpty || _isCombining) ? null : () => _combine(others),
                child: _isCombining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _selected.isEmpty
                            ? 'Select people to combine'
                            : 'Combine with ${_selected.length} '
                                '${_selected.length == 1 ? "person" : "people"}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
