const SOURCE_HOST = 'https://www.example.com';

function createBook(partial = {}) {
  return {
    // 可选：站点有稳定书籍主键时填写；没有可留空。
    id: '',
    title: '',
    author: '',
    cover: '',
    intro: '',
    status: '',
    category: '',
    score: '',
    wordCount: '',
    updateTime: '',
    tags: [],
    latestChapter: '',
    detailUrl: '',
    sourceId: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

function createChapter(partial = {}) {
  return {
    // 可选：站点有稳定章节主键时填写；没有可留空。
    id: '',
    title: '',
    url: '',
    index: 0,
    vip: false,
    updateTime: '',
    sourceId: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

function createContent(partial = {}) {
  return {
    title: '',
    content: '',
    nextUrl: null,
    images: [],
    sourceId: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

export default {
  meta: {
    name: '最小模板书源',
    group: '默认分组',
    author: 'your_name',
    description: '从这个骨架开始补齐站点逻辑。',
    domains: ['www.example.com'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },

  async init(ctx, task) {},

  async search(ctx, keyword) {
    return [];
  },

  async detail(ctx, book) {
    return createBook({
      ...book,
      sourceId: ctx.source.id,
    });
  },

  async chapters(ctx, book) {
    return [];
  },

  async content(ctx, book, chapter) {
    return createContent({
      title: chapter.title,
      content: '',
      sourceId: ctx.source.id,
    });
  },
};
