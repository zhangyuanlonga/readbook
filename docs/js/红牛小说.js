const SOURCE_HOST = 'https://www.songdalaw.com';
const DEFAULT_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
  Accept:
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'zh-CN,zh;q=0.9',
  Referer: `${SOURCE_HOST}/`,
};

const DISCOVER_CATEGORIES = [
  ['不限', '/classurl/0_0_0_0_0_{{page}}.html'],
  ['修真', '/classurl/1_0_0_0_0_{{page}}.html'],
  ['仙侠', '/classurl/2_0_0_0_0_{{page}}.html'],
  ['情感', '/classurl/3_0_0_0_0_{{page}}.html'],
  ['历史', '/classurl/4_0_0_0_0_{{page}}.html'],
  ['网游', '/classurl/5_0_0_0_0_{{page}}.html'],
  ['穿越', '/classurl/6_0_0_0_0_{{page}}.html'],
  ['恐怖', '/classurl/7_0_0_0_0_{{page}}.html'],
  ['其他', '/classurl/8_0_0_0_0_{{page}}.html'],
  ['阅读排行', '/classurl/0_allvisit_0_0_0_{{page}}.html'],
  ['推荐排行', '/classurl/0_allvote_0_0_0_{{page}}.html'],
  ['收藏排行', '/classurl/0_goodnum_0_0_0_{{page}}.html'],
  ['更新时间', '/classurl/0_lastupdate_0_0_0_{{page}}.html'],
  ['最新小说', '/classurl/0_postdate_0_0_0_{{page}}.html'],
  ['30万以下', '/classurl/0_0_1_0_0_{{page}}.html'],
  ['30万-50万', '/classurl/0_0_2_0_0_{{page}}.html'],
  ['50万-100万', '/classurl/0_0_3_0_0_{{page}}.html'],
  ['100万-200万', '/classurl/0_0_4_0_0_{{page}}.html'],
  ['200万以上', '/classurl/0_0_5_0_0_{{page}}.html'],
  ['连载中', '/classurl/0_0_0_1_0_{{page}}.html'],
  ['已完结', '/classurl/0_0_0_2_0_{{page}}.html'],
];

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

function innerHtml(ctx, node) {
  return node ? String(ctx.html.innerHtml(node) || '') : '';
}

function parsePubInfo(text) {
  const normalized = normalizeText(text);
  const match = normalized.match(
    /作者[:：]\s*(.*?)\s*\/\s*类型[:：]?\s*(.*?)\s*\/\s*(\d{4}-\d{2}-\d{2})\s*\/\s*(连载中|已完结)\s*\/\s*([\d.]+万字)/,
  );
  if (!match) {
    return {
      author: '',
      category: '',
      updateTime: '',
      status: '',
      wordCount: '',
    };
  }
  return {
    author: normalizeText(match[1]),
    category: normalizeText(match[2]),
    updateTime: normalizeText(match[3]),
    status: normalizeText(match[4]),
    wordCount: normalizeText(match[5]),
  };
}

function cleanIntro(text) {
  return normalizeMultiline(
    normalizeText(text)
      .replace(/^【内容简介】|^【小说介绍】/g, '')
      .replace(/\.\.\.\s*$/, '')
      .replace(/最新章节推荐地址.*/g, ''),
  );
}

function metaContent(doc, property) {
  return normalizeText(
    doc
      ?.querySelector(`meta[property="${property}"]`)
      ?.getAttribute('content'),
  );
}

function parseSearchItem(ctx, item) {
  const linkNode = item.querySelector('.ebook-link a') || item.querySelector('h2 a');
  const latestNode = item.querySelector('.market-info a');
  const coverNode = item.querySelector('.pic img');
  const pubText = ctx.html.text(item.querySelector('.pub'));
  const pubInfo = parsePubInfo(pubText);

  return createBook({
    type: 'novel',
    title: normalizeText(ctx.html.text(item.querySelector('h2 a'))),
    author: pubInfo.author,
    cover: absolute(ctx, ctx.html.attr(coverNode, 'data-original') || ctx.html.attr(coverNode, 'src')),
    intro: cleanIntro(ctx.html.text(item.querySelector('.info p'))),
    status: pubInfo.status,
    category: pubInfo.category,
    wordCount: pubInfo.wordCount,
    updateTime: pubInfo.updateTime,
    latestChapter: normalizeText(ctx.html.text(latestNode)).replace(/^【最新章节】/, ''),
    detailUrl: absolute(ctx, ctx.html.attr(linkNode, 'href')),
    extra: {
      latestChapterUrl: absolute(ctx, ctx.html.attr(latestNode, 'href')),
    },
  });
}

