# Immich Fork — Claude Reference

This is a personal fork of [Immich](https://immich.app) with custom Android mobile app features. All changes were made by Claude (Anthropic AI) based on plain-English descriptions. Work happens on `claude/**` branches; the active branch is `claude/update-library-view-layout-39URK`.

## Tech stack (mobile)

- **Flutter/Dart** with `hooks_riverpod` for state management
- **Drift** (SQLite ORM) for local database queries
- **auto_route** for navigation (`context.pushRoute(SomeRoute(...))`)
- **photo_manager** for local device asset/album access
- Code generation: `build_runner`, `drift`, `auto_route` (run `dart run build_runner build --delete-conflicting-outputs`)
- CI: GitHub Actions builds a release APK for every push to `claude/**` (signed with `mobile/android/dev-release.jks`, password `android`, alias `immich`)

## Key file locations

| Area | File |
|------|------|
| Library tab | `mobile/lib/presentation/pages/drift_library.page.dart` |
| People collection page | `mobile/lib/presentation/pages/drift_people_collection.page.dart` |
| Albums selector / view modes | `mobile/lib/presentation/widgets/album/album_selector.widget.dart` |
| Asset viewer "Add to" menu | `mobile/lib/presentation/widgets/action_buttons/add_action_button.widget.dart` |
| Photo details (technical) | `mobile/lib/presentation/widgets/asset_viewer/asset_details/technical_details.widget.dart` |
| Photo grid filter model | `mobile/lib/domain/models/photo_grid_filter.model.dart` |
| Photo grid filter provider | `mobile/lib/providers/infrastructure/photo_grid_filter.provider.dart` |
| Photo grid filter bottom sheet | `mobile/lib/presentation/widgets/bottom_sheet/photo_grid_filter_bottom_sheet.widget.dart` |
| Remote asset repository | `mobile/lib/infrastructure/repositories/remote_asset.repository.dart` |
| Remote album repository | `mobile/lib/infrastructure/repositories/remote_album.repository.dart` |
| Asset service | `mobile/lib/domain/services/asset.service.dart` |
| Remote album service | `mobile/lib/domain/services/remote_album.service.dart` |
| Asset provider | `mobile/lib/providers/infrastructure/asset.provider.dart` |
| Album provider | `mobile/lib/providers/infrastructure/album.provider.dart` |
| App settings enum | `mobile/lib/services/app_settings.service.dart` |
| Store keys (Hive) | `mobile/lib/domain/models/store.model.dart` |
| Asset media repository | `mobile/lib/repositories/asset_media.repository.dart` |
| CI workflow | `.github/workflows/build-feature-apk.yml` |

## Features added in this fork

### Library tab redesign
**File:** `drift_library.page.dart`

The library page is a `CustomScrollView` with sliver sections. Each section is a `ConsumerWidget` that returns a `SliverPadding > SliverToBoxAdapter` (via `_SectionCard`).

- **People** — horizontal `ListView` of 64×64px squircle face avatars. Uses `Material(shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(64 * 0.35)), clipBehavior: Clip.antiAlias)`. Has `frameBuilder` to show a person-icon placeholder while loading (prevents blank on cache miss). Taps push `DriftPersonRoute(person: person)`.
- **Places** — horizontal `ListView` of 120×80px thumbnails sorted by photo count DESC (popularity). Each item is `SizedBox(width: 120) > InkWell` to ensure the full area is hit-testable. Taps push `DriftPlaceDetailRoute(place: place.$1)`.
- **On This Device** — horizontal `ListView` of 90×90px local album thumbnails. Same `SizedBox > InkWell` pattern. Taps push `LocalTimelineRoute(album: album)`.
- **Favorites** — horizontal `ListView` of 90×90px recent favorite photo thumbnails (up to 8, via `recentFavoritesProvider`). Tapping opens the asset viewer: calls `AssetViewer.setAsset(ref, asset)` then pushes `AssetViewerRoute(initialIndex: index, timelineService: timelineService)` where `timelineService = ref.read(timelineFactoryProvider).fromAssets(assets, TimelineOrigin.favorite)`.
- **Bottom list** — Card with `ListView(physics: NeverScrollableScrollPhysics())` of `ListTile`s for Archive, Trash, Shared Links, Folders, Locked Folder, Partners. Partners also shows individual partner tiles via `_PartnerList`.

**Tap pattern:** All tappable items in horizontal lists use `SizedBox(width, height) > InkWell > ClipRRect > content`. Do NOT use bare `GestureDetector` inside horizontal `ListView`s inside slivers — taps won't reliably fire without the explicit `SizedBox` size.

**Places sort by popularity:** `getPlaces()` in `remote_asset.repository.dart` uses `.addColumns([..., countAll()])` and `.orderBy([OrderingTerm.desc(countAll())])`.

**Recent favorites:** `getRecentFavorites(userId, {int limit = 8})` added to `RemoteAssetRepository` and `AssetService`. Provider: `recentFavoritesProvider` in `asset.provider.dart`.

---

### People view sections
**File:** `drift_people_collection.page.dart`

The people list is split into four sections rendered in order:
1. **Favorites** (`p.isFavorite == true && !p.isHidden`) — shown with a star header, always expanded
2. **Named** (`p.name.isNotEmpty && !p.isFavorite && !p.isHidden`) — always expanded
3. **Unnamed** (`p.name.isEmpty && !p.isHidden`) — collapsible, collapsed by default, header shows count
4. **Hidden** (`p.isHidden == true`) — collapsible, collapsed by default, header shows count

Long-pressing a face avatar calls `showPersonActionBottomSheet(context, person)` which shows options to rename, favorite/unfavorite, or hide/unhide.

---

### Albums — Sections view mode
**File:** `album_selector.widget.dart`

Three view modes cycle via a toggle button: List → Grid → Sections.

- Persisted in `AppSettingsEnum.albumViewMode` / `StoreKey.albumViewMode` (int, id=142)
- **Sections mode** (`_AlbumViewMode.sections`): renders `_AlbumSections` → `SliverList` of `_AlbumSectionCard`
- Each `_AlbumSectionCard` (`ConsumerWidget`) shows:
  - Header row: album name, item count, shared-with info, chevron
  - Thumbnail strip: horizontal `ListView` of up to 8 recent assets (80×80px), fetched via `albumRecentAssetsProvider(album.id)` (autoDispose family)
  - Divider
- `albumRecentAssetsProvider` calls `RemoteAlbumService.getRecentAssets(albumId, limit: 8)` which queries with `.orderBy([OrderingTerm.desc(_db.remoteAssetEntity.createdAt)]).limit(limit)`

---

### Favorites toggle in "Add to" menu
**File:** `add_action_button.widget.dart`

`AddToMenuItem` enum includes `favorites`. The toggle is handled directly in `_AddActionButtonState._toggleFavorite()` (not a sub-widget) to avoid `ref` invalidation after the menu closes:

```dart
Future<void> _toggleFavorite() async {
  final asset = ref.read(assetViewerProvider).currentAsset;
  if (asset == null || asset is! RemoteAsset) return;
  if (asset.isFavorite) {
    final result = await ref.read(actionProvider.notifier).unFavorite(ActionSource.viewer);
    if (result.success) ref.read(assetViewerProvider.notifier).setAsset(asset.copyWith(isFavorite: false));
  } else {
    final result = await ref.read(actionProvider.notifier).favorite(ActionSource.viewer);
    if (result.success) ref.read(assetViewerProvider.notifier).setAsset(asset.copyWith(isFavorite: true));
  }
}
```

---

### Photo details — local folder and file path
**File:** `technical_details.widget.dart`, `asset_media.repository.dart`

`AssetMediaRepository.getLocalFileInfo(String id)` fetches `AssetEntity.relativePath` (folder) and `entity.originFile?.path` (full path) from `photo_manager`.

In `TechnicalDetails._buildFileInfoTile`:
- If `asset is LocalAsset`: fetches filename + folder + path, renders `_LocalFileTiles`
- If `asset.localId != null` (cloud asset with local copy): fetches folder + path only, renders `_LocalFileTiles`
- Otherwise: plain `SheetTile` with filename only

`_LocalFileTiles` is a `StatelessWidget` that renders the filename tile plus optional folder (`Icons.folder_outlined`) and path (`Icons.storage_outlined`) tiles. All tiles support long-press to copy.

---

### Photos timeline filtering
**Files:** `photo_grid_filter.model.dart`, `photo_grid_filter.provider.dart`, `photo_grid_filter_bottom_sheet.widget.dart`

`PhotoGridFilter` holds two `Set<String>`:
- `folderIds` — local device folder IDs
- `cameraKeys` — `"make:::model"` strings

The filter bottom sheet has two tabs (Folders, Cameras) with multi-select chip lists. Changes are staged locally and applied/cleared on confirm. The filter is persisted via `StoreKey.photoGridFolderFilter` and `StoreKey.photoGridCameraFilter` (both `String`, serialized with `\x1F` separator).

---

### CI / signing
**File:** `.github/workflows/build-feature-apk.yml`

- Triggers on push to any `claude/**` branch
- Builds a release APK (arm64) signed with `mobile/android/dev-release.jks` (committed to repo, password `android`, alias `immich`) — fixed key so APK updates install over previous builds without reinstall
- Also builds a debug APK
- Both uploaded as GitHub Actions artifacts (14-day retention)

## Common patterns

### Adding a new persisted setting
1. Add a `StoreKey<T>._(id)` entry to `mobile/lib/domain/models/store.model.dart`
2. Add an `AppSettingsEnum<T>` entry to `mobile/lib/services/app_settings.service.dart`
3. Read/write via `ref.read(appSettingsServiceProvider).getSetting/setSetting(AppSettingsEnum.x)`

### Adding a new provider for DB data
1. Add query method to the relevant repository in `mobile/lib/infrastructure/repositories/`
2. Add service method delegating to it in `mobile/lib/domain/services/`
3. Add `FutureProvider` (or `FutureProvider.family`) in `mobile/lib/providers/infrastructure/`

### Navigation
Routes are defined in `mobile/lib/routing/router.dart` and generated in `router.gr.dart`. Navigate with `context.pushRoute(SomeRoute(...))`. All custom routes in this fork are already registered at the root router level.
