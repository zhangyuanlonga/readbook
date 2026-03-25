const SOURCE_HOST = 'https://www.example.com';

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

    if (book.extra.forceBrowserContent === true) {
      const browserResult = await ctx.browser.eval({
        url: chapter.url,
        script: `
          const title = document.querySelector('.chapter-title')?.innerText || '';
          const content = document.querySelector('.chapter-content')?.innerText || '';
          return { title, content };
        `,
        timeoutMs: 10000,
      });

      return createContent({
        title: browserResult.title || chapter.title,
        content: browserResult.content || '',
        sourceId: ctx.source.id,
      });
    }

    const doc = ctx.html.parse(retryResponse.text);
    return createContent({
      title: ctx.html.text(doc.querySelector('.chapter-title')) || chapter.title,
      content: ctx.html.text(doc.querySelector('.chapter-content')),
      sourceId: ctx.source.id,
    });
  },
};
