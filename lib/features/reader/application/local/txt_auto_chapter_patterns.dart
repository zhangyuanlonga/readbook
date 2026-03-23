class TxtAutoChapterPattern {
  const TxtAutoChapterPattern({
    required this.name,
    required this.pattern,
    required this.serialNumber,
    required this.enabled,
    this.example,
  });

  final String name;
  final String pattern;
  final String? example;
  final int serialNumber;
  final bool enabled;

  RegExp get compiled => RegExp(pattern, multiLine: true, caseSensitive: false);
}

const List<TxtAutoChapterPattern>
defaultTxtAutoChapterPatterns = <TxtAutoChapterPattern>[
  TxtAutoChapterPattern(
    name: '目录(去空白)',
    pattern:
        r'(?<=[　\s])(?:序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|第\s{0,4}[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\s{0,4}(?:章|节(?!课)|卷|集(?![合和]))(?:\s|[:：\-_.、\)\]）】》>]|$)).{0,30}$',
    example: '第一章 假装第一章前面有空白但我不要',
    serialNumber: 0,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '目录',
    pattern:
        r'^[ 　\t]{0,4}(?:序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|第\s{0,4}[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\s{0,4}(?:章|节(?!课)|卷|集(?![合和])|部(?![分赛游])|篇(?!张))(?:\s|[:：\-_.、\)\]）】》>]|$)).{0,30}$',
    example: '第一章 标准的粤语就是这样',
    serialNumber: 1,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '目录(匹配简介)',
    pattern:
        r'(?<=[　\s])(?:(?:内容|文章)?简介|文案|前言|序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|第\s{0,4}[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\s{0,4}(?:章|节(?!课)|卷|集(?![合和])|部(?![分赛游])|回(?![合来事去])|场(?![和合比电是])|篇(?!张))).{0,30}$',
    example: '简介 老夫诸葛村夫',
    serialNumber: 2,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '目录(古典、轻小说备用)',
    pattern:
        r'^[ 　\t]{0,4}(?:序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|第\s{0,4}[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\s{0,4}(?:章|节(?!课)|卷|集(?![合和])|部(?![分赛游])|回(?![合来事去])|场(?![和合比电是])|话|篇(?!张))).{0,30}$',
    example: '第一章 比上面只多了回和话',
    serialNumber: 3,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '数字(纯数字标题)',
    pattern: r'(?<=[　\s])\d+\.?[ 　\t]{0,4}$',
    example: '12',
    serialNumber: 4,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '大写数字(纯数字标题)',
    pattern: r'(?<=[　\s])[零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,12}[ 　\t]{0,4}$',
    example: '一百七十',
    serialNumber: 5,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '数字混合(纯数字标题)',
    pattern: r'(?<=[　\s])[零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟\d]{1,12}[ 　\t]{0,4}$',
    example: '12 / 一百七十',
    serialNumber: 6,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '数字 分隔符 标题名称',
    pattern: r'^[ 　\t]{0,4}\d{1,5}[:：,.， 、_—\-].{1,30}$',
    example: '1、这个就是标题',
    serialNumber: 7,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '大写数字 分隔符 标题名称',
    pattern:
        r'^[ 　\t]{0,4}(?:序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|[零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}章?)[ 、_—\-].{1,30}$',
    example: '一、只有前面的数字有差别',
    serialNumber: 8,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '数字混合 分隔符 标题名称',
    pattern:
        r'^[ 　\t]{0,4}(?:序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|[零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}章?[ 、_—\-]|\d{1,5}章?[:：,.， 、_—\-]).{0,30}$',
    example: '1、人参公鸡 / 二百二十章 boy next door',
    serialNumber: 9,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '正文 标题/序号',
    pattern: r'^[ 　\t]{0,4}正文[ 　]{1,4}.{0,20}$',
    example: '正文 我奶常山赵子龙',
    serialNumber: 10,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: 'Chapter/Section/Part/Episode 序号 标题',
    pattern:
        r'^[ 　\t]{0,4}(?:[Cc]hapter|[Ss]ection|[Pp]art|ＰＡＲＴ|[Nn][oO][.、]|[Ee]pisode|(?:内容|文章)?简介|文案|前言|序章|楔子|正文(?!完|结)|终章|后记|尾声|番外)\s{0,4}\d{1,4}.{0,30}$',
    example: 'Chapter 1 MyGrandmaIsNB',
    serialNumber: 11,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: 'Chapter(去简介)',
    pattern:
        r'^[ 　\t]{0,4}(?:[Cc]hapter|[Ss]ection|[Pp]art|ＰＡＲＴ|[Nn][Oo]\.|[Ee]pisode)\s{0,4}\d{1,4}.{0,30}$',
    example: 'Chapter 1 MyGrandmaIsNB',
    serialNumber: 12,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '特殊符号 序号 标题',
    pattern:
        r'(?<=[\s　])[【〔〖「『〈［\[](?:第|[Cc]hapter)[\d零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,10}[章节].{0,20}$',
    example: '【第一章 后面的符号可以没有',
    serialNumber: 13,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '特殊符号 标题(成对)',
    pattern:
        r'(?<=[\s　]{0,4})(?:[\[〈「『〖〔《（【\(].{1,30}[\)】）》〕〗』」〉\]]?|(?:内容|文章)?简介|文案|前言|序章|楔子|正文(?!完|结)|终章|后记|尾声|番外)[ 　]{0,4}$',
    example: '『加个直角引号更专业』',
    serialNumber: 14,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '特殊符号 标题(单个)',
    pattern:
        r'(?<=[\s　]{0,4})(?:[☆★✦✧].{1,30}|(?:内容|文章)?简介|文案|前言|序章|楔子|正文(?!完|结)|终章|后记|尾声|番外)[ 　]{0,4}$',
    example: '☆、晋江作者最喜欢的格式',
    serialNumber: 15,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '章/卷 序号 标题',
    pattern:
        r'^[ \t　]{0,4}(?:(?:内容|文章)?简介|文案|前言|序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|[卷章][\d零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8})[ 　]{0,4}.{0,30}$',
    example: '卷五 开源盛世',
    serialNumber: 16,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '顶格标题',
    pattern: r'^\S.{1,20}$',
    example: '20字以内顶格写的都是标题',
    serialNumber: 17,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '双标题(前向)',
    pattern:
        r'(?m)(?<=[ \t　]{0,4})第[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}章.{0,30}$(?=[\s　]{0,8}第[\d零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}章)',
    example: '第一章 真正的标题 / 第一章 这个不要',
    serialNumber: 18,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '双标题(后向)',
    pattern:
        r'(?m)(?<=[ \t　]{0,4}第[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}章.{0,30}$[\s　]{0,8})第[\d零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}章.{0,30}$',
    example: '第一章 这个标题不要 / 第一章真正的标题',
    serialNumber: 19,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '书名 括号 序号',
    pattern:
        r'^[一-龥]{1,20}[ 　\t]{0,4}[(（][\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}[)）][ 　\t]{0,4}$',
    example: '标题后面数字有括号(12)',
    serialNumber: 20,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '书名 序号',
    pattern:
        r'^[一-龥]{1,20}[ 　\t]{0,4}[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8}[ 　\t]{0,4}$',
    example: '标题后面数字没有括号124',
    serialNumber: 21,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '特定字符 标题 特定符号',
    pattern: r'(?<=\={3,6}).{1,40}?(?=\=)',
    example: '===起这种标题干什么===',
    serialNumber: 22,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '字数分割 分节阅读',
    pattern:
        r'(?<=[ 　\t]{0,4})(?:.{0,15}分[页节章段]阅读[-_ ]|第\s{0,4}[\d零一二两三四五六七八九十百千万]{1,6}\s{0,4}[页节]).{0,30}$',
    example: '分节|分页|分段阅读 / 第一页',
    serialNumber: 23,
    enabled: true,
  ),
  TxtAutoChapterPattern(
    name: '通用模式',
    pattern:
        r'(?im)^.{0,6}(?:[引楔]子|正文(?!完|结)|[引序前]言|[序终]章|扉页|[上中下][部篇卷]|卷首语|后记|尾声|番外|={2,4}|第\s{0,4}[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\s{0,4}(?:章|节(?!课)|卷|页[、 　]|集(?![合和])|部(?![分是门落])|篇(?!张))).{0,40}$|^.{0,6}[\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟a-z]{1,8}[、. 　].{0,20}$',
    example: '激进模式,适配更多非常用格式',
    serialNumber: 24,
    enabled: false,
  ),
  TxtAutoChapterPattern(
    name: '默认分章模式',
    pattern: '',
    example: '兜底模式，请勿改动此内容',
    serialNumber: 99,
    enabled: false,
  ),
];

List<TxtAutoChapterPattern> get defaultEnabledTxtAutoChapterPatterns =>
    defaultTxtAutoChapterPatterns
      .where((pattern) => pattern.enabled && pattern.pattern.trim().isNotEmpty)
      .toList(growable: false)..sort(
      (first, second) => first.serialNumber.compareTo(second.serialNumber),
    );