function parseContentHtml(html) {
  return normalizeMultiline(
    String(html || '')
      .replace(/<p>\s*readx;\s*<\/p>/gi, '')
      .replace(/（\.无弹窗广告）/g, '')
      .replace(/<p[^>]*style="color:red;[^"]*"[^>]*>[\s\S]*?<\/p>/gi, '')
      .trim(),
  );
}

export default {
  meta: {
    name: '红牛小说',
    group: '🌞',
    author: 'converted_from_test_json',
    description: '由旧规则转换的红牛小说脚本源。',
    checkKeyword: '凡人修仙传',
    domains: ['www.songdalaw.com', 'm.songdalaw.com'],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'www.songdalaw.com': {
        minIntervalMs: 500,
      },
    },
  },

  async discoverCategories(ctx) {
    return DISCOVER_CATEGORIES.map(([title, url]) =>
      createDiscoverCategory({
        title,
        url: absolute(ctx, url.replace('{{page}}', '1')),
        style: {
          layoutFlexGrow: 1,
          layoutFlexBasisPercent: 25,
        },
        extra: {
          urlPattern: url,
        },
      }),
    );
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const urlPattern = category.extra?.urlPattern || category.url || '';
    const url = absolute(ctx, String(urlPattern).replace('{{page}}', String(page)));
    const response = await requestText(ctx, url);
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.subject-item');
    return ctx.html.collect(items, (item) => parseSearchItem(ctx, item));
  },

  async search(ctx, keyword) {
    const response = await requestText(
      ctx,
      `${SOURCE_HOST}/search/?keyword=${encodeURIComponent(keyword)}&t=0&page=1`,
    );
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.subject-item');
    return ctx.html.collect(items, (item) => parseSearchItem(ctx, item));
  },

  async detail(ctx, book) {
    const response = await requestText(ctx, book.detailUrl);
    const doc = ctx.html.parse(response.text);

    return createBook({
      ...book,
      title: metaContent(doc, 'og:novel:book_name') || book.title,
      author: metaContent(doc, 'og:novel:author') || book.author,
      cover: metaContent(doc, 'og:image') || book.cover,
      intro:
        cleanIntro(
          ctx.html.text(doc.querySelector('.related_info .intro')) ||
            metaContent(doc, 'og:description'),
        ) || book.intro,
      status: metaContent(doc, 'og:novel:status') || book.status,
      category: metaContent(doc, 'og:novel:category') || book.category,
      wordCount:
        normalizeText(
          ctx.html
            .text(doc.querySelector('#info'))
            .match(/已写[:：]?\s*(\d+万字)/)?.[1],
        ) || book.wordCount,
      updateTime: metaContent(doc, 'og:novel:update_time') || book.updateTime,
      latestChapter:
        metaContent(doc, 'og:novel:latest_chapter_name') || book.latestChapter,
      tocUrl:
        absolute(ctx, ctx.html.attr(doc.querySelector('.online-read a'), 'href')) ||
        metaContent(doc, 'og:novel:read_url') ||
        book.tocUrl,
    });
  },

  async chapters(ctx, book) {
    const response = await requestText(ctx, book.tocUrl || book.detailUrl);
    const doc = ctx.html.parse(response.text);
    const nodes = doc.querySelectorAll('#listsss #chapter a');

    return ctx.html.collect(nodes, (node, index) =>
      createChapter({
        title: normalizeText(ctx.html.text(node)),
        url: String(ctx.utils.absoluteUrl(book.tocUrl || book.detailUrl, ctx.html.attr(node, 'href') || '') || ''),
        extra: {
          index: index + 1,
        },
      }),
    );
  },

  async content(ctx, book, chapter) {
    const response = await requestText(ctx, chapter.url, {
      headers: {
        Referer: book.tocUrl || book.detailUrl || `${SOURCE_HOST}/`,
      },
    });
    const doc = ctx.html.parse(response.text);
    const blocks = Array.from(doc.querySelectorAll('#txt dd')).sort(
      (a, b) =>
        Number(a.getAttribute('data-id') || 0) -
        Number(b.getAttribute('data-id') || 0),
    );

    const html = blocks.map((node) => innerHtml(ctx, node)).join('\n');

    return createContent({
      title: chapter.title,
      content: parseContentHtml(html),
    });
  },
};
