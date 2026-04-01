const String sourceScriptTemplateV1 = r'''
function createBook(partial = {}) {
  return {
    // 可选：站点有稳定主键时填写；没有可留空，宿主可兜底生成。
    id: '',
    // 推荐：novel / comic / audio
    type: '',
    title: '',
    author: '',
    cover: '',
    intro: '',
    status: '',
    category: '',
    // 以下字段当前运行时仍支持，适合搜索结果增强展示。
    score: '',
    wordCount: '',
    updateTime: '',
    tags: [],
    latestChapter: '',
    detailUrl: '',
    // 建议在 detail 阶段补齐。
    tocUrl: '',
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
    // 运行时兼容 `vip` 与 `isVip`，模板统一使用 `isVip`。
    isVip: false,
    isPay: false,
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
    // 图片型正文可直接返回图片 URL 数组。
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
        type: 'novel',
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
        isVip: false,
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
        isVip: false,
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

const String sourceScriptOfficialTemplateV1 = r'''
const SOURCE_HOST = 'https://www.example.com';

function createBook(partial = {}) {
  return {
    // 可选：站点有稳定主键时填写；没有可留空，宿主可兜底生成。
    id: '',
    // 推荐：novel / comic / audio
    type: '',
    title: '',
    author: '',
    cover: '',
    intro: '',
    status: '',
    category: '',
    // 以下字段当前运行时仍支持，适合搜索结果增强展示。
    score: '',
    wordCount: '',
    updateTime: '',
    tags: [],
    latestChapter: '',
    detailUrl: '',
    // 建议在 detail 阶段补齐。
    tocUrl: '',
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
    // 运行时兼容 `vip` 与 `isVip`，模板统一使用 `isVip`。
    isVip: false,
    isPay: false,
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
    // 图片型正文可直接返回图片 URL 数组。
    images: [],
    sourceId: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

// 官方推荐写法：helper 显式接收 ctx。
function requestJson(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    ...options,
  });
}

