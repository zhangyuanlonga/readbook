const SOURCE_HOST = 'https://www.sudugu.org';
const SEARCH_REFERER = 'https://www.sudugu.org/i/so.aspx';
const REQUEST_TIMEOUT = 180000;

const DEFAULT_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
  Accept:
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
  'accept-language': 'zh-CN,zh;q=0.9',
};

function createBook(partial = {}) {
  return {
    type: 'novel',
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
    tocUrl: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

function createChapter(partial = {}) {
  return {
    title: '',
    url: '',
    isVolume: false,
    isVip: false,
    isPay: false,
    updateTime: '',
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
    extra: {},
    debug: {},
    ...partial,
  };
}

function absoluteUrl(url) {
  return ctx.utils.absoluteUrl(SOURCE_HOST, url || '');
}

async function requestText(ctx, url, { referer = SOURCE_HOST } = {}) {
  return await ctx.http.request({
    url,
    method: 'GET',
    headers: {
      ...DEFAULT_HEADERS,
      referer,
    },
    timeoutMs: REQUEST_TIMEOUT,
    responseType: 'text',
  });
}

function cleanText(value) {
  return ctx.utils.normalizeText(value || '');
}

function textOf(node, selector) {
  return cleanText(ctx.html.text(node?.querySelector(selector)));
}

function attrOf(node, selector, attr) {
  return cleanText(node?.querySelector(selector)?.getAttribute(attr));
}

function parseSearchBooks(ctx, doc) {
  const items = doc.querySelectorAll('.item');

  return ctx.html.collect(items, (item) =>
    createBook({
      title: textOf(item, 'h3 > a'),
      author: textOf(item, 'p > a'),
      cover: absoluteUrl(attrOf(item, 'img', 'src')),
      intro: textOf(item, 'li:nth-child(1) > a'),
      category: textOf(item, 'span'),
      latestChapter: textOf(item, 'li:nth-child(1) > a'),
      detailUrl: absoluteUrl(attrOf(item, 'h3 > a', 'href')),
      extra: {
        searchIntro: textOf(item, 'li:nth-child(1) > a'),
      },
    }),
  ).filter((book) => book.title && book.detailUrl);
}

async function fetchChapterPage(ctx, url, visited = new Set()) {
  const targetUrl = absoluteUrl(url);
  if (!targetUrl || visited.has(targetUrl)) {
    return [];
  }
  visited.add(targetUrl);

  const response = await requestText(ctx, targetUrl, { referer: targetUrl });
  const doc = ctx.html.parse(response.text || '');
  const items = doc.querySelectorAll('#list li');

  const chapters = ctx.html.collect(items, (item) => {
    const link = item.querySelector('a');
    const title = cleanText(ctx.html.text(link));
    const href = cleanText(link?.getAttribute('href'));
    if (!title || !href) {
      return null;
    }
    return createChapter({
      title,
      url: absoluteUrl(href),
    });
  }).filter(Boolean);

  const nextHref = cleanText(attrOf(doc, '#pages > .gr', 'href'));
  if (!nextHref) {
    return chapters;
  }

  const more = await fetchChapterPage(ctx, nextHref, visited);
  return [...chapters, ...more];
}

async function fetchContentPages(ctx, url, chapterTitle, visited = new Set()) {
  const targetUrl = absoluteUrl(url);
  if (!targetUrl || visited.has(targetUrl)) {
    return { content: '', nextUrl: null };
  }
  visited.add(targetUrl);

  const response = await requestText(ctx, targetUrl, { referer: targetUrl });
  const doc = ctx.html.parse(response.text || '');

  const paragraphs = doc
    .querySelectorAll('.con > p')
    .map((node) => cleanText(ctx.html.text(node)))
    .filter(Boolean);

  let text = paragraphs.join('\n\n');
  if (chapterTitle) {
    text = text.replace(chapterTitle, '');
  }
  text = text.replace(/\(本章完\)/g, '').trim();

  const nextHref = cleanText(
    attrOf(doc, 'div.prenext > span:nth-child(3) > a', 'href'),
  );
  const nextUrl = absoluteUrl(nextHref);

  if (!nextHref || !nextUrl || visited.has(nextUrl)) {
    return {
      content: text,
      nextUrl: null,
    };
  }

  const nextResult = await fetchContentPages(
    ctx,
    nextUrl,
    chapterTitle,
    visited,
  );

  return {
    content: [text, nextResult.content].filter(Boolean).join('\n\n'),
    nextUrl: nextResult.nextUrl,
  };
}

export default {
  meta: {
    name: '🌐 速读谷',
    group: '起点',
    author: 'converted',
    description: '从 Legado 规则转换的 JS 书源。',
    domains: ['www.sudugu.org', 'sudugu.org'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
    rateLimits: {
      'www.sudugu.org': {
        minIntervalMs: 1000,
      },
      'sudugu.org': {
        minIntervalMs: 1000,
      },
    },
  },

  async search(ctx, keyword) {
    const response = await requestText(
      ctx,
      `${SOURCE_HOST}/i/sor.aspx?key=${ctx.utils.encodeUriComponent(keyword)}`,
      { referer: SEARCH_REFERER },
    );
    const doc = ctx.html.parse(response.text || '');
    return parseSearchBooks(ctx, doc);
  },

  async detail(ctx, book) {
    const response = await requestText(ctx, book.detailUrl, {
      referer: SEARCH_REFERER,
    });
    const doc = ctx.html.parse(response.text || '');

    const title = textOf(doc, 'h1 > a') || book.title;
    const author = textOf(doc, 'p:nth-child(3) > a') || book.author;
    const cover = absoluteUrl(attrOf(doc, '.item img', 'src')) || book.cover;
    const intro = textOf(doc, '.des:nth-child(3)') || book.intro;
    const category = textOf(doc, 'p > span') || book.category;
    const latestChapter =
      textOf(doc, 'li:nth-child(1) > a:nth-child(2)') || book.latestChapter;
    const wordCount = textOf(doc, 'h1 > i') || book.wordCount;

    return createBook({
      ...book,
      title,
      author,
      cover,
      intro,
      category,
      latestChapter,
      wordCount,
      detailUrl: absoluteUrl(book.detailUrl),
      tocUrl: absoluteUrl(book.detailUrl),
    });
  },

  async chapters(ctx, book) {
    const tocUrl = book.tocUrl || book.detailUrl;
    const chapters = await fetchChapterPage(ctx, tocUrl);
    return chapters.map((chapter, index) =>
      createChapter({
        ...chapter,
        extra: {
          ...chapter.extra,
          index,
        },
      }),
    );
  },

  async content(ctx, book, chapter) {
    const result = await fetchContentPages(ctx, chapter.url, chapter.title);
    return createContent({
      title: chapter.title,
      content: result.content,
      nextUrl: result.nextUrl,
    });
  },
};