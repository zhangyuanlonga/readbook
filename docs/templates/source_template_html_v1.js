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
    name: 'HTML 站点模板',
    group: '默认分组',
    author: 'your_name',
    description: '适合传统 HTML 搜索/详情/目录/正文站点。',
    domains: ['www.example.com'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },

  async init(ctx, task) {},

  async search(ctx, keyword) {
    const response = await ctx.http.request({
      url: `${SOURCE_HOST}/search`,
      method: 'GET',
      query: {
        q: keyword,
      },
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.search-item');

    return ctx.html.collect(items, (item, index) =>
      createBook({
        title: ctx.html.text(item.querySelector('.title')),
        author: ctx.html.text(item.querySelector('.author')),
        detailUrl: ctx.utils.absoluteUrl(
          SOURCE_HOST,
          item.querySelector('a')?.getAttribute('href') || '',
        ),
        sourceId: ctx.source.id,
      }),
    );
  },

  async detail(ctx, book) {
    const response = await ctx.http.request({
      url: book.detailUrl,
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);

    return createBook({
      ...book,
      intro: ctx.html.text(doc.querySelector('.book-intro')),
      cover: ctx.utils.absoluteUrl(
        book.detailUrl,
        doc.querySelector('.book-cover img')?.getAttribute('src') || '',
      ),
      status: ctx.html.text(doc.querySelector('.book-status')),
      category: ctx.html.text(doc.querySelector('.book-category')),
      latestChapter: ctx.html.text(doc.querySelector('.book-latest')),
      sourceId: ctx.source.id,
      extra: {
        ...book.extra,
        catalogUrl: ctx.utils.absoluteUrl(
          book.detailUrl,
          doc.querySelector('.book-catalog-link')?.getAttribute('href') || '',
        ),
      },
    });
  },

  async chapters(ctx, book) {
    const response = await ctx.http.request({
      url: book.extra.catalogUrl || book.detailUrl,
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);
    const chapterNodes = doc.querySelectorAll('.chapter-list a');

    return ctx.html.collect(chapterNodes, (node, index) =>
      createChapter({
        title: ctx.html.text(node),
        url: ctx.utils.absoluteUrl(
          book.detailUrl,
          node.getAttribute('href') || '',
        ),
        index,
        sourceId: ctx.source.id,
      }),
    );
  },

  async content(ctx, book, chapter) {
    const response = await ctx.http.request({
      url: chapter.url,
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);

    return createContent({
      title: chapter.title,
      content: ctx.html.text(doc.querySelector('.chapter-content')),
      sourceId: ctx.source.id,
    });
  },
};