// 简化版写法：如果你嫌每次传 ctx 麻烦，也可以直接使用全局 ctx。
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
    name: '示例书源',
    group: '默认分组',
    author: 'your_name',
    description: '一个演示 API / HTML / 浏览器混合流程的模板书源。',
    domains: ['www.example.com'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
    rateLimits: {
      'www.example.com': {
        minIntervalMs: 800,
      },
      'api.example.com': {
        minIntervalMs: 300,
      },
    },
  },

  async init(ctx, task) {
    if (task.step !== 'search') {
      return;
    }

    if (!ctx.session.get('bootstrapToken')) {
      const bootstrap = await ctx.http.request({
        url: 'https://api.example.com/bootstrap',
        method: 'GET',
        timeoutMs: 5000,
      });

      if (bootstrap.json?.token) {
        ctx.session.set('bootstrapToken', bootstrap.json.token);
      }
    }

    if (ctx.session.get('needLogin') === true) {
      await ctx.browser.challenge({
        url: `${SOURCE_HOST}/login`,
        reason: 'login_required',
        timeoutMs: 120000,
      });
    }
  },

  async search(ctx, keyword) {
    const response = await requestJson(ctx, `${SOURCE_HOST}/search`, {
      query: {
        q: keyword,
      },
      responseType: 'text',
      timeoutMs: 6000,
    });

    if (ctx.http.isChallenge(response)) {
      await ctx.browser.challenge({
        url: response.url,
        reason: 'captcha',
        timeoutMs: 120000,
      });
    }

    const retryResponse = ctx.http.isChallenge(response)
      ? await ctx.http.request({
          url: `${SOURCE_HOST}/search`,
          method: 'GET',
          query: {
            q: keyword,
          },
          timeoutMs: 6000,
        })
      : response;

    const doc = ctx.html.parse(retryResponse.text);
    const items = doc.querySelectorAll('.book-item');

    return ctx.html.collect(items, (item, index) => {
      const titleNode = item.querySelector('.book-title');
      const authorNode = item.querySelector('.book-author');
      const linkNode = item.querySelector('a');

      return createBook({
        id: item.getAttribute('data-id') || String(index),
        title: ctx.html.text(titleNode),
        author: ctx.html.text(authorNode),
        sourceId: ctx.source.id,
        detailUrl: ctx.utils.absoluteUrl(
          SOURCE_HOST,
          linkNode?.getAttribute('href') || '',
        ),
        score: '',
        wordCount: '',
        updateTime: '',
        tags: [],
        extra: {
          fromSearch: true,
          rawSearchIndex: index,
        },
      });
    });
  },

  async detail(ctx, book) {
    const response = await ctx.http.request({
      url: ctx.utils.absoluteUrl(SOURCE_HOST, book.detailUrl),
      method: 'GET',
      timeoutMs: 6000,
    });

    if (ctx.http.isChallenge(response)) {
      await ctx.browser.challenge({
        url: response.url,
        reason: 'detail_captcha',
        timeoutMs: 120000,
      });
    }

    const retryResponse = ctx.http.isChallenge(response)
      ? await ctx.http.request({
          url: ctx.utils.absoluteUrl(SOURCE_HOST, book.detailUrl),
          method: 'GET',
          timeoutMs: 6000,
        })
      : response;

    const doc = ctx.html.parse(retryResponse.text);

    return createBook({
      ...book,
      sourceId: ctx.source.id,
      intro: ctx.html.text(doc.querySelector('.book-intro')),
      cover: ctx.utils.absoluteUrl(
        SOURCE_HOST,
        doc.querySelector('.book-cover img')?.getAttribute('src') || '',
      ),
      status: ctx.html.text(doc.querySelector('.book-status')),
      category: ctx.html.text(doc.querySelector('.book-category')),
      score: ctx.html.text(doc.querySelector('.book-score')),
      wordCount: ctx.html.text(doc.querySelector('.book-words')),
      updateTime: ctx.html.text(doc.querySelector('.book-update-time')),
      tags: ctx.html
        .collect(doc.querySelectorAll('.book-tags .tag'), (node) => ctx.html.text(node))
        .filter(Boolean),
      latestChapter: ctx.html.text(doc.querySelector('.book-latest')),
      extra: {
        ...book.extra,
        catalogUrl: ctx.utils.absoluteUrl(
          SOURCE_HOST,
          doc.querySelector('.book-catalog-link')?.getAttribute('href') || '',
        ),
      },
    });
  },

  async chapters(ctx, book) {
    const response = await ctx.http.request({
      url: book.extra.catalogUrl || ctx.utils.absoluteUrl(SOURCE_HOST, book.detailUrl),
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);
    const chapterNodes = doc.querySelectorAll('.chapter-item a');

    return ctx.html.collect(chapterNodes, (node, index) =>
      createChapter({
        id: node.getAttribute('data-id') || String(index),
        title: ctx.html.text(node),
        sourceId: ctx.source.id,
        url: ctx.utils.absoluteUrl(
          SOURCE_HOST,
          node.getAttribute('href') || '',
        ),
        index,
        updateTime: ctx.html.text(node.parentElement?.querySelector('.chapter-time')),
      }),
    );
  },

  async content(ctx, book, chapter) {
    const response = await ctx.http.request({
      url: chapter.url,
      method: 'GET',
      timeoutMs: 6000,
    });

    if (ctx.http.isChallenge(response)) {
      await ctx.browser.challenge({
        url: response.url,
        reason: 'content_captcha',
        timeoutMs: 120000,
      });
    }

    const retryResponse = ctx.http.isChallenge(response)
      ? await ctx.http.request({
          url: chapter.url,
          method: 'GET',
          timeoutMs: 6000,
        })
      : response;

    const doc = ctx.html.parse(retryResponse.text);
    const contentNode = doc.querySelector('.chapter-content');

    return createContent({
      title: chapter.title,
      content: ctx.html.text(contentNode),
      sourceId: ctx.source.id,
      nextUrl: null,
    });
  },
};
''';
