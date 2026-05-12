const SOURCE_HOST = 'http://wap.80zw.la';
const DEFAULT_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 9) Mobile Safari/537.36',
};

const DISCOVER_CATEGORIES = [
  ['全本小说', '/top/full-{{page}}.html'],
  ['日点击榜', '/top/dayvisit-{{page}}.html'],
  ['周点击榜', '/top/weekvisit-{{page}}.html'],
  ['月点击榜', '/top/monthvisit-{{page}}.html'],
  ['总点击榜', '/top/allvisit-{{page}}.html'],
  ['总收藏榜', '/top/goodnum-{{page}}.html'],
  ['字数排行', '/top/size-{{page}}.html'],
  ['日推荐榜', '/top/dayvote-{{page}}.html'],
  ['周推荐榜', '/top/weekvote-{{page}}.html'],
  ['月推荐榜', '/top/monthvote-{{page}}.html'],
  ['总推荐榜', '/top/allvote-{{page}}.html'],
  ['最新入库', '/top/postdate-{{page}}.html'],
  ['最近更新', '/top/lastupdate-{{page}}.html'],
  ['修真', '/class3-{{page}}.html'],
  ['魔法', '/class13-{{page}}.html'],
  ['异术', '/class1-{{page}}.html'],
  ['东方', '/class12-{{page}}.html'],
  ['争霸', '/class14-{{page}}.html'],
  ['武侠', '/class15-{{page}}.html'],
  ['未来', '/class9-{{page}}.html'],
  ['灵异', '/class10-{{page}}.html'],
  ['探险', '/class22-{{page}}.html'],
  ['传记', '/class6-{{page}}.html'],
  ['特种', '/class7-{{page}}.html'],
  ['网游', '/class16-{{page}}.html'],
  ['竞技', '/class8-{{page}}.html'],
  ['女强', '/class2-{{page}}.html'],
  ['婚姻', '/class4-{{page}}.html'],
  ['百合', '/class5-{{page}}.html'],
  ['唯美', '/class24-{{page}}.html'],
  ['穿越', '/class17-{{page}}.html'],
  ['贵族', '/class18-{{page}}.html'],
  ['校园', '/class19-{{page}}.html'],
  ['布衣', '/class20-{{page}}.html'],
  ['商战', '/class21-{{page}}.html'],
  ['间谍', '/class23-{{page}}.html'],
  ['同人', '/class11-{{page}}.html'],
  ['文集', '/class25-{{page}}.html'],
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

function requestSearch(ctx, keyword) {
  return ctx.http.request({
    url: `${SOURCE_HOST}/modules/article/search.php`,
    method: 'POST',
    responseType: 'text',
    bodyType: 'form',
    timeoutMs: 15000,
    headers: {
      ...DEFAULT_HEADERS,
      Referer: `${SOURCE_HOST}/`,
    },
    body: {
      searchkey: keyword,
    },
  });
}

function normalizeText(value) {
  return String(value == null ? '' : value).replace(/\s+/g, ' ').trim();
}

function absolute(ctx, url) {
  return String(ctx.utils.absoluteUrl(SOURCE_HOST, url || '') || '');
}

function cleanChapterTitle(title) {
  return normalizeText(
    String(title == null ? '' : title)
      .replace(/^(\d+)[、.，]\s*/g, '')
      .replace(/^正文|^VIP章节|^最新章节/g, '')
      .replace(/\s+/g, ' '),
  );
}

function buildCoverUrl(detailUrl) {
  const match = String(detailUrl || '').match(/\/(\d+)\/?$/);
  if (!match) {
    return '';
  }
  const bookId = Number(match[1]);
  if (Number.isNaN(bookId)) {
    return '';
  }
  const group = Math.floor(bookId / 1000);
  return `${SOURCE_HOST}/${group}/${bookId}/${bookId}s.jpg`;
}

function parseLineItem(ctx, item) {
  const link = item.querySelector('a');
  const href = ctx.html.attr(link, 'href') || '';
  const title = normalizeText(ctx.html.text(link));
  const fullText = normalizeText(ctx.html.text(item));
  const category = normalizeText(fullText.match(/^\[(.*?)\]/)?.[1]);
  const author = normalizeText(fullText.split('/').pop());
  return createBook({
    type: 'novel',
    title,
    author,
    category,
    detailUrl: absolute(ctx, href),
    cover: buildCoverUrl(href),
  });
}

function parseInfoParagraphs(nodes, ctx) {
  return Array.from(nodes).map((node) => normalizeText(ctx.html.text(node)));
}

function stripContentNoise(html) {
  return String(html || '')
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<div[^>]*id="center_tip"[\s\S]*?<\/div>/gi, '')
    .replace(/<br\s*\/?>\s*（本章未完，请点击下一页继续阅读）/gi, '')
    .replace(/最新网址：wap\.80zw\.la/gi, '')
    .replace(/readx;/gi, '')
    .trim();
}

