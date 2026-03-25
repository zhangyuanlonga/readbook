const String sourceScriptTemplateV1 = r'''
function createBook(partial = {}) {
  return {
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

function requestJson(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    ...options,
  });
}

function requestJsonLite(url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    ...options,
  });
}

export default {
  meta: {
    name: '临时脚本源',
    group: '调试',
    author: 'you',
    description: '直接在调试器里粘贴的书源脚本。',
    domains: ['debug.local'],
    homepage: 'https://debug.local',
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
    rateLimits: {
      'debug.local': {
        minIntervalMs: 500,
      },
    },
  },

  async init(ctx, task) {
    if (task.step === 'search' && !ctx.session.get('initialized')) {
      ctx.session.set('initialized', true);
      ctx.log('init executed');
    }
  },

  async search(ctx, keyword) {
    return [
      createBook({
        id: 'scratch-book-1',
        title: `${keyword} 调试样书`,
        author: '调试作者',
        latestChapter: '第3章 调试正文',
        score: '9.1',
        wordCount: '128000',
        updateTime: '2026-03-25 08:00:00',
        tags: ['调试', '示例'],
        detailUrl: '/books/debug',
        sourceId: ctx.source.id,
        extra: {
          debugMode: true,
        },
      }),
    ];
  },

  async detail(ctx, book) {
    return createBook({
      ...book,
      intro: `${book.title} 的详情来自临时脚本源。`,
      category: '调试分类',
      status: '连载',
      score: book.score || '9.1',
      wordCount: book.wordCount || '128000',
      updateTime: book.updateTime || '2026-03-25 08:00:00',
      tags: book.tags?.length ? book.tags : ['调试', '示例'],
      sourceId: ctx.source.id,
      extra: {
        ...book.extra,
        catalogKey: 'debug-catalog',
      },
    });
  },

  async chapters(ctx, book) {
    return [
      createChapter({
        id: 'debug-chapter-1',
        title: '第一章 调试开始',
        url: '/chapters/1',
        index: 1,
        updateTime: '2026-03-24 21:00:00',
        sourceId: ctx.source.id,
        extra: {
          fromBook: book.id,
        },
      }),
      createChapter({
        id: 'debug-chapter-2',
        title: '第二章 调试继续',
        url: '/chapters/2',
        index: 2,
        updateTime: '2026-03-25 08:00:00',
        sourceId: ctx.source.id,
        extra: {
          fromBook: book.id,
        },
      }),
    ];
  },

  async content(ctx, book, chapter) {
    return createContent({
      title: chapter.title,
      content: `${book.title}\n\n${chapter.title}\n\n这里是临时脚本调试正文。`,
      sourceId: ctx.source.id,
    });
  },
};
''';
