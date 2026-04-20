const SOURCE_HOST = 'https://www.dabaipc.com';
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

function createPagedPattern(href) {
  const value = String(href || '').trim();
  if (!value) {
    return '';
  }
  if (/\/list\/[^/]+\/1\/$/.test(value)) {
    return value.replace(/\/1\/$/, '/{{page}}/');
  }
  if (value === '/quanben/list/') {
    return '/quanben/list/{{page}}/';
  }
  if (value === '/rank/allvisit/') {
    return '/rank/allvisit/';
  }
  return value;
}

function buildPagedUrl(pattern, page) {
  const value = String(pattern || '').trim();
  if (!value) {
    return value;
  }
  if (value.includes('{{page}}')) {
    return value.replace(/{{page}}/g, String(page));
  }
  if (page <= 1) {
    return value;
  }
  if (value.endsWith('/')) {
    return `${value}${page}/`;
  }
  return value;
}

function parseBookCard(ctx, item) {
  const titleNode = item.querySelector('dt a') || item.querySelector('.s2 a') || item.querySelector('a[href^="/book/"]');
  const coverNode = item.querySelector('img');
  const authorNode = item.querySelector('.btm a') || item.querySelector('.s5') || item.querySelector('a[href^="/author/"]');
  const metaText = normalizeText(ctx.html.text(item.querySelector('.hidden-xs') || item.querySelector('.btm') || item.querySelector('em:last-child')));
  const wordCount = normalizeText(metaText.match(/(\d+\s*万字)/)?.[1]);
  const updateTime = normalizeText(metaText.match(/(\d{4}-\d{2}-\d{2}|\d+天前|\d+个月前)/)?.[1]);

  return createBook({
    type: 'novel',
    title: normalizeText(ctx.html.text(titleNode)),
    author: normalizeText(ctx.html.text(authorNode)),
    cover:
      absolute(
        ctx,
        ctx.html.attr(coverNode, 'data-original') || ctx.html.attr(coverNode, 'src'),
      ) || '',
    intro: normalizeText(ctx.html.text(item.querySelector('dd'))),
    category:
      normalizeText(ctx.html.text(item.querySelector('.s1'))) ||
      normalizeText(ctx.html.text(item.querySelector('.visible-xs .orange'))) ||
      '',
    wordCount,
    updateTime,
    detailUrl: absolute(ctx, ctx.html.attr(titleNode, 'href')),
  });
}

