import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/discover_source_summary.dart';

final discoverSourceSummariesProvider =
    FutureProvider<List<DiscoverSourceSummary>>((ref) async {
      return <DiscoverSourceSummary>[
        DiscoverSourceSummary(
          id: 'source_biquge',
          name: '笔趣阁服务器源',
          categoryCount: 24,
          status: DiscoverSourceStatus.available,
          latencyMs: 128,
          categories: [
            _category(
              id: 'biquge_hot',
              name: '热门推荐',
              seed: 10,
              books: ['夜雨问道', '星河旧梦', '长生渡', '雾都灵案', '青山客', '烬海'],
            ),
            _category(
              id: 'biquge_xuanhuan',
              name: '玄幻奇幻',
              seed: 20,
              books: ['万古神庭', '九霄剑主', '荒原灵纪', '天命石', '玄门旧事', '龙渊行'],
            ),
            _category(
              id: 'biquge_dushi',
              name: '都市生活',
              seed: 30,
              books: ['城市微光', '明日咖啡馆', '逆风而行', '人间晚晴', '旧巷来信', '烟火年年'],
            ),
            _category(
              id: 'biquge_xianxia',
              name: '武侠仙侠',
              seed: 40,
              books: ['剑起南山', '白云观记', '江湖夜航', '青灯问仙', '昆仑雪', '一念山河'],
            ),
            _category(
              id: 'biquge_finish',
              name: '完本精选',
              seed: 50,
              books: ['归途有风', '故园春迟', '最后的客栈', '月落长安', '山海余生', '万里归鸿'],
            ),
          ],
        ),
        DiscoverSourceSummary(
          id: 'source_qidian',
          name: '起点聚合源',
          categoryCount: 18,
          status: DiscoverSourceStatus.slow,
          latencyMs: 860,
          categories: [
            _category(
              id: 'qidian_male',
              name: '男生频道',
              seed: 60,
              books: ['诸天行者', '深空边境', '大明夜巡', '御兽纪元', '机械王座', '黑塔档案'],
            ),
            _category(
              id: 'qidian_female',
              name: '女生频道',
              seed: 70,
              books: ['春日来信', '玫瑰航班', '她的北极星', '小城夏夜', '云端婚礼', '晚风知我'],
            ),
            _category(
              id: 'qidian_rank',
              name: '排行榜',
              seed: 80,
              books: ['第一序列', '星门之后', '天启名单', '长夜将明', '无尽回廊', '人皇纪事'],
            ),
            _category(
              id: 'qidian_new',
              name: '新书入库',
              seed: 90,
              books: ['昨日重启', '纸上星辰', '风暴邮局', '第七封印', '雨林火种', '边城异闻'],
            ),
          ],
        ),
        DiscoverSourceSummary(
          id: 'source_fanqie',
          name: '番茄小说源',
          categoryCount: 22,
          status: DiscoverSourceStatus.available,
          latencyMs: 214,
          categories: [
            _category(
              id: 'fanqie_free',
              name: '免费热读',
              seed: 100,
              books: ['今日宜喜欢', '她从月光来', '开局一座城', '人间有味', '向阳而生', '南风知愿'],
            ),
            _category(
              id: 'fanqie_short',
              name: '短篇故事',
              seed: 110,
              books: ['三分钟恋人', '午夜来电', '夏末便利店', '窗边的猫', '第十封信', '风停以后'],
            ),
            _category(
              id: 'fanqie_audio',
              name: '听书专区',
              seed: 120,
              books: ['山河入梦', '长街灯火', '旧书店奇谈', '星夜航线', '春山可望', '夜色温柔'],
            ),
            _category(
              id: 'fanqie_update',
              name: '最近更新',
              seed: 130,
              books: ['第九次心动', '晨昏之间', '云海邮差', '浮城日记', '归零计划', '银河尽头'],
            ),
          ],
        ),
        DiscoverSourceSummary(
          id: 'source_manga',
          name: '漫画聚合源',
          categoryCount: 16,
          status: DiscoverSourceStatus.available,
          latencyMs: 176,
          categories: [
            _category(
              id: 'manga_hot',
              name: '热门漫画',
              seed: 140,
              books: ['霓虹少年', '机甲课后', '猫街事件簿', '异世界食堂', '晴空战线', '零号社团'],
            ),
            _category(
              id: 'manga_japan',
              name: '日漫',
              seed: 150,
              books: ['樱色回合', '东京雨季', '蓝色月台', '少年侦探部', '怪谈社', '银河便当'],
            ),
            _category(
              id: 'manga_china',
              name: '国漫',
              seed: 160,
              books: ['山海少年录', '长安妖闻', '灵笼外传', '墨城风云', '白塔纪事', '龙门旧案'],
            ),
            _category(
              id: 'manga_finish',
              name: '已完结',
              seed: 170,
              books: ['终章之前', '夏日终点', '星轨完结篇', '旧日同盟', '归海', '黎明闭幕'],
            ),
          ],
        ),
        const DiscoverSourceSummary(
          id: 'source_legacy',
          name: '旧版测试源',
          categoryCount: 0,
          status: DiscoverSourceStatus.unavailable,
          latencyMs: null,
          categories: [],
        ),
      ];
    });

DiscoverSourceCategory _category({
  required String id,
  required String name,
  required int seed,
  required List<String> books,
}) {
  return DiscoverSourceCategory(
    id: id,
    name: name,
    books: [
      for (final entry in books.asMap().entries)
        DiscoverCategoryBook(
          id: '${id}_${entry.key}',
          name: entry.value,
          detailUrl: '/discover/$id/${entry.key}',
          coverSeed: seed + entry.key,
        ),
    ],
  );
}
