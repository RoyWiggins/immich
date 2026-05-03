import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/extensions/asyncvalue_extensions.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_viewer.page.dart';
import 'package:immich_mobile/presentation/widgets/images/local_album_thumbnail.widget.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail.widget.dart';
import 'package:immich_mobile/presentation/widgets/people/partner_user_avatar.widget.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/partner.provider.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/server_info.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:immich_mobile/widgets/common/immich_sliver_app_bar.dart';

@RoutePage()
class DriftLibraryPage extends ConsumerWidget {
  const DriftLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: CustomScrollView(
        slivers: [
          ImmichSliverAppBar(snap: false, floating: false, pinned: true, showUploadButton: false),
          _PeopleSection(),
          _PlacesSection(),
          _OnDeviceSection(),
          _FavoritesSection(),
          _BottomActionList(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              'view_all'.t(context: context),
              style: TextStyle(color: context.primaryColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.topPadding = 16});

  final Widget child;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.only(left: 16, right: 16, top: topPadding),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

class _PeopleSection extends ConsumerWidget {
  const _PeopleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(driftGetAllPeopleProvider);

    return people.widgetWhen(
      onLoading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      onData: (people) {
        final visible = people.where((p) => !p.isHidden).toList();
        if (visible.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'people'.t(context: context),
                onSeeAll: () => context.pushRoute(const DriftPeopleCollectionRoute()),
              ),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final person = visible[index];
                    return GestureDetector(
                      onTap: () => context.pushRoute(DriftPersonRoute(person: person)),
                      child: SizedBox(
                        width: 64,
                        child: Column(
                          children: [
                            Material(
                              shape: ContinuousRectangleBorder(
                                borderRadius: BorderRadius.circular(64 * 0.35),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image(
                                image: RemoteImageProvider(url: getFaceThumbnailUrl(person.id)),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Places
// ---------------------------------------------------------------------------

class _PlacesSection extends ConsumerWidget {
  const _PlacesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider);

    return places.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (places) {
        if (places.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'places'.t(),
                onSeeAll: () => context.pushRoute(DriftPlaceRoute(currentLocation: null)),
              ),
              SizedBox(
                height: 114,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: places.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return SizedBox(
                      width: 120,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        onTap: () => context.pushRoute(DriftPlaceDetailRoute(place: place.$1)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              child: SizedBox(
                                width: 120,
                                height: 80,
                                child: Thumbnail.remote(remoteId: place.$2, thumbhash: "", fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              place.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// On this device
// ---------------------------------------------------------------------------

class _OnDeviceSection extends ConsumerWidget {
  const _OnDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(localAlbumProvider);

    return albums.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (albums) {
        if (albums.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'on_this_device'.t(context: context),
                onSeeAll: () => context.pushRoute(const DriftLocalAlbumsRoute()),
              ),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: albums.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    return SizedBox(
                      width: 90,
                      height: 90,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        onTap: () => context.pushRoute(LocalTimelineRoute(album: album)),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          child: LocalAlbumThumbnail(albumId: album.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

class _FavoritesSection extends ConsumerWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(recentFavoritesProvider);

    return favorites.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (assets) {
        if (assets.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        final timelineService = ref.read(timelineFactoryProvider).fromAssets(assets, TimelineOrigin.favorite);

        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'favorites'.t(context: context),
                onSeeAll: () => context.pushRoute(const DriftFavoriteRoute()),
              ),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: assets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return SizedBox(
                      width: 90,
                      height: 90,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        onTap: () {
                          AssetViewer.setAsset(ref, asset);
                          context.pushRoute(
                            AssetViewerRoute(initialIndex: index, timelineService: timelineService),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          child: Thumbnail.fromAsset(asset: asset, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action list (favorites, archive, trash, shared links, folders, locked, partners)
// ---------------------------------------------------------------------------

class _BottomActionList extends ConsumerWidget {
  const _BottomActionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTrashEnabled = ref.watch(serverInfoProvider.select((s) => s.serverFeatures.trash));
    final partnerSharedWithAsync = ref.watch(driftSharedWithPartnerProvider);
    final partners = partnerSharedWithAsync.valueOrNull ?? [];

    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, top: 20, right: 16, bottom: 32),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.colorScheme.onSurface.withAlpha(10), width: 1),
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            gradient: LinearGradient(
              colors: [
                context.colorScheme.primary.withAlpha(10),
                context.colorScheme.primary.withAlpha(15),
                context.colorScheme.primary.withAlpha(20),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickTile(
                icon: Icons.archive_outlined,
                label: 'archived'.t(context: context),
                onTap: () => context.pushRoute(const DriftArchiveRoute()),
                isFirst: true,
              ),
              if (isTrashEnabled)
                _QuickTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'trash'.t(context: context),
                  onTap: () => context.pushRoute(const DriftTrashRoute()),
                ),
              _QuickTile(
                icon: Icons.link_outlined,
                label: 'shared_links'.t(context: context),
                onTap: () => context.pushRoute(const SharedLinkRoute()),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _QuickTile(
                icon: Icons.folder_outlined,
                label: 'folders'.t(context: context),
                onTap: () => context.pushRoute(FolderRoute()),
              ),
              _QuickTile(
                icon: Icons.lock_outline_rounded,
                label: 'locked_folder'.t(context: context),
                onTap: () => context.pushRoute(const DriftLockedFolderRoute()),
              ),
              _QuickTile(
                icon: Icons.group_outlined,
                label: 'partners'.t(context: context),
                onTap: () => context.pushRoute(const DriftPartnerRoute()),
                isLast: partners.isEmpty,
              ),
              _PartnerList(partners: partners),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isFirst ? 20 : 0),
          topRight: Radius.circular(isFirst ? 20 : 0),
          bottomLeft: Radius.circular(isLast ? 20 : 0),
          bottomRight: Radius.circular(isLast ? 20 : 0),
        ),
      ),
      leading: Icon(icon, size: 26),
      title: Text(label, style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

class _PartnerList extends StatelessWidget {
  const _PartnerList({required this.partners});

  final List<PartnerUserDto> partners;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: partners.length,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final partner = partners[index];
        final isLastItem = index == partners.length - 1;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(isLastItem ? 20 : 0),
              bottomRight: Radius.circular(isLastItem ? 20 : 0),
            ),
          ),
          contentPadding: const EdgeInsets.only(left: 12.0, right: 18.0),
          leading: PartnerUserAvatar(partner: partner),
          title: const Text(
            "partner_list_user_photos",
            style: TextStyle(fontWeight: FontWeight.w500),
          ).t(context: context, args: {'user': partner.name}),
          onTap: () => context.pushRoute(DriftPartnerDetailRoute(partner: partner)),
        );
      },
    );
  }
}
