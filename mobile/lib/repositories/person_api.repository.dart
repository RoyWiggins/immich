import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/person.model.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/repositories/api.repository.dart';
import 'package:openapi/api.dart';

final personApiRepositoryProvider = Provider((ref) => PersonApiRepository(ref.watch(apiServiceProvider).peopleApi));

class PersonApiRepository extends ApiRepository {
  final PeopleApi _api;

  PersonApiRepository(this._api);

  Future<List<PersonDto>> getAll() async {
    final dto = await checkNull(_api.getAllPeople());
    return dto.people.map(_toPerson).toList();
  }

  Future<PersonDto> update(
    String id, {
    String? name,
    DateTime? birthday,
    bool? isFavorite,
    bool? isHidden,
  }) async {
    final birthdayUtc = birthday == null ? null : DateTime.utc(birthday.year, birthday.month, birthday.day);
    final dto = PersonUpdateDto(name: name, birthDate: birthdayUtc, isFavorite: isFavorite, isHidden: isHidden);
    final response = await checkNull(_api.updatePerson(id, dto));
    return _toPerson(response);
  }

  Future<List<BulkIdResponseDto>> mergePerson(String targetId, List<String> sourceIds) async {
    final dto = MergePersonDto(ids: sourceIds);
    return await checkNull(_api.mergePerson(targetId, dto)) ?? [];
  }

  static PersonDto _toPerson(PersonResponseDto dto) => PersonDto(
    birthDate: dto.birthDate,
    id: dto.id,
    isHidden: dto.isHidden,
    name: dto.name,
    thumbnailPath: dto.thumbnailPath,
  );
}
