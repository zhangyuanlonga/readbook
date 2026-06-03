import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_display_state.freezed.dart';

enum BookDisplayCoverSource { overrideCustom, localManaged, remote, none }

@freezed
abstract class BookDisplayState with _$BookDisplayState {
  const factory BookDisplayState({
    required String displayTitle,
    String? displayAuthor,
    String? displayIntro,
    String? displayCover,
    String? realCoverUrl,
    String? customCoverPath,
    @Default(BookDisplayCoverSource.none)
    BookDisplayCoverSource displayCoverSource,
    @Default(false) bool overrideUsed,
    @Default(false) bool localMetadataUsed,
  }) = _BookDisplayState;
}
