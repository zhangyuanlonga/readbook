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
}
