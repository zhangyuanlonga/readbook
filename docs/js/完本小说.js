const SOURCE_HOST = 'https://www.finalbooks.work';
const DEFAULT_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 9) Mobile Safari/537.36',
};

function createDiscoverCategory(partial = {}) {
  return {
    title: '',
    url: '',
    style: {
      layoutFlexGrow: null,
      layoutFlexBasisPercent: null,
    },
    extra: {},
    debug: {},
    ...partial,
  };
}

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

function requestText(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'text',
    timeoutMs: 15000,
    headers: {
      ...DEFAULT_HEADERS,
      ...(options.headers || {}),
    },
    ...options,
  });
}

function normalizeText(value) {
  return String(value == null ? '' : value).replace(/\s+/g, ' ').trim();
}

function normalizeMultiline(value) {
  return String(value == null ? '' : value)
    .replace(/\r\n?/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function absolute(ctx, url) {
  return String(ctx.utils.absoluteUrl(SOURCE_HOST, url || '') || '');
}

function metaContent(doc, property) {
  return normalizeText(
    doc
      ?.querySelector(`meta[property="${property}"]`)
      ?.getAttribute('content'),
  );
}

function buildPagedUrl(categoryUrl, page) {
  const normalized = String(categoryUrl || '').trim();
  if (!normalized) {
    return normalized;
  }
  if (page <= 1) {
    return normalized;
  }
  if (normalized.endsWith('/')) {
    return `${normalized}${page}.html`;
  }
  return normalized.replace(/(\d+\.html)?$/, `${page}.html`);
}

function parseSearchItem(ctx, node) {
  const bookLink = node.querySelector('a[href^="/book/"]');
  const categoryLink = node.querySelector('a[href^="/category/"]');
  const writerLink = node.querySelector('a[href^="/writer/"]');
  return createBook({
    type: 'novel',
    title: normalizeText(ctx.html.text(bookLink)),
    author: normalizeText(ctx.html.text(writerLink)),
    category: normalizeText(ctx.html.text(categoryLink)),
    detailUrl: absolute(ctx, ctx.html.attr(bookLink, 'href')),
  });
}

function parseDiscoverBook(ctx, unit) {
  const titleNode = unit.querySelector('a.title') || unit.querySelector('span a');
  const authorNode = unit.querySelector('p a[href^="/writer/"]');
  return createBook({
    type: 'novel',
    title: normalizeText(ctx.html.text(titleNode)),
    author: normalizeText(ctx.html.text(authorNode)),
    detailUrl: absolute(ctx, ctx.html.attr(titleNode, 'href')),
  });
}

function extractDecryptionPayload(html) {
  const match = String(html || '').match(/\.html\(d\("([^"]+)",\s*"([^"]+)"\)\)/);
  if (!match) {
    return null;
  }
  return {
    encrypted: match[1],
    seed: match[2],
  };
}

function cleanupContent(html) {
  return normalizeMultiline(
    String(html || '')
      .replace(/<p[^>]*style="color:(orange|blue)[^"]*"[^>]*>[\s\S]*?<\/p>/gi, '')
      .replace(/<p>\s*收藏网址：.*?<\/p>/gi, '')
      .replace(/<p>\s*\(＞人＜；\)\s*<\/p>/gi, '')
      .trim(),
  );
}

async function fetchCatalogPages(ctx, tocUrl) {
  const firstResponse = await requestText(ctx, tocUrl);
  const firstDoc = ctx.html.parse(firstResponse.text);
  const endHref = ctx.html.attr(firstDoc.querySelector('#end'), 'href');
  const match = String(endHref || '').match(/\/catalog\/(\d+)\.html$/);
  const totalPages = match ? Number(match[1]) : 1;
  const pages = [{ url: tocUrl, doc: firstDoc }];

  for (let i = 2; i <= totalPages; i += 1) {
    const url = absolute(ctx, `${tocUrl}${i}.html`);
    const response = await requestText(ctx, url);
    pages.push({
      url,
      doc: ctx.html.parse(response.text),
    });
  }

  return pages;
}

export default {
  meta: {
    name: '完本小说',
    group: '🌞',
    author: 'converted_from_test_json',
    description: '由旧规则转换的完本小说脚本源。',
    checkKeyword: '凡人修仙传',
    domains: ['www.finalbooks.work'],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'www.finalbooks.work': {
        minIntervalMs: 600,
      },
    },
  },

  async discoverCategories(ctx) {
    const response = await requestText(ctx, `${SOURCE_HOST}/category/`);
    const doc = ctx.html.parse(response.text);
    const nodes = doc.querySelectorAll('.CGsectionTwo-left a');
    const seen = new Set();
    const categories = [];

    for (const node of nodes) {
      const title = normalizeText(ctx.html.text(node));
      const href = absolute(ctx, ctx.html.attr(node, 'href'));
      if (!title || !href || seen.has(href)) {
        continue;
      }
      seen.add(href);
      categories.push(
        createDiscoverCategory({
          title,
          url: href,
          extra: {
            route: 'category',
          },
        }),
      );
    }

    return categories;
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const url = buildPagedUrl(category.url, page);
    const response = await requestText(ctx, url);
    const doc = ctx.html.parse(response.text);
    const units = doc.querySelectorAll('.CGsectionTwo-right-content-unit');
    return ctx.html.collect(units, (unit) => parseDiscoverBook(ctx, unit));
  },

  async search(ctx, keyword) {
    const response = await requestText(
      ctx,
      `${SOURCE_HOST}/search/${encodeURIComponent(keyword)}/1`,
    );
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.SHsectionThree-middle > p');
    return ctx.html.collect(items, (item) => parseSearchItem(ctx, item));
  },

  async detail(ctx, book) {
    const response = await requestText(ctx, book.detailUrl);
    const doc = ctx.html.parse(response.text);
    const tocHref =
      ctx.html.attr(
        doc.querySelector('.BGsectionOne-bottom a[href*="/catalog/"]'),
        'href',
      ) || `${book.detailUrl.replace(/\/$/, '')}/catalog/`;
    const categoryText = normalizeText(ctx.html.text(doc.querySelector('.category')))
      .replace(/^类别：/, '')
      .replace(/\/\s*排行榜/g, '')
      .trim();

    return createBook({
      ...book,
      title: metaContent(doc, 'og:novel:book_name') || book.title,
      author: metaContent(doc, 'og:novel:author') || book.author,
      cover:
        metaContent(doc, 'og:image') ||
        absolute(ctx, ctx.html.attr(doc.querySelector('.BGsectionOne-top-left img'), '_src')) ||
        book.cover,
      intro:
        normalizeMultiline(ctx.html.text(doc.querySelector('.BGsectionTwo-bottom'))) ||
        metaContent(doc, 'og:description') ||
        book.intro,
      status: metaContent(doc, 'og:novel:status') || book.status,
      category: categoryText || metaContent(doc, 'og:novel:category') || book.category,
      updateTime: metaContent(doc, 'og:novel:update_time') || book.updateTime,
      latestChapter:
        normalizeText(ctx.html.text(doc.querySelector('.newestChapter a'))) ||
        metaContent(doc, 'og:novel:lastest_chapter_name') ||
        book.latestChapter,
      tocUrl: absolute(ctx, tocHref),
    });
  },

  async chapters(ctx, book) {
    const pages = await fetchCatalogPages(ctx, book.tocUrl);
    const chapters = [];
    const seen = new Set();

    for (const page of pages) {
      const nodes = page.doc.querySelectorAll('li.BCsectionTwo-top-chapter');
      const sorted = Array.from(nodes).sort(
        (a, b) =>
          Number(a.getAttribute('data-tmd') || 0) -
          Number(b.getAttribute('data-tmd') || 0),
      );

      for (const node of sorted) {
        const link = node.querySelector('a');
        const title = normalizeText(link?.getAttribute('data-gldd') || ctx.html.text(link));
        const encodedUrl = normalizeText(link?.getAttribute('data-sdlv'));
        const decodedUrl = encodedUrl ? ctx.utils.base64Decode(encodedUrl) : '';
        const url = absolute(ctx, decodedUrl || ctx.html.attr(link, 'href'));
        if (!title || !url || seen.has(url)) {
          continue;
        }
        seen.add(url);
        chapters.push(
          createChapter({
            title,
            url,
          }),
        );
      }
    }

    return chapters;
  },

  async content(ctx, book, chapter) {
    const response = await requestText(ctx, chapter.url, {
      headers: {
        Referer: book.tocUrl || book.detailUrl || `${SOURCE_HOST}/`,
      },
    });
    const payload = extractDecryptionPayload(response.text);
    let content = '';

    if (payload) {
      const fullKey = ctx.crypto.md5(payload.seed);
      const iv = fullKey.slice(0, 16);
      const key = fullKey.slice(16);
      content = ctx.crypto.aesDecrypt({
        data: payload.encrypted,
        key,
        iv,
        mode: 'cbc',
        inputEncoding: 'base64',
        keyEncoding: 'utf8',
        ivEncoding: 'utf8',
        outputEncoding: 'utf8',
      });
    }

    if (!content) {
      const doc = ctx.html.parse(response.text);
      content = ctx.html.innerHtml(doc.querySelector('.RBGsectionThree-content'));
    }

    const doc = ctx.html.parse(response.text);
    return createContent({
      title: normalizeText(ctx.html.text(doc.querySelector('#chapterTitle'))) || chapter.title,
      content: cleanupContent(content),
    });
  },
};
