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

Future<void> showPersonActionBottomSheet(BuildContext context, DriftPerson person) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (_) => _PersonActionBottomSheet(person: person),
  );
}

class _PersonActionBottomSheet extends ConsumerWidget {
  final DriftPerson person;

  const _PersonActionBottomSheet({required this.person});

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
                CircleAvatar(
                  radius: 28,
                  backgroundImage: RemoteImageProvider(url: getFaceThumbnailUrl(person.id)),
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
              await showNameEditModal(context, person);
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
