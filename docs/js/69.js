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

function absoluteUrl(ctx, url) {
  return ctx.utils.absoluteUrl(SOURCE_HOST, url || '');
}

function cleanText(ctx, value) {
  return ctx.utils.normalizeText(value || '');
}

function normalizeMultiline(ctx, value) {
  return String(value == null ? '' : value)
    .replace(/\r\n?/g, '\n')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .split('\n')
    .map((line) => cleanText(ctx, line))
    .filter(Boolean)
    .join('\n\n')
    .trim();
}

async function requestText(ctx, url, options = {}) {
  return await ctx.http.request({
    url,
    method: 'GET',
    responseType: 'text',
    timeoutMs: REQUEST_TIMEOUT,
    headers: {
      ...DEFAULT_HEADERS,
      Referer: SOURCE_HOST,
      ...(options.headers || {}),
    },
    ...options,
  });
}

function textOf(ctx, node, selector) {
  return cleanText(ctx, ctx.html.text(node?.querySelector(selector)));
}

function attrOf(ctx, node, selector, attr) {
  return cleanText(ctx, node?.querySelector(selector)?.getAttribute(attr));
}

function parseOg(ctx, doc, name) {
  return cleanText(
    ctx,
    doc.querySelector(`meta[property="og:${name}"]`)?.getAttribute('content'),
  );
}

function decodeHtml(ctx, value) {
  const text = cleanText(ctx, value);
  if (!text) {
    return '';
  }
  const doc = ctx.html.parse(`<div>${text}</div>`);
  return cleanText(ctx, ctx.html.text(doc.querySelector('div')));
}

function parseListItems(ctx, doc, fallbackCategory = '') {
  const items = doc.querySelectorAll('.item');

  return ctx.html
    .collect(items, (item) => {
      const title =
        textOf(ctx, item, 'dl > dt > a') ||
        textOf(ctx, item, 'a:nth-of-type(1)');
      const detailUrl = absoluteUrl(
        ctx,
        attrOf(ctx, item, 'dl > dt > a', 'href') ||
          attrOf(ctx, item, 'a:nth-of-type(1)', 'href'),
      );

      return createBook({
        title,
        type: 'novel',
        author:
          textOf(ctx, item, '.btm a') ||
          textOf(ctx, item, 'a:nth-of-type(2)'),
        cover: absoluteUrl(
          ctx,
          attrOf(ctx, item, 'img', 'data-original') ||
            attrOf(ctx, item, 'img', 'src'),
        ),
        intro: decodeHtml(ctx, textOf(ctx, item, 'dl > dd') || textOf(ctx, item, 'dd')),
        category: fallbackCategory,
        wordCount: textOf(ctx, item, '.btm em.orange'),
        updateTime: textOf(ctx, item, '.btm em.blue'),
        detailUrl,
        tocUrl: detailUrl,
      });
    })
    .filter((book) => book.title && book.detailUrl);
}

