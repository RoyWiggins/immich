import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/widgets/people/person_action_bottom_sheet.widget.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/utils/people.utils.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';

@RoutePage()
class DriftPeopleCollectionPage extends ConsumerStatefulWidget {
  const DriftPeopleCollectionPage({super.key});

  @override
  ConsumerState<DriftPeopleCollectionPage> createState() => _DriftPeopleCollectionPageState();
}

class _DriftPeopleCollectionPageState extends ConsumerState<DriftPeopleCollectionPage> {
  final FocusNode _formFocus = FocusNode();
  String? _search;
  bool _unnamedExpanded = false;

  @override
  void dispose() {
    _formFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(driftGetAllPeopleProvider);
    final isTablet = MediaQuery.sizeOf(context).width > 600;
    final crossAxisCount = isTablet ? 6 : 3;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: _search == null,
        title: _search != null
            ? SearchField(
                focusNode: _formFocus,
                onTapOutside: (_) => _formFocus.unfocus(),
                onChanged: (value) => setState(() => _search = value),
                filled: true,
                hintText: 'filter_people'.tr(),
                autofocus: true,
              )
            : Text('people'.tr()),
        actions: [
          IconButton(
            icon: Icon(_search != null ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _search = _search == null ? '' : null);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: peopleAsync.when(
          data: (people) {
            // Searching: flat filtered grid
            if (_search != null) {
              final filtered = people
                  .where((p) => p.name.toLowerCase().contains(_search!.toLowerCase()))
                  .toList();
              return _FlatGrid(people: filtered, crossAxisCount: crossAxisCount);
            }

            final favorites = people.where((p) => p.isFavorite).toList();
            final named = people.where((p) => !p.isFavorite && p.name.isNotEmpty).toList();
            final unnamed = people.where((p) => p.name.isEmpty).toList();

            return CustomScrollView(
              slivers: [
                if (favorites.isNotEmpty) ...[
                  _SectionHeader(title: 'person_section_favorites'.tr(), icon: Icons.star_rounded),
                  _PeopleGrid(people: favorites, crossAxisCount: crossAxisCount),
                ],
                if (named.isNotEmpty) ...[
                  _SectionHeader(title: 'people'.tr()),
                  _PeopleGrid(people: named, crossAxisCount: crossAxisCount),
                ],
                if (unnamed.isNotEmpty) ...[
                  _UnnamedHeader(
                    count: unnamed.length,
                    expanded: _unnamedExpanded,
                    onTap: () => setState(() => _unnamedExpanded = !_unnamedExpanded),
                  ),
                  if (_unnamedExpanded) _PeopleGrid(people: unnamed, crossAxisCount: crossAxisCount),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
          error: (_, __) => const Center(child: Text('error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _FlatGrid extends StatelessWidget {
  final List<DriftPerson> people;
  final int crossAxisCount;

  const _FlatGrid({required this.people, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _PeopleGrid(people: people, crossAxisCount: crossAxisCount),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionHeader({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.colorScheme.primary),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnnamedHeader extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _UnnamedHeader({required this.count, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(
                'person_section_unnamed'.tr(args: [count.toString()]),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more, size: 18, color: context.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleGrid extends StatelessWidget {
  final List<DriftPerson> people;
  final int crossAxisCount;

  const _PeopleGrid({required this.people, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.85,
        ),
        itemCount: people.length,
        itemBuilder: (context, index) => _PersonCell(person: people[index]),
      ),
    );
  }
}

class _PersonCell extends ConsumerWidget {
  final DriftPerson person;

  const _PersonCell({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = MediaQuery.sizeOf(context).width > 600;
    final radius = isTablet ? 50.0 : 48.0;

    return GestureDetector(
      onTap: () => context.pushRoute(DriftPersonRoute(person: person)),
      onLongPress: () => showPersonActionBottomSheet(context, person),
      child: Column(
        key: ValueKey(person.id),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Material(
                shape: const CircleBorder(side: BorderSide.none),
                elevation: 3,
                child: CircleAvatar(
                  maxRadius: radius,
                  backgroundImage: RemoteImageProvider(url: getFaceThumbnailUrl(person.id)),
                ),
              ),
              if (person.isFavorite)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star_rounded, size: 16, color: context.colorScheme.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showNameEditModal(context, person),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: person.name.isEmpty
                  ? Text(
                      'add_a_name'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.primary),
                    )
                  : Text(
                      person.name,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
