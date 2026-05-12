const SOURCE_HOST = 'https://so.html5.qq.com';
const DISCOVER_HOST = 'https://ubook.reader.qq.com';
const DISCOVER_CATEGORIES_URL = `${DISCOVER_HOST}/book-cate`;
const DISCOVER_CATEGORY_BOOKLIST_API =
  'https://ubook.reader.qq.com/api/book/categories/booklist';
const SEARCH_API = 'https://newopensearch.reader.qq.com/wechat';
const DETAIL_API = 'https://bookshelf.html5.qq.com/qbread/api/novel/intro-info';
const TOC_API = 'https://bookshelf.html5.qq.com/qbread/api/book/all-chapter';
const CONTENT_API = 'https://novel.html5.qq.com/be-api/content/ads-read';
const RESOURCE_ID_OFFSET = 1100000000;
const CONTENT_Q_GUID = '4aa27c7cf2d9aca3359656ea186488cb';
const DISCOVER_CATEGORY_ROUTE_PATTERN = /\/book-cate\/([0-9-]+)/i;
const DEFAULT_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 10; MI 8 Build/QKQ1.190828.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.101 Mobile Safari/537.36',
  Referer: 'https://bookshelf.html5.qq.com/qbread',
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

function requestJson(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    headers: {
      ...DEFAULT_HEADERS,
      ...(options.headers || {}),
    },
    ...options,
  });
}

function requestHtml(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'text',
    headers: {
      ...DEFAULT_HEADERS,
      Referer: DISCOVER_HOST,
      ...(options.headers || {}),
    },
    ...options,
  });
}

function normalizeText(value) {
  return String(value == null ? '' : value).replace(/\s+/g, ' ').trim();
}