function chapterBaseKey(url) {
  return String(url || '').replace(/(_\d+)?\.html(?:[?#].*)?$/, '');
}

function cleanContentHtml(html) {
  return normalizeMultiline(
    String(html || '')
      .replace(/<p[^>]*style="color:\s*red;?[^"]*"[^>]*>[\s\S]*?<\/p>/gi, '')
      .replace(/<p>\s*本章未完，点击下一页继续阅读。?\s*<\/p>/gi, '')
      .trim(),
  );
}

async function fetchChapterPages(ctx, startUrl) {
  const visited = new Set();
  const parts = [];
  const baseKey = chapterBaseKey(startUrl);
  let currentUrl = startUrl;

  while (currentUrl && !visited.has(currentUrl)) {
    visited.add(currentUrl);
    const response = await requestText(ctx, currentUrl, {
      headers: {
        Referer: SOURCE_HOST,
      },
    });
    const doc = ctx.html.parse(response.text);
    const html = ctx.html.innerHtml(doc.querySelector('#booktxt'));
    if (html) {
      parts.push(cleanContentHtml(html));
    }

    const rawNext =
      ctx.html.attr(doc.querySelector('#next_url'), 'href') ||
      ctx.html.attr(doc.querySelector('a[rel="next"]'), 'href');
    const nextUrl = absolute(ctx, rawNext);
    if (!nextUrl || chapterBaseKey(nextUrl) !== baseKey || nextUrl === currentUrl) {
      break;
    }
    currentUrl = nextUrl;
  }

  return parts.join('\n');
}

async function fetchIndexPages(ctx, tocUrl) {
  const firstResponse = await requestText(ctx, tocUrl);
  const firstDoc = ctx.html.parse(firstResponse.text);
  const optionNodes = firstDoc.querySelectorAll('#indexselect option');
  const urls = [];
  const seen = new Set();

  for (const option of optionNodes) {
    const url = absolute(ctx, ctx.html.attr(option, 'value'));
    if (!url || seen.has(url)) {
      continue;
    }
    seen.add(url);
    urls.push(url);
  }

  if (urls.length === 0) {
    urls.push(tocUrl);
  }

  return urls;
}

export default {
  meta: {
    name: '大白小说',
    group: '🌞',
    author: 'converted_from_test_json',
    description: '由旧规则转换的大白小说脚本源。',
    checkKeyword: '剑来',
    domains: ['www.dabaipc.com', 'img.dabaipc.com'],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'www.dabaipc.com': {
        minIntervalMs: 500,
      },
    },
  },

  async discoverCategories(ctx) {
    const response = await requestText(ctx, `${SOURCE_HOST}/`);
    const doc = ctx.html.parse(response.text);
    const navNodes = doc.querySelectorAll('.nav li a');
    const categories = [];
    const seen = new Set();

    for (const node of navNodes) {
      const title = normalizeText(ctx.html.text(node));
      const href = ctx.html.attr(node, 'href');
      if (!title || title === '首页' || title === '记录') {
        continue;
      }
      const pattern = createPagedPattern(href);
      const url = absolute(ctx, buildPagedUrl(pattern, 1));
      if (!url || seen.has(url)) {
        continue;
      }
      seen.add(url);
      categories.push(
        createDiscoverCategory({
          title,
          url,
          extra: {
            urlPattern: pattern,
          },
        }),
      );
    }

    return categories;
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const pattern = category.extra?.urlPattern || category.url || '';
    const url = absolute(ctx, buildPagedUrl(pattern, page));
    const response = await requestText(ctx, url);
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.item, .l li');
    return ctx.html.collect(items, (item) => parseBookCard(ctx, item));
  },

  async search(ctx, keyword) {
    const response = await requestText(
      ctx,
      `${SOURCE_HOST}/search06.html?searchkey=${encodeURIComponent(keyword)}`,
    );
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.item');
    return ctx.html.collect(items, (item) => parseBookCard(ctx, item));
  },

  async detail(ctx, book) {
    const response = await requestText(ctx, book.detailUrl);
    const doc = ctx.html.parse(response.text);
    const tocHref =
      ctx.html.attr(doc.querySelector('.readbtn a.chapterlist'), 'href') ||
      '';
    const wordCount = normalizeText(
      ctx.html
        .text(doc.querySelector('#info'))
        .match(/(\d+\s*万字)/)?.[1],
    );
    const updateTime =
      metaContent(doc, 'og:novel:update_time') ||
      normalizeText(ctx.html.text(doc.querySelector('#info')).match(/最后更新[:：]?\s*([^\s].*)$/m)?.[1]);

    return createBook({
      ...book,
      title: metaContent(doc, 'og:novel:book_name') || book.title,
      author: metaContent(doc, 'og:novel:author') || book.author,
      cover:
        metaContent(doc, 'og:image') ||
        absolute(
          ctx,
          ctx.html.attr(doc.querySelector('#fmimg img'), 'data-original') ||
            ctx.html.attr(doc.querySelector('#fmimg img'), 'src'),
        ) ||
        book.cover,
      intro:
        normalizeMultiline(ctx.html.text(doc.querySelector('#intro'))) ||
        metaContent(doc, 'og:description') ||
        book.intro,
      status: metaContent(doc, 'og:novel:status') || book.status,
      category: metaContent(doc, 'og:novel:category') || book.category,
      wordCount: wordCount || book.wordCount,
      updateTime: updateTime || book.updateTime,
      latestChapter:
        metaContent(doc, 'og:novel:latest_chapter_name') ||
        normalizeText(ctx.html.text(doc.querySelector('.lastchapter a'))) ||
        book.latestChapter,
      tocUrl: absolute(ctx, tocHref),
    });
  },

  async chapters(ctx, book) {
    const tocUrl = book.tocUrl || book.detailUrl;
    const pageUrls = await fetchIndexPages(ctx, tocUrl);
    const chapters = [];
    const seen = new Set();

    for (const pageUrl of pageUrls) {
      const response = await requestText(ctx, pageUrl);
      const doc = ctx.html.parse(response.text);
      const nodes = doc.querySelectorAll('#content_1 a[rel="chapter"], #list a[rel="chapter"]');

      for (const node of nodes) {
        const url = absolute(ctx, ctx.html.attr(node, 'href'));
        const title = normalizeText(ctx.html.text(node));
        if (!url || !title || seen.has(url)) {
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
    const content = await fetchChapterPages(ctx, chapter.url);
    return createContent({
      title: chapter.title,
      content,
    });
  },
};
