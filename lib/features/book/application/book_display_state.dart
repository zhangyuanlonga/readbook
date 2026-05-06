enum BookDisplayCoverSource { overrideCustom, localManaged, remote, none }

class BookDisplayState {
  const BookDisplayState({
    required this.displayTitle,
    this.displayAuthor,
    this.displayIntro,
    this.displayCover,
    this.realCoverUrl,
    this.customCoverPath,
    this.displayCoverSource = BookDisplayCoverSource.none,
    this.overrideUsed = false,
    this.localMetadataUsed = false,
  });

  final String displayTitle;
  final String? displayAuthor;
  final String? displayIntro;
  final String? displayCover;
  final String? realCoverUrl;
  final String? customCoverPath;
  final BookDisplayCoverSource displayCoverSource;
  final bool overrideUsed;
  final bool localMetadataUsed;

  @override
  bool operator ==(Object other) {
    return other is BookDisplayState &&
        other.displayTitle == displayTitle &&
        other.displayAuthor == displayAuthor &&
        other.displayIntro == displayIntro &&
        other.displayCover == displayCover &&
        other.realCoverUrl == realCoverUrl &&
        other.customCoverPath == customCoverPath &&
        other.displayCoverSource == displayCoverSource &&
        other.overrideUsed == overrideUsed &&
        other.localMetadataUsed == localMetadataUsed;
  }

  @override
  int get hashCode => Object.hash(
    displayTitle,
    displayAuthor,
    displayIntro,
    displayCover,
    realCoverUrl,
    customCoverPath,
    displayCoverSource,
    overrideUsed,
    localMetadataUsed,
  );
}