function normalizeMultilineText(value) {
  return String(value == null ? '' : value)
    .replace(/\r\n?/g, '\n')
    .replace(/\u00a0/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function cleanupIntro(value) {
  return normalizeMultilineText(String(value == null ? '' : value).replace(/^"+|"+$/g, ''));
}

function cleanupContent(value) {
  const normalized = normalizeMultilineText(value);
  if (!normalized) {
    return '';
  }

  return normalized
    .split(/\n\s*-{20,}\s*\n/)[0]
    .replace(/<p>\s*<\/p>/gi, '')
    .trim();
}

function cleanLatestChapter(value) {
  return normalizeText(
    String(value == null ? '' : value).replace(
      /正文卷\.|正文\.|VIP卷\.|默认卷\.|卷_|VIP章节\.|免费章节\.|章节目录\.|最新章节\.|[\(（【].*?[求更票谢乐发订合补加架字修Kk].*?[】）\)]/g,
      '',
    ),
  );
}

function formatTimestamp(ctx, seconds) {
  const value = Number(seconds || 0);
  if (!value) {
    return '';
  }

  return String(ctx.utils.timeFormat(value * 1000, 'yyyy-MM-dd HH:mm:ss') || '');
}

function toResourceId(rawValue) {
  const text = normalizeText(rawValue);
  if (!text) {
    return '';
  }
  if (text.startsWith('110')) {
    return text;
  }

  const numeric = Number(text);
  if (Number.isNaN(numeric)) {
    return text;
  }

  return String(RESOURCE_ID_OFFSET + numeric);
}

function extractResourceIdFromUrl(url) {
  const match = String(url || '').match(/[?&]bookid=(\d+)|[?&]bookId=(\d+)/i);
  if (!match) {
    return '';
  }
  return normalizeText(match[1] || match[2]);
}

function resolveResourceId(book) {
  if (book && book.extra && book.extra.resourceId) {
    return normalizeText(book.extra.resourceId);
  }
  if (book && book.detailUrl) {
    const resourceId = extractResourceIdFromUrl(book.detailUrl);
    if (resourceId) {
      return resourceId;
    }
  }
  if (book && book.tocUrl) {
    const resourceId = extractResourceIdFromUrl(book.tocUrl);
    if (resourceId) {
      return resourceId;
    }
  }
  if (book && book.extra && book.extra.bid) {
    return toResourceId(book.extra.bid);
  }
  return '';
}

function resolveChapterSeqNo(chapter) {
  if (chapter && chapter.extra && chapter.extra.chapterSeqNo) {
    return Number(chapter.extra.chapterSeqNo);
  }

  const match = String((chapter && chapter.url) || '').match(/[?&]chapterSeqNo=(\d+)/i);
  if (!match) {
    return 0;
  }

  return Number(match[1]);
}

function buildDetailUrl(resourceId) {
  return `${DETAIL_API}?bookid=${resourceId}`;
}

function buildTocUrl(resourceId) {
  return `${TOC_API}?bookId=${resourceId}`;
}

function buildChapterUrl(resourceId, chapterSeqNo) {
  return `${CONTENT_API}?bookId=${resourceId}&chapterSeqNo=${chapterSeqNo}`;
}

function buildSearchCoverUrl(bid) {
  const text = normalizeText(bid);
  if (!text) {
    return '';
  }

  const tail = text.slice(-3);
  const numeric = Number(tail);
  let bucket = text.slice(-1);
  if (!Number.isNaN(numeric)) {
    if (numeric >= 100) {
      bucket = tail;
    } else if (numeric >= 10) {
      bucket = text.slice(-2);
    }
  }

  return `https://wfqqreader-1252317822.image.myqcloud.com/cover/${bucket}/${text}/b_${text}.jpg`;
}

function parseTags(value) {
  const text = normalizeText(value);
  if (!text) {
    return [];
  }

  return text
    .split('|')
    .map((item) => normalizeText(item.split(':').pop()))
    .filter(Boolean);
}

function parseCategoryInfo(value) {
  const text = normalizeText(value);
  if (!text) {
    return '';
  }

  return text
    .split(',')
    .map((item) => item.split(':'))
    .map((parts) => normalizeText(parts[1] || parts[parts.length - 1] || ''))
    .filter((item) => item && item !== '小说')
    .join(' / ');
}

function parseStatus(updateInfo, isFinish) {
  if (typeof isFinish === 'boolean') {
    return isFinish ? '已完结' : '连载';
  }

  const text = normalizeText(updateInfo);
  if (!text) {
    return '';
  }

  return text.includes('完结') ? '已完结' : '连载';
}

function parseLatestChapter(updateInfo) {
  const text = normalizeText(updateInfo);
  if (!text || !text.startsWith('已更新至')) {
    return '';
  }

  return cleanLatestChapter(text.replace(/^已更新至/, ''));
}

function requireSuccess(response, label) {
  const payload = response && response.json ? response.json : null;
  if (!payload) {
    throw new Error(`${label} 返回为空。`);
  }

  const code = payload.ret != null ? payload.ret : payload.code;
  if (code !== 0) {
    throw new Error(`${label} 失败: ${payload.message || payload.errMsg || code}`);
  }

  return payload;
}

function inferDiscoverBookType(categoryId) {
  const value = Number(categoryId || 0);
  if (!value) {
    return 1;
  }
  if (value >= 30000) {
    return 2;
  }
  if (value >= 10000 && value < 20000) {
    return 3;
  }
  return 1;
}

function resolveDiscoverUrl(ctx, href) {
  const value = normalizeText(href);
  if (!value) {
    return '';
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('//')) {
    return `https:${value}`;
  }
  return String(ctx.utils.absoluteUrl(DISCOVER_CATEGORIES_URL, value) || '');
}

function parseDiscoverCategoryRoute(url) {
  const normalized = normalizeText(url);
  const match = normalized.match(DISCOVER_CATEGORY_ROUTE_PATTERN);
  if (!match) {
    return null;
  }

  const parts = String(match[1] || '')
    .split('-')
    .map((item) => Number(item || 0));
  if (parts.length < 1 || !parts[0]) {
    return null;
  }

  const categoryId = parts[0] || 0;
  const orderBy = parts.length > 6 ? parts[6] || 0 : 0;
  return {
    categoryId,
    orderBy,
    bookType: inferDiscoverBookType(categoryId),
  };
}

function buildDiscoverCategoryItem(ctx, groupTitle, linkNode) {
  const rawName = normalizeText(ctx.html.text(linkNode.querySelector('.cate-name')));
  const rawUrl = resolveDiscoverUrl(ctx, ctx.html.attr(linkNode, 'href'));
  const route = parseDiscoverCategoryRoute(rawUrl);
  if (!rawName || !rawUrl || !route) {
    return null;
  }

  const titlePrefix = normalizeText(groupTitle);
  return createDiscoverCategory({
    title: titlePrefix ? `${titlePrefix} · ${rawName}` : rawName,
    url: rawUrl,
    extra: {
      rawTitle: rawName,
      group: titlePrefix,
      categoryId: route.categoryId,
      orderBy: route.orderBy,
      bookType: route.bookType,
    },
  });
}

function resolveDiscoverCategoryMeta(category) {
  const extra = (category && category.extra) || {};
  const categoryId = Number(extra.categoryId || 0);
  const orderBy = Number(extra.orderBy || 0);
  const bookType = Number(extra.bookType || inferDiscoverBookType(categoryId));

  if (!categoryId) {
    const parsed = parseDiscoverCategoryRoute(category && category.url);
    if (parsed) {
      return parsed;
    }
  }

  if (!categoryId) {
    throw new Error('发现分类缺少 categoryId。');
  }

  return {
    categoryId,
    orderBy,
    bookType: bookType || inferDiscoverBookType(categoryId),
  };
}

function buildDiscoverBook(item, categoryMeta) {
  const bid = normalizeText(item && item.id);
  const resourceId = toResourceId(bid);
  const categories = Array.isArray(item && item.categories) ? item.categories : [];
  const categoryText = categories
    .slice(1)
    .map((entry) => normalizeText(entry && (entry.shortName || entry.name)))
    .filter(Boolean)
    .join(' / ');

  return createBook({
    type: 'novel',
    title: normalizeText(item && item.title),
    author: normalizeText(item && item.author),
    cover: normalizeText(item && item.cover),
    intro: cleanupIntro(item && item.intro),
    status: item && item.finished === true ? '已完结' : '连载',
    category: categoryText,
    score: item && item.score != null && item.score !== '' ? String(item.score) : '',
    wordCount: normalizeText(item && item.totalWords),
    latestChapter: cleanLatestChapter(item && item.lastChapterName),
    detailUrl: buildDetailUrl(resourceId),
    tocUrl: buildTocUrl(resourceId),
    extra: {
      bid,
      resourceId,
      discoverCategoryId: categoryMeta.categoryId,
      discoverBookType: categoryMeta.bookType,
      discoverOrderBy: categoryMeta.orderBy,
      sexAttr: item && item.sexAttr != null ? Number(item.sexAttr) : 0,
    },
  });
}

export default {
  meta: {
    name: '球球览器',
    group: '腾讯',
    author: 'migrated_from_test_read_json',
    description: '由旧规则 test_read.json 迁移的 QQ 阅读脚本源。',
    checkKeyword: '斗破苍穹',
    domains: [
      'so.html5.qq.com',
      'ubook.reader.qq.com',
      'newopensearch.reader.qq.com',
      'bookshelf.html5.qq.com',
      'novel.html5.qq.com',
      'qbnovel.qq.com',
    ],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'ubook.reader.qq.com': {
        minIntervalMs: 300,
      },
      'newopensearch.reader.qq.com': {
        minIntervalMs: 300,
      },
      'bookshelf.html5.qq.com': {
        minIntervalMs: 300,
      },
      'novel.html5.qq.com': {
        minIntervalMs: 300,
      },
    },
  },

  async discoverCategories(ctx) {
    const response = await requestHtml(ctx, DISCOVER_CATEGORIES_URL, {
      timeoutMs: 10000,
    });
    const html = String((response && response.text) || '');
    if (!html) {
      throw new Error('发现分类页为空。');
    }

    const doc = ctx.html.parse(html);
    const sections = doc.querySelectorAll('.cate-list');
    const categories = [];
    const seen = new Set();

    for (const section of sections) {
      const groupTitle = normalizeText(ctx.html.text(section.querySelector('.cate-tab')));
      const linkNodes = section.querySelectorAll('a[href*="/book-cate/"]');
      for (const linkNode of linkNodes) {
        const item = buildDiscoverCategoryItem(ctx, groupTitle, linkNode);
        if (!item) {
          continue;
        }

        const dedupeKey = `${item.title}|${item.url}`;
        if (seen.has(dedupeKey)) {
          continue;
        }

        seen.add(dedupeKey);
        categories.push(item);
      }
    }

    return categories;
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const categoryMeta = resolveDiscoverCategoryMeta(category);
    const response = await requestJson(ctx, DISCOVER_CATEGORY_BOOKLIST_API, {
      query: {
        pageIndex: String(page),
        pageSize: String(pageSize),
        bookType: String(categoryMeta.bookType),
        categoryid: String(categoryMeta.categoryId),
        sorted: String(categoryMeta.orderBy),
      },
      headers: {
        Referer: DISCOVER_CATEGORIES_URL,
      },
      timeoutMs: 10000,
    });

    const payload = response && response.json ? response.json : null;
    const data = payload && payload.data ? payload.data : null;
    if (!data) {
      throw new Error('分类书单返回为空。');
    }

    const list = Array.isArray(data.list) ? data.list : [];
    return list.map((item) => buildDiscoverBook(item, categoryMeta));
  },

  async search(ctx, keyword) {
    const response = await requestJson(ctx, SEARCH_API, {
      query: {
        keyword,
        start: 0,
        end: 19,
      },
      timeoutMs: 10000,
    });
    const payload = requireSuccess(response, '搜索');
    const list = Array.isArray(payload.booklist) ? payload.booklist : [];

    return list.map((item) => {
      const bid = normalizeText(item.bid);
      const resourceId = toResourceId(bid);
      return createBook({
        type: 'novel',
        title: normalizeText(item.title),
        author: normalizeText(item.author),
        cover: buildSearchCoverUrl(bid),
        intro: cleanupIntro(item.intro),
        status: parseStatus(item.updateInfo, null),
        category: parseCategoryInfo(item.categoryInfoV4),
        wordCount: normalizeText(item.totalWords),
        tags: parseTags(item.tag),
        latestChapter: parseLatestChapter(item.updateInfo),
        detailUrl: buildDetailUrl(resourceId),
        tocUrl: buildTocUrl(resourceId),
        extra: {
          bid,
          resourceId,
          jmpUrl: normalizeText(item.jmpURL),
        },
      });
    });
  },

  async detail(ctx, book) {
    const resourceId = resolveResourceId(book);
    if (!resourceId) {
      throw new Error('详情缺少 resourceId。');
    }

    const response = await requestJson(ctx, DETAIL_API, {
      query: {
        bookid: resourceId,
      },
      timeoutMs: 10000,
    });
    const payload = requireSuccess(response, '详情');
    const bookInfo = (payload.data && payload.data.bookInfo) || null;
    if (!bookInfo) {
      throw new Error('详情缺少 bookInfo。');
    }

    const categoryParts = [
      normalizeText(bookInfo.subject),
      normalizeText(bookInfo.subtype),
    ].filter(Boolean);

    return createBook({
      ...book,
      type: 'novel',
      title: normalizeText(bookInfo.resourceName || book.title),
      author: normalizeText(bookInfo.author || book.author),
      cover: normalizeText(bookInfo.picCDN || bookInfo.picurl || book.cover),
      intro: cleanupIntro(bookInfo.summary || book.intro),
      status: parseStatus('', !!bookInfo.isfinish),
      category: categoryParts.join(' / '),
      score: normalizeText(bookInfo.userscore),
      wordCount: normalizeText(bookInfo.contentsize),
      updateTime: formatTimestamp(ctx, bookInfo.lastUpdatetime),
      tags: parseTags(bookInfo.tag),
      latestChapter: cleanLatestChapter(bookInfo.lastSerialname),
      detailUrl: buildDetailUrl(resourceId),
      tocUrl: buildTocUrl(resourceId),
      extra: {
        ...(book.extra || {}),
        bid: normalizeText((book.extra && book.extra.bid) || ''),
        resourceId,
      },
    });
  },

  async chapters(ctx, book) {
    const resourceId = resolveResourceId(book);
    if (!resourceId) {
      throw new Error('目录缺少 resourceId。');
    }

    const response = await requestJson(ctx, TOC_API, {
      query: {
        bookId: resourceId,
      },
      timeoutMs: 10000,
    });
    const payload = requireSuccess(response, '目录');
    const rows = Array.isArray(payload.rows) ? payload.rows : [];

    return rows.map((item) =>
      createChapter({
        title: cleanLatestChapter(item.serialName),
        url: buildChapterUrl(resourceId, item.serialID),
        isVip: item.isFree === false,
        isPay: item.isFree === true,
        extra: {
          resourceId,
          chapterSeqNo: Number(item.serialID || 0),
          serialUniqID: normalizeText(item.serialUniqID),
        },
      }),
    );
  },

  async content(ctx, book, chapter) {
    const resourceId = resolveResourceId(book);
    if (!resourceId) {
      throw new Error('正文缺少 resourceId。');
    }

    const chapterSeqNo = resolveChapterSeqNo(chapter);
    if (!chapterSeqNo) {
      throw new Error('正文缺少 chapterSeqNo。');
    }

    const response = await ctx.http.request({
      url: CONTENT_API,
      method: 'POST',
      responseType: 'json',
      bodyType: 'json',
      timeoutMs: 10000,
      headers: {
        ...DEFAULT_HEADERS,
        'Content-Type': 'application/json',
        'Q-GUID': CONTENT_Q_GUID,
      },
      body: {
        Scene: 'chapter',
        ContentAnchorBatch: [
          {
            BookID: resourceId,
            ChapterSeqNo: [chapterSeqNo],
          },
        ],
      },
    });

    const payload = requireSuccess(response, '正文');
    const contentItem =
      payload.data && Array.isArray(payload.data.Content)
        ? payload.data.Content[0]
        : null;
    if (!contentItem) {
      throw new Error('正文缺少内容块。');
    }

    const textList = Array.isArray(contentItem.Content) ? contentItem.Content : [];
    const text = cleanupContent(textList.join('\n'));
    if (!text) {
      throw new Error('正文为空。');
    }

    const chapterInfo = contentItem.ChapterInfo || {};

    return createContent({
      title: normalizeText(chapterInfo.Title || chapter.title),
      content: text,
      extra: {
        resourceId,
        chapterSeqNo,
        chapterId: normalizeText(chapterInfo.ChapterID),
      },
    });
  },
};
