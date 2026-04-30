import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/photo_grid_filter.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline.repository.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/store.provider.dart';

/// Provides distinct camera make+model pairs available in the remote EXIF DB.
final availableCamerasProvider = FutureProvider<List<CameraInfo>>((ref) {
  return DriftTimelineRepository(ref.watch(driftProvider)).getDistinctCameras();
});

class PhotoGridFilterNotifier extends Notifier<PhotoGridFilter> {
  @override
  PhotoGridFilter build() {
    final store = ref.read(storeServiceProvider);
    final folderStr = store.tryGet(StoreKey.photoGridFolderFilter) ?? '';
    final cameraStr = store.tryGet(StoreKey.photoGridCameraFilter) ?? '';
    return PhotoGridFilter(
      folderIds: PhotoGridFilter.deserialize(folderStr),
      cameraKeys: PhotoGridFilter.deserialize(cameraStr),
    );
  }

  Future<void> setFolderIds(Set<String> ids) async {
    final store = ref.read(storeServiceProvider);
    final toSave = PhotoGridFilter(folderIds: ids).serializeFolderIds();
    await store.put(StoreKey.photoGridFolderFilter, toSave);
    state = state.copyWith(folderIds: ids);
  }

  Future<void> setCameraKeys(Set<String> keys) async {
    final store = ref.read(storeServiceProvider);
    final toSave = PhotoGridFilter(cameraKeys: keys).serializeCameraKeys();
    await store.put(StoreKey.photoGridCameraFilter, toSave);
    state = state.copyWith(cameraKeys: keys);
  }

  Future<void> clearAll() async {
    final store = ref.read(storeServiceProvider);
    await Future.wait([
      store.put(StoreKey.photoGridFolderFilter, ''),
      store.put(StoreKey.photoGridCameraFilter, ''),
    ]);
    state = const PhotoGridFilter();
  }
}

final photoGridFilterProvider = NotifierProvider<PhotoGridFilterNotifier, PhotoGridFilter>(
  PhotoGridFilterNotifier.new,
);
