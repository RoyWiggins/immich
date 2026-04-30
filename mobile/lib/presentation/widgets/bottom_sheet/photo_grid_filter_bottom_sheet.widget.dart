import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/photo_grid_filter.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/photo_grid_filter.provider.dart';

class PhotoGridFilterBottomSheet extends ConsumerStatefulWidget {
  const PhotoGridFilterBottomSheet({super.key});

  @override
  ConsumerState<PhotoGridFilterBottomSheet> createState() => _PhotoGridFilterBottomSheetState();
}

class _PhotoGridFilterBottomSheetState extends ConsumerState<PhotoGridFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Set<String> _pendingFolderIds;
  late Set<String> _pendingCameraKeys;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final current = ref.read(photoGridFilterProvider);
    _pendingFolderIds = Set.from(current.folderIds);
    _pendingCameraKeys = Set.from(current.cameraKeys);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _applyAndClose() async {
    final notifier = ref.read(photoGridFilterProvider.notifier);
    await notifier.setFolderIds(_pendingFolderIds);
    await notifier.setCameraKeys(_pendingCameraKeys);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clearAndClose() async {
    await ref.read(photoGridFilterProvider.notifier).clearAll();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(photoGridFilterProvider);
    final hasAnyPending = _pendingFolderIds.isNotEmpty || _pendingCameraKeys.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _HandleBar(),
              _Header(
                hasFilter: filter.hasFilter,
                hasAnyPending: hasAnyPending,
                onApply: _applyAndClose,
                onClear: _clearAndClose,
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'photo_filter_folders'.tr()),
                  Tab(text: 'photo_filter_cameras'.tr()),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _FolderFilterTab(
                      selectedIds: _pendingFolderIds,
                      onToggle: (id) => setState(() {
                        if (_pendingFolderIds.contains(id)) {
                          _pendingFolderIds.remove(id);
                        } else {
                          _pendingFolderIds.add(id);
                        }
                      }),
                    ),
                    _CameraFilterTab(
                      selectedKeys: _pendingCameraKeys,
                      onToggle: (key) => setState(() {
                        if (_pendingCameraKeys.contains(key)) {
                          _pendingCameraKeys.remove(key);
                        } else {
                          _pendingCameraKeys.add(key);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HandleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.colorScheme.onSurfaceVariant.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool hasFilter;
  final bool hasAnyPending;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _Header({
    required this.hasFilter,
    required this.hasAnyPending,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'photo_filter_title'.tr(),
            style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (hasFilter)
            TextButton(
              onPressed: onClear,
              child: Text(
                'photo_filter_clear_all'.tr(),
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: onApply,
            child: Text('photo_filter_apply'.tr()),
          ),
        ],
      ),
    );
  }
}

class _FolderFilterTab extends ConsumerWidget {
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  const _FolderFilterTab({required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(localAlbumProvider);

    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text(err.toString())),
      data: (albums) {
        if (albums.isEmpty) {
          return Center(child: Text('photo_filter_no_folders'.tr()));
        }
        return ListView.builder(
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final isSelected = selectedIds.contains(album.id);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (_) => onToggle(album.id),
              title: Text(album.name),
              subtitle: Text(
                'photo_filter_asset_count'.tr(namedArgs: {'count': album.assetCount.toString()}),
                style: context.textTheme.bodySmall,
              ),
              secondary: const Icon(Icons.folder_outlined),
              controlAffinity: ListTileControlAffinity.trailing,
            );
          },
        );
      },
    );
  }
}

class _CameraFilterTab extends ConsumerWidget {
  final Set<String> selectedKeys;
  final void Function(String key) onToggle;

  const _CameraFilterTab({required this.selectedKeys, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camerasAsync = ref.watch(availableCamerasProvider);

    return camerasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text(err.toString())),
      data: (cameras) {
        if (cameras.isEmpty) {
          return Center(child: Text('photo_filter_no_cameras'.tr()));
        }
        return ListView.builder(
          itemCount: cameras.length,
          itemBuilder: (context, index) {
            final camera = cameras[index];
            final isSelected = selectedKeys.contains(camera.key);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (_) => onToggle(camera.key),
              title: Text(camera.displayName),
              secondary: const Icon(Icons.camera_alt_outlined),
              controlAffinity: ListTileControlAffinity.trailing,
            );
          },
        );
      },
    );
  }
}
