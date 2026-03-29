const SOURCE_HOST = 'https://www.example.com';
const API_HOST = 'https://api.example.com';

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

function requestJson(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    timeoutMs: 6000,
    ...options,
  });
}

function authHeaders(ctx) {
  const token = ctx.session.get('bootstrapToken');
  if (!token) {
    return {};
  }
  return {
    Authorization: `Bearer ${token}`,
  };
}

// 这类接口通常会返回 bookId / chapterId。
// 建议把后续请求真正要用的参数放进 extra，而不是强依赖 Book.id / Chapter.id。

export default {
  meta: {
    name: 'JSON API 模板',
    group: '默认分组',
    author: 'your_name',
    description: '适合以 JSON 接口为主的站点。',
    domains: ['www.example.com', 'api.example.com'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
    rateLimits: {
      'api.example.com': {
        minIntervalMs: 300,
      },
    },
  },

  async init(ctx, task) {
    if (ctx.session.get('bootstrapToken')) {
      return;
    }

    const bootstrap = await requestJson(ctx, `${API_HOST}/bootstrap`);
    const token = bootstrap.json?.data?.token || bootstrap.json?.token;

    if (token) {
      ctx.session.set('bootstrapToken', token);
    }
  },

  async search(ctx, keyword) {
    const response = await requestJson(ctx, `${API_HOST}/search`, {
      query: {
        keyword,
      },
      headers: authHeaders(ctx),
    });

    const list = response.json?.data?.list || response.json?.list || [];

    return list.map((item, index) =>
      createBook({
        title: item.title || item.name || '',
        author: item.author || '',
        cover: item.cover || '',
        intro: item.intro || '',
        detailUrl: item.detailUrl
          ? ctx.utils.absoluteUrl(SOURCE_HOST, item.detailUrl)
          : `${SOURCE_HOST}/book/${item.id || item.bookId || index}`,
        sourceId: ctx.source.id,
        extra: {
          bookId: String(item.id || item.bookId || index),
        },
      }),
    );
  },

  async detail(ctx, book) {
    const response = await requestJson(
      ctx,
      `${API_HOST}/book/detail`,
      {
        query: {
          id: book.extra.bookId || book.id,
        },
        headers: authHeaders(ctx),
      },
    );

    const item = response.json?.data || response.json || {};

    return createBook({
      ...book,
      title: item.title || item.name || book.title,
      author: item.author || book.author,
      cover: item.cover || book.cover,
      intro: item.intro || book.intro,
      status: item.status || '',
      category: item.category || '',
      score: item.score ? String(item.score) : '',
      wordCount: item.wordCount ? String(item.wordCount) : '',
      updateTime: item.updateTime || '',
      latestChapter: item.latestChapter || '',
      sourceId: ctx.source.id,
      extra: {
        ...book.extra,
        bookId: String(item.id || item.bookId || book.extra.bookId || book.id),
      },
    });
  },

  async chapters(ctx, book) {
    const response = await requestJson(
      ctx,
      `${API_HOST}/book/chapters`,
      {
        query: {
          id: book.extra.bookId || book.id,
        },
        headers: authHeaders(ctx),
      },
    );

    const list = response.json?.data?.chapters || response.json?.chapters || [];

    return list.map((item, index) =>
      createChapter({
        title: item.title || '',
        url: item.url || `${API_HOST}/chapter/content?id=${item.id || item.chapterId || index}`,
        index,
        updateTime: item.updateTime || '',
        sourceId: ctx.source.id,
        extra: {
          chapterId: String(item.id || item.chapterId || index),
        },
      }),
    );
  },

  async content(ctx, book, chapter) {
    const response = await requestJson(
      ctx,
      `${API_HOST}/chapter/content`,
      {
        query: {
          id: chapter.extra.chapterId || chapter.id,
        },
        headers: authHeaders(ctx),
      },
    );

    const item = response.json?.data || response.json || {};

    return createContent({
      title: item.title || chapter.title,
      content: ctx.utils.normalizeText(item.content || ''),
      sourceId: ctx.source.id,
      nextUrl: item.nextUrl || null,
    });
  },
};
