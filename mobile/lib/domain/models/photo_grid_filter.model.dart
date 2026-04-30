import 'package:collection/collection.dart';

class PhotoGridFilter {
  final Set<String> folderIds;
  final Set<String> cameraKeys; // "make:::model" format

  const PhotoGridFilter({
    this.folderIds = const {},
    this.cameraKeys = const {},
  });

  bool get hasFilter => folderIds.isNotEmpty || cameraKeys.isNotEmpty;
  bool get hasFolderFilter => folderIds.isNotEmpty;
  bool get hasCameraFilter => cameraKeys.isNotEmpty;

  PhotoGridFilter copyWith({Set<String>? folderIds, Set<String>? cameraKeys}) {
    return PhotoGridFilter(
      folderIds: folderIds ?? this.folderIds,
      cameraKeys: cameraKeys ?? this.cameraKeys,
    );
  }

  static const String _listSeparator = '\x1F'; // unit separator
  static const String cameraSeparator = ':::';

  String serializeFolderIds() => folderIds.join(_listSeparator);
  String serializeCameraKeys() => cameraKeys.join(_listSeparator);

  static Set<String> deserialize(String value) {
    if (value.isEmpty) return const {};
    return value.split(_listSeparator).where((s) => s.isNotEmpty).toSet();
  }

  static String makeCameraKey(String? make, String? model) =>
      '${make ?? ''}$cameraSeparator${model ?? ''}';

  static (String make, String model) parseCameraKey(String key) {
    final idx = key.indexOf(cameraSeparator);
    if (idx < 0) return (key, '');
    return (key.substring(0, idx), key.substring(idx + cameraSeparator.length));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotoGridFilter &&
        const SetEquality<String>().equals(other.folderIds, folderIds) &&
        const SetEquality<String>().equals(other.cameraKeys, cameraKeys);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(folderIds.toList()..sort()),
        Object.hashAll(cameraKeys.toList()..sort()),
      );
}

class CameraInfo {
  final String? make;
  final String? model;

  const CameraInfo({this.make, this.model});

  String get key => PhotoGridFilter.makeCameraKey(make, model);

  String get displayName {
    final m = make?.trim();
    final mo = model?.trim();
    if (m != null && m.isNotEmpty && mo != null && mo.isNotEmpty) {
      return '$m $mo';
    }
    return m ?? mo ?? 'Unknown Camera';
  }
}
