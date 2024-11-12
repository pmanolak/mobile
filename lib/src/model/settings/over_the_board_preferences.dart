import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'over_the_board_preferences.freezed.dart';
part 'over_the_board_preferences.g.dart';

@riverpod
class OverTheBoardPreferences extends _$OverTheBoardPreferences
    with PreferencesStorage<OverTheBoardPrefs> {
  // ignore: avoid_public_notifier_properties
  @override
  PrefCategory get prefCategory => PrefCategory.overTheBoard;

  // ignore: avoid_public_notifier_properties
  @override
  OverTheBoardPrefs get defaults => OverTheBoardPrefs.defaults;

  @override
  OverTheBoardPrefs fromJson(Map<String, dynamic> json) =>
      OverTheBoardPrefs.fromJson(json);

  @override
  OverTheBoardPrefs build() {
    return fetch();
  }

  Future<void> toggleFlipPiecesAfterMove() {
    return save(
      state.copyWith(flipPiecesAfterMove: !state.flipPiecesAfterMove),
    );
  }

  Future<void> toggleSymmetricPieces() {
    return save(
      state.copyWith(symmetricPieces: !state.symmetricPieces),
    );
  }
}

@Freezed(fromJson: true, toJson: true)
class OverTheBoardPrefs with _$OverTheBoardPrefs implements Serializable {
  const OverTheBoardPrefs._();

  const factory OverTheBoardPrefs({
    required bool flipPiecesAfterMove,
    required bool symmetricPieces,
  }) = _OverTheBoardPrefs;

  static const defaults = OverTheBoardPrefs(
    flipPiecesAfterMove: false,
    symmetricPieces: false,
  );

  factory OverTheBoardPrefs.fromJson(Map<String, dynamic> json) {
    return _$OverTheBoardPrefsFromJson(json);
  }
}