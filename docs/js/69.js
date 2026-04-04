const SOURCE_HOST = 'https://www.69hao.com';
const REQUEST_TIMEOUT = 180000;

const DEFAULT_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 15; V2403A Build/AP3A.240905.015.A1; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.6478.71 Mobile Safari/537.36',
  'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7,en-GB;q=0.6',
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

function absoluteUrl(url) {
  return ctx.utils.absoluteUrl(SOURCE_HOST, url || '');
}

async function requestText(
  ctx,
  url,
  {
    method = 'GET',
    headers = {},
    query = {},
    body,
    bodyType = 'auto',
    referer = SOURCE_HOST,
  } = {},
) {
  return await ctx.http.request({
    url,
    method,
    headers: {
      ...DEFAULT_HEADERS,
      referer,
      ...headers,
    },
    query,
    body,
    bodyType,
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

function metaContent(doc, property) {
  return cleanText(
    doc
      ?.querySelector(`meta[property="${property}"]`)
      ?.getAttribute('content'),
  );
}

function isVerificationPage(html) {
  return cleanText(html).includes('请输入验证码') &&
    cleanText(html).includes('modal-code');
}

function extractVerificationCode(html) {
  const match = String(html || '').match(
    /class=["']modal-code["'][^>]*>\s*([^<\s]+)\s*</i,
  );
  return cleanText(match?.[1] || '');
}

function extractBookTextHtml(html) {
  const match = String(html || '').match(
    /<div id=["']booktxt["'][^>]*>([\s\S]*?)<\/div>/i,
  );
  return match?.[1] || '';
}

function parseBookCards(ctx, doc, fallback = {}) {
  const items = doc.querySelectorAll('.item');

  return ctx.html
    .collect(items, (item, index) => {
      const title = textOf(item, 'dt > a') || textOf(item, 'a[title]');
      const detailUrl = absoluteUrl(
        attrOf(item, 'dt > a', 'href') || attrOf(item, 'a[title]', 'href'),
      );
      if (!title || !detailUrl) {
        return null;
      }

      return createBook({
        title,
        author: textOf(item, '.btm > a'),
        cover: absoluteUrl(attrOf(item, 'img', 'data-original')),
        intro: textOf(item, 'dd'),
        category: fallback.category || '',
        wordCount: textOf(item, '.btm > em.orange'),
        updateTime: textOf(item, '.btm > em.blue'),
        latestChapter: '',
        detailUrl,
        tocUrl: detailUrl,
        extra: {
          ...fallback.extra,
          rawListIndex: index,
        },
      });
    })
    .filter(Boolean);
}

async function searchWithVerification(ctx, keyword) {
  const url = `${SOURCE_HOST}/ss/?searchkey=${ctx.utils.encodeUriComponent(keyword)}`;

  let response = await requestText(ctx, url, { referer: SOURCE_HOST });
  if (!isVerificationPage(response.text || '')) {
    return response;
  }

  for (let attempt = 0; attempt < 2; attempt += 1) {
    const code = extractVerificationCode(response.text || '');
    if (!code) {
      break;
    }

    response = await requestText(ctx, url, {
      method: 'POST',
      referer: url,
      bodyType: 'form',
      body: {
        verifycode: code,
      },
    });

    if (!isVerificationPage(response.text || '')) {
      return response;
    }
  }

  return response;
}

function extractBookId(url) {
  const match = String(url || '').match(/\/(\d+)\/?(?:[#?].*)?$/);
  return cleanText(match?.[1] || '');
}

function buildChapterSeriesKey(url) {
  const match = String(url || '').match(/^(.*?\/\d+)(?:_\d+)?\.html(?:[#?].*)?$/);
  return cleanText(match?.[1] || '');
}

async function fetchPagedContent(ctx, url, chapterTitle, visited = new Set()) {
  const targetUrl = absoluteUrl(url);
  if (!targetUrl || visited.has(targetUrl)) {
    return { content: '', nextUrl: null };
  }
  visited.add(targetUrl);

  const response = await requestText(ctx, targetUrl, { referer: targetUrl });
  const doc = ctx.html.parse(response.text || '');
  const contentNode = doc.querySelector('#booktxt');

  let text = ctx.html
    .collect(contentNode?.querySelectorAll('p') || [], (node) => ctx.html.text(node))
    .map((value) => cleanText(value))
    .filter(Boolean)
    .join('\n\n');

  if (!text) {
    text = cleanText(ctx.utils.htmlFormat(extractBookTextHtml(response.text || '')));
  }

  const nextHref = cleanText(attrOf(doc, '#next_url', 'href'));
  const nextLabel = textOf(doc, '#next_url');
  const nextUrl = absoluteUrl(nextHref);
  const currentSeriesKey = buildChapterSeriesKey(targetUrl);
  const nextSeriesKey = buildChapterSeriesKey(nextUrl);

  if (
    nextUrl &&
    nextLabel.includes('下一页') &&
    currentSeriesKey &&
    currentSeriesKey === nextSeriesKey &&
    !visited.has(nextUrl)
  ) {
    const nextResult = await fetchPagedContent(ctx, nextUrl, chapterTitle, visited);
    return {
      content: [text, nextResult.content].filter(Boolean).join('\n\n'),
      nextUrl: nextResult.nextUrl,
    };
  }

  return {
    content: text,
    nextUrl: nextUrl || null,
  };
}

function categoryPageUrl(category, page) {
  const template = cleanText(category?.extra?.pageTemplate || '');
  if (template) {
    return template.replace('{{page}}', String(page));
  }

  const baseUrl = cleanText(category?.url || '');
  if (!baseUrl) {
    return '';
  }

  if (page <= 1) {
    return baseUrl;
  }

  if (/_\d+\.html$/.test(baseUrl)) {
    return baseUrl.replace(/_(\d+)\.html$/, `_${page}.html`);
  }

  return '';
}

export default {
  meta: {
    name: '🌐 69书吧',
    group: '网页',
    author: 'converted',
    description: '从阅读 3.0 规则迁移的 69 书吧脚本源。',
    domains: ['www.69hao.com', '69hao.com'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'www.69hao.com': {
        minIntervalMs: 1000,
      },
      '69hao.com': {
        minIntervalMs: 1000,
      },
    },
  },

  async discoverCategories(ctx) {
    const response = await requestText(ctx, SOURCE_HOST, {
      referer: SOURCE_HOST,
    });
    const doc = ctx.html.parse(response.text || '');

    const categories = [
      createDiscoverCategory({
        title: '全部分类',
        url: SOURCE_HOST,
        style: {
          layoutFlexGrow: 1,
          layoutFlexBasisPercent: 100,
        },
      }),
    ];

    const navLinks = doc.querySelectorAll('.nav a');
    const seen = new Set([SOURCE_HOST]);

    const parsed = ctx.html.collect(navLinks, (node) => {
      const title = cleanText(ctx.html.text(node));
      const href = absoluteUrl(node.getAttribute('href') || '');
      if (!title || !href || seen.has(href)) {
        return null;
      }

      const isCategoryPage = href.includes('/class/');
      const isHotPage = href.includes('/rank/allvisit/');
      if (!isCategoryPage && !isHotPage) {
        return null;
      }
      seen.add(href);

      return createDiscoverCategory({
        title,
        url: href,
        style: {
          layoutFlexGrow: 1,
          layoutFlexBasisPercent: 33.3,
        },
        extra: {
          pageTemplate: isCategoryPage
            ? href.replace(/_(\d+)\.html$/, '_{{page}}.html')
            : '',
        },
      });
    }).filter(Boolean);

    return [...categories, ...parsed];
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const url = categoryPageUrl(category, page);
    if (!url) {
      return [];
    }

    const response = await requestText(ctx, url, { referer: SOURCE_HOST });
    const doc = ctx.html.parse(response.text || '');

    return parseBookCards(ctx, doc, {
      category: category.title === '全部分类' ? '' : category.title,
      extra: {
        discoverCategoryTitle: category.title,
        discoverPage: page,
        discoverPageSize: pageSize,
      },
    });
  },

  async search(ctx, keyword) {
    ctx.cookie.clearDomain('www.69hao.com');
    ctx.cookie.clearDomain('69hao.com');

    const response = await searchWithVerification(ctx, keyword);
    const doc = ctx.html.parse(response.text || '');
    return parseBookCards(ctx, doc, {
      extra: {
        keyword,
      },
    });
  },

  async detail(ctx, book) {
    const detailUrl = absoluteUrl(book.detailUrl);
    const response = await requestText(ctx, detailUrl, {
      referer: SOURCE_HOST,
    });
    const doc = ctx.html.parse(response.text || '');

    const title = metaContent(doc, 'og:novel:book_name') || cleanText(book.title);
    const author = metaContent(doc, 'og:novel:author') || cleanText(book.author);
    const category = metaContent(doc, 'og:novel:category') || cleanText(book.category);
    const status = metaContent(doc, 'og:novel:status') || textOf(doc, '#info p:nth-child(3)');
    const intro = metaContent(doc, 'og:description') || cleanText(ctx.html.text(doc.querySelector('#intro')));
    const cover = metaContent(doc, 'og:image') || absoluteUrl(attrOf(doc, '#fmimg img', 'data-original'));
    const latestChapter =
      metaContent(doc, 'og:novel:latest_chapter_name') ||
      textOf(doc, '#info p:nth-child(4) a');
    const updateTime =
      metaContent(doc, 'og:novel:update_time') ||
      cleanText(textOf(doc, '#info p:nth-child(5)').replace(/^最后更新：/, ''));

    return createBook({
      ...book,
      title,
      author,
      cover,
      intro,
      status: cleanText(String(status).replace(/^状态：/, '')),
      category,
      wordCount: book.wordCount || '',
      updateTime,
      latestChapter,
      detailUrl,
      tocUrl: absoluteUrl(metaContent(doc, 'og:novel:read_url') || detailUrl),
      extra: {
        ...book.extra,
        bookId: extractBookId(detailUrl),
      },
    });
  },

  async chapters(ctx, book) {
    const tocUrl = absoluteUrl(book.tocUrl || book.detailUrl);
    const response = await requestText(ctx, tocUrl, {
      referer: tocUrl,
    });
    const doc = ctx.html.parse(response.text || '');
    const chapterNodes = doc.querySelectorAll('#list a[rel="chapter"]');

    return ctx.html
      .collect(chapterNodes, (node, index) => {
        const title = cleanText(ctx.html.text(node));
        const url = absoluteUrl(node.getAttribute('href') || '');
        if (!title || !url) {
          return null;
        }

        return createChapter({
          title,
          url,
          extra: {
            index,
          },
        });
      })
      .filter(Boolean);
  },

  async content(ctx, book, chapter) {
    const result = await fetchPagedContent(ctx, chapter.url, chapter.title);

    return createContent({
      title: chapter.title,
      content: result.content,
      nextUrl: result.nextUrl,
      extra: {
        ...chapter.extra,
        bookId: book.extra?.bookId || extractBookId(book.detailUrl),
      },
    });
  },
};
