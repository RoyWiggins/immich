import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/presentation/widgets/people/person_action_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/person_sliver_app_bar.dart';

@RoutePage()
class DriftPersonPage extends ConsumerStatefulWidget {
  final DriftPerson person;

  const DriftPersonPage({super.key, required this.person});

  @override
  ConsumerState<DriftPersonPage> createState() => _DriftPersonPageState();
}

class _DriftPersonPageState extends ConsumerState<DriftPersonPage> {
  late DriftPerson _person;

  @override
  initState() {
    super.initState();
    _person = widget.person;
  }

  Future<void> handleEditName(BuildContext context) async {
    final newName = await showNameEditModal(context, _person);

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _person = _person.copyWith(name: newName);
      });
    }
  }

  Future<void> handleEditBirthday(BuildContext context) async {
    final birthday = await showBirthdayEditModal(context, _person);

    if (birthday != null) {
      setState(() {
        _person = _person.copyWith(birthDate: birthday);
      });
    }
  }

  void showOptionSheet(BuildContext context) {
    showPersonActionBottomSheet(
      context,
      _person,
      onNameChanged: (newName) {
        if (mounted) setState(() => _person = _person.copyWith(name: newName));
      },
      onBirthdayChanged: (birthday) {
        if (mounted) setState(() => _person = _person.copyWith(birthDate: birthday));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        timelineServiceProvider.overrideWith((ref) {
          final user = ref.watch(currentUserProvider);
          if (user == null) {
            throw Exception('User must be logged in to view person timeline');
          }

          final timelineService = ref.watch(timelineFactoryProvider).person(user.id, _person.id);
          ref.onDispose(timelineService.dispose);
          return timelineService;
        }),
      ],
      child: Timeline(
        appBar: PersonSliverAppBar(
          person: _person,
          onNameTap: () => handleEditName(context),
          onBirthdayTap: () => handleEditBirthday(context),
          onShowOptions: () => showOptionSheet(context),
        ),
      ),
    );
  }
}