function dedupeBooks(books) {
  const seen = new Set();
  const result = [];

  for (const book of books) {
    const key = `${book.detailUrl}::${book.title}`;
    if (!book.detailUrl || seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(book);
  }

  return result;
}

function extractCaptchaCode(ctx, html) {
  const doc = ctx.html.parse(html || '');
  return textOf(ctx, doc, '.modal-code');
}

function isCaptchaHtml(ctx, html) {
  const doc = ctx.html.parse(html || '');
  const code = textOf(ctx, doc, '.modal-code');
  const hasInput = !!doc.querySelector('input[name="verifycode"]');
  const hasForm = !!doc.querySelector('form');
  return !!code && hasInput && hasForm;
}

function looksLikeCfChallenge(html) {
  const text = String(html || '').toLowerCase();
  return (
    text.includes('cf-browser-verification') ||
    text.includes('challenge-platform') ||
    text.includes('__cf_chl') ||
    text.includes('just a moment') ||
    text.includes('checking your browser') ||
    text.includes('cloudflare')
  );
}

async function waitBrowserHtmlReady(ctx, check, timeoutMs = 20000) {
  const startedAt = Date.now();
  let html = '';

  while (Date.now() - startedAt < timeoutMs) {
    await ctx.utils.sleep(500);
    html = await ctx.browser.getHtml();
    if (html && check(html)) {
      return html;
    }
  }

  return html;
}

async function submitCaptchaSearch(ctx, keyword, searchUrl, captchaCode) {
  const submitUrl = `${SOURCE_HOST}/ss?searchkey=${ctx.utils.encodeUriComponent(keyword)}`;
  const response = await ctx.http.request({
    url: submitUrl,
    method: 'POST',
    responseType: 'text',
    timeoutMs: REQUEST_TIMEOUT,
    bodyType: 'form',
    headers: {
      ...DEFAULT_HEADERS,
      Referer: searchUrl,
    },
    body: {
      verifycode: captchaCode,
    },
  });

  return response.text || '';
}

async function searchWithBrowser(ctx, keyword, searchUrl) {
  await ctx.browser.open({
    url: searchUrl,
    timeoutMs: REQUEST_TIMEOUT,
  });

  let html = await waitBrowserHtmlReady(
    ctx,
    (value) => !looksLikeCfChallenge(value),
    25000,
  );

  if (looksLikeCfChallenge(html)) {
    throw '浏览器打开搜索页后，仍停留在 CF 验证页。';
  }

  let doc = ctx.html.parse(html || '');
  let books = parseListItems(ctx, doc);
  if (books.length > 0) {
    return books;
  }

  if (isCaptchaHtml(ctx, html)) {
    const code = extractCaptchaCode(ctx, html);
    ctx.log(`search browser page shows captcha, submit via http, code=${code}`);
    html = await submitCaptchaSearch(ctx, keyword, searchUrl, code);
    doc = ctx.html.parse(html || '');
    books = parseListItems(ctx, doc);
    if (books.length > 0) {
      return books;
    }
    if (isCaptchaHtml(ctx, html)) {
      throw `验证码已提交，但页面仍停留在验证码页：${code}`;
    }
  }

  return books;
}

async function performSearch(ctx, keyword) {
  const searchUrl = `${SOURCE_HOST}/ss/?searchkey=${ctx.utils.encodeUriComponent(keyword)}`;

  const response = await requestText(ctx, searchUrl, {
    headers: {
      Referer: SOURCE_HOST,
    },
  });

  const html = response.text || '';
  const doc = ctx.html.parse(html);
  const books = parseListItems(ctx, doc);

  if (books.length > 0) {
    return books;
  }

  if (ctx.http.isChallenge(response) || looksLikeCfChallenge(html)) {
    ctx.log('search hit cf challenge, switch to browser');
    return await searchWithBrowser(ctx, keyword, searchUrl);
  }

  if (isCaptchaHtml(ctx, html)) {
    const code = extractCaptchaCode(ctx, html);
    ctx.log(`search hit captcha page, submit via http, code=${code}`);
    const submittedHtml = await submitCaptchaSearch(
      ctx,
      keyword,
      searchUrl,
      code,
    );
    const submittedDoc = ctx.html.parse(submittedHtml || '');
    return parseListItems(ctx, submittedDoc);
  }

  return [];
}

function resolveCategoryTemplate(ctx, href) {
  const absolute = absoluteUrl(ctx, href);
  if (!absolute) {
    return '';
  }
  return absolute.replace(/_(\d+)\.html$/i, '_{{page}}.html');
}

async function fetchCategoryPage(ctx, url) {
  const response = await requestText(ctx, url, {
    headers: {
      Referer: SOURCE_HOST,
    },
  });

  const doc = ctx.html.parse(response.text || '');
  const heading =
    textOf(ctx, doc, '#hotcontent .rank h2') ||
    textOf(ctx, doc, '#newscontent .r h2');

  const books = parseListItems(ctx, doc, heading);
  return {
    heading,
    books,
  };
}

function parseDiscoverCategories(ctx, doc) {
  const nodes = doc.querySelectorAll('.nav a');

  return ctx.html
    .collect(nodes, (node) => {
      const href = cleanText(ctx, node.getAttribute('href'));
      if (!/^\/class\//.test(href)) {
        return null;
      }

      return createDiscoverCategory({
        title: cleanText(ctx, ctx.html.text(node)),
        url: resolveCategoryTemplate(ctx, href),
        style: {
          layoutFlexGrow: 1,
          layoutFlexBasisPercent: 0.33,
        },
        extra: {
          firstPageUrl: absoluteUrl(ctx, href),
        },
      });
    })
    .filter(Boolean);
}

function extractDirectoryHtml(html) {
  const match = String(html || '').match(
    /<dt>\s*目录章节[\s\S]*?<\/dt>([\s\S]*?)<\/dl>/i,
  );
  return match ? match[1] : '';
}

function parseChapterList(ctx, html) {
  const fragmentHtml = extractDirectoryHtml(html);
  const targetDoc = ctx.html.parse(
    fragmentHtml ? `<div>${fragmentHtml}</div>` : html || '',
  );
  const links = targetDoc.querySelectorAll('a[rel="chapter"]');

  return ctx.html
    .collect(links, (link, index) => {
      const title =
        cleanText(ctx, ctx.html.text(link.querySelector('dd'))) ||
        cleanText(ctx, ctx.html.text(link));
      const href = cleanText(ctx, link.getAttribute('href'));

      return createChapter({
        title,
        url: absoluteUrl(ctx, href),
        extra: {
          index,
        },
      });
    })
    .filter((chapter) => chapter.title && chapter.url);
}

function chapterBaseKey(url) {
  const absolute = String(url || '').split('?')[0].split('#')[0];
  const match = absolute.match(/^(.*\/\d+)(?:_\d+)?\.html$/i);
  return match ? match[1] : absolute;
}

function parseNextPageUrl(ctx, doc) {
  return absoluteUrl(
    ctx,
    attrOf(ctx, doc, '#next_url', 'href') ||
      attrOf(ctx, doc, 'a[rel="next"]', 'href'),
  );
}

function cleanupContent(ctx, value) {
  return normalizeMultiline(
    ctx,
    String(value || '')
      .replace(/^第.+?（\d+\/\d+）/, '')
      .replace(/^第.+?章[^\n]*/, '')
      .replace(/本章未完，点击下一页继续阅读。?/g, ''),
  );
}

async function fetchPagedContent(ctx, url, visited = new Set(), baseKey = '') {
  const currentUrl = absoluteUrl(ctx, url);
  if (!currentUrl || visited.has(currentUrl)) {
    return {
      content: '',
      nextUrl: null,
    };
  }

  visited.add(currentUrl);

  const response = await requestText(ctx, currentUrl, {
    headers: {
      Referer: currentUrl,
    },
  });
  const doc = ctx.html.parse(response.text || '');

  const paragraphs = doc
    .querySelectorAll('#booktxt > p')
    .map((node) => cleanText(ctx, ctx.html.text(node)))
    .filter(Boolean);

  let content = paragraphs.join('\n\n');
  if (!content) {
    content = cleanText(ctx, ctx.html.text(doc.querySelector('#booktxt')));
  }
  content = cleanupContent(ctx, content);

  const nextUrl = parseNextPageUrl(ctx, doc);
  const nextBaseKey = chapterBaseKey(nextUrl);

  if (!nextUrl || !baseKey || nextBaseKey !== baseKey || visited.has(nextUrl)) {
    return {
      content,
      nextUrl: null,
    };
  }

  const nextResult = await fetchPagedContent(ctx, nextUrl, visited, baseKey);

  return {
    content: [content, nextResult.content].filter(Boolean).join('\n\n'),
    nextUrl: nextResult.nextUrl,
  };
}

export default {
  meta: {
    name: '69书吧',
    group: '默认分组',
    author: 'converted',
    description: '从 Legado 规则转换的 JS 书源，包含搜索验证码处理。',
    domains: ['www.69hao.com', '69hao.com'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['discover', 'search', 'detail', 'chapters', 'content'],
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
      headers: {
        Referer: SOURCE_HOST,
      },
    });
    const doc = ctx.html.parse(response.text || '');
    return parseDiscoverCategories(ctx, doc);
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const currentPage = Math.max(1, Number(page || 1));
    const urlTemplate = category.url || category.extra?.firstPageUrl || SOURCE_HOST;
    const pageUrl = String(urlTemplate).includes('{{page}}')
      ? String(urlTemplate).replace(/\{\{page\}\}/g, String(currentPage))
      : urlTemplate;

    const result = await fetchCategoryPage(ctx, pageUrl);
    const books = result.books;

    if (!pageSize || books.length <= Number(pageSize)) {
      return books;
    }

    return books.slice(0, Number(pageSize));
  },

  async search(ctx, keyword) {
    return await performSearch(ctx, keyword);
  },

  async detail(ctx, book) {
    const response = await requestText(ctx, book.detailUrl, {
      headers: {
        Referer: book.detailUrl || SOURCE_HOST,
      },
    });

    const doc = ctx.html.parse(response.text || '');

    const title = parseOg(ctx, doc, 'novel:book_name') || book.title;
    const author = parseOg(ctx, doc, 'novel:author') || book.author;
    const category = parseOg(ctx, doc, 'novel:category') || book.category;
    const status = parseOg(ctx, doc, 'novel:status') || book.status;
    const updateTime = parseOg(ctx, doc, 'novel:update_time') || book.updateTime;
    const latestChapter =
      parseOg(ctx, doc, 'novel:latest_chapter_name') || book.latestChapter;
    const cover = absoluteUrl(ctx, parseOg(ctx, doc, 'image') || book.cover);
    const intro =
      parseOg(ctx, doc, 'description') ||
      decodeHtml(ctx, ctx.html.text(doc.querySelector('#intro'))) ||
      book.intro;
    const detailUrl =
      absoluteUrl(ctx, parseOg(ctx, doc, 'novel:read_url') || book.detailUrl);

    return createBook({
      ...book,
      type: 'novel',
      title,
      author,
      cover,
      intro,
      status,
      category,
      updateTime,
      latestChapter,
      detailUrl,
      tocUrl: detailUrl,
    });
  },

  async chapters(ctx, book) {
    const tocUrl = book.tocUrl || book.detailUrl;
    const response = await requestText(ctx, tocUrl, {
      headers: {
        Referer: book.detailUrl || SOURCE_HOST,
      },
    });

    return parseChapterList(ctx, response.text || '');
  },

  async content(ctx, book, chapter) {
    const baseKey = chapterBaseKey(chapter.url);
    const result = await fetchPagedContent(ctx, chapter.url, new Set(), baseKey);

    return createContent({
      title: chapter.title,
      content: result.content,
      nextUrl: result.nextUrl,
    });
  },
};