function chapterBaseKey(url) {
  return String(url || '').replace(/(_\d+)?\.html(?:[?#].*)?$/, '');
}

async function fetchTocPageUrls(ctx, tocUrl) {
  const response = await requestText(ctx, tocUrl);
  const doc = ctx.html.parse(response.text);
  const optionNodes = doc.querySelectorAll('select[name="pageselect"] option');
  const urls = [];
  const seen = new Set();

  if (optionNodes.length > 0) {
    for (const node of optionNodes) {
      const href = absolute(ctx, ctx.html.attr(node, 'value'));
      if (!href || seen.has(href)) {
        continue;
      }
      seen.add(href);
      urls.push(href);
    }
    return urls;
  }

  return [tocUrl];
}

async function fetchPagedContent(ctx, startUrl) {
  const visited = new Set();
  const htmlParts = [];
  let currentUrl = startUrl;
  let nextUrl = null;
  const baseKey = chapterBaseKey(startUrl);

  do {
    if (!currentUrl || visited.has(currentUrl)) {
      break;
    }
    visited.add(currentUrl);

    const response = await requestText(ctx, currentUrl, {
      headers: {
        Referer: SOURCE_HOST,
      },
    });
    const doc = ctx.html.parse(response.text);
    const html = ctx.html.innerHtml(doc.querySelector('#nr1'));
    if (html) {
      htmlParts.push(stripContentNoise(html));
    }

    const rawNext =
      ctx.html.attr(doc.querySelector('#pb_next'), 'href') ||
      ctx.html.attr(doc.querySelector('#pt_next'), 'href');
    const resolvedNext = absolute(ctx, rawNext);
    nextUrl =
      resolvedNext &&
      chapterBaseKey(resolvedNext) === baseKey &&
      resolvedNext !== currentUrl
        ? resolvedNext
        : null;
    currentUrl = nextUrl;
  } while (currentUrl);

  return htmlParts.join('\n');
}

export default {
  meta: {
    name: '八零小说',
    group: '🌞',
    author: 'converted_from_test_json',
    description: '由旧规则转换的八零小说脚本源。',
    checkKeyword: '凡人修仙传',
    domains: ['wap.80zw.la', 'www.80zw.la'],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'wap.80zw.la': {
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
    const items = doc.querySelectorAll('.cover .line');
    return ctx.html.collect(items, (item) => parseLineItem(ctx, item));
  },

  async search(ctx, keyword) {
    const response = await requestSearch(ctx, keyword);
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.cover .line');
    return ctx.html.collect(items, (item) => parseLineItem(ctx, item));
  },

  async detail(ctx, book) {
    const response = await requestText(ctx, book.detailUrl);
    const doc = ctx.html.parse(response.text);
    const infoText = parseInfoParagraphs(
      doc.querySelectorAll('.block_txt2 p'),
      ctx,
    );
    const author = normalizeText(
      infoText.find((line) => line.includes('作者：'))?.replace('作者：', ''),
    );
    const category = normalizeText(
      infoText.find((line) => line.includes('分类：'))?.replace('分类：', ''),
    );
    const status = normalizeText(
      infoText.find((line) => line.includes('状态：'))?.replace('状态：', ''),
    );
    const updateTime = normalizeText(
      infoText.find((line) => line.includes('更新：'))?.replace('更新：', ''),
    );
    const latestChapter = normalizeText(
      ctx.html.text(doc.querySelector('.block_txt2 p a')),
    );
    const intro = normalizeText(ctx.html.text(doc.querySelector('.intro_info')))
      .replace(/最新章节推荐地址.*/g, '')
      .trim();
    const tocHref =
      ctx.html.attr(doc.querySelector('.book_more a'), 'href') || '';

    return createBook({
      ...book,
      title: normalizeText(ctx.html.text(doc.querySelector('.block_txt2 h2'))) || book.title,
      author: author || book.author,
      cover: buildCoverUrl(book.detailUrl) || book.cover,
      intro: intro || book.intro,
      status: status || book.status,
      category: category || book.category,
      updateTime: updateTime || book.updateTime,
      latestChapter: latestChapter || book.latestChapter,
      tocUrl: absolute(ctx, tocHref),
    });
  },

  async chapters(ctx, book) {
    const tocUrl = book.tocUrl || absolute(ctx, `${book.detailUrl.replace(/\/?$/, '/') }page-1.html`);
    const pageUrls = await fetchTocPageUrls(ctx, tocUrl);
    const chapters = [];
    const seen = new Set();

    for (const pageUrl of pageUrls) {
      const response = await requestText(ctx, pageUrl);
      const doc = ctx.html.parse(response.text);
      const nodes = doc.querySelectorAll('.book_last dd a');

      for (const node of nodes) {
        const title = cleanChapterTitle(ctx.html.text(node));
        const url = absolute(ctx, ctx.html.attr(node, 'href'));
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
    const content = await fetchPagedContent(ctx, chapter.url);
    return createContent({
      title: chapter.title,
      content,
    });
  },
};
