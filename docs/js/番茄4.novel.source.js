const SOURCE_HOST = 'https://fanqie.shrtxs.cn';
const SEARCH_API = `${SOURCE_HOST}/search`;
const DETAIL_API = `${SOURCE_HOST}/detail`;
const TOC_API = `${SOURCE_HOST}/catolog`;
const CONTENT_API = `${SOURCE_HOST}/content`;
const DISCOVER_FRONT_API = `${SOURCE_HOST}/reading/bookapi/new_category/front/v/`;
const DISCOVER_LANDING_API =
  `${SOURCE_HOST}/reading/bookapi/new_category/landing/v/`;

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
    images: [],
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
    timeoutMs: 12000,
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

function cleanupHtmlText(value) {
  return normalizeText(String(value == null ? '' : value).replace(/<[^>]+>/g, ' '));
}

function formatTimestamp(ctx, seconds) {
  const numeric = Number(seconds || 0);
  if (!numeric) {
    return '';
  }
  return String(ctx.utils.timeFormat(numeric * 1000, 'yyyy-MM-dd HH:mm:ss') || '');
}

function statusFromCreationStatus(value) {
  const text = normalizeText(value);
  if (text === '0') {
    return '已完结';
  }
  if (text === '1') {
    return '连载';
  }
  if (text === '4') {
    return '断更';
  }
  return '';
}

function parseJsonString(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const text = value.trim();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (_) {
    return null;
  }
}

function parseCategoryNames(value) {
  const parsed = parseJsonString(value);
  if (Array.isArray(parsed)) {
    return parsed
      .map((item) => {
        if (item && typeof item === 'object') {
          return normalizeText(item.name || item.Name);
        }
        return '';
      })
      .filter(Boolean);
  }

  return normalizeText(value)
    .split(',')
    .map((item) => normalizeText(item))
    .filter(Boolean);
}

function parseTagNames(value) {
  return normalizeText(value)
    .split(',')
    .map((item) => normalizeText(item))
    .filter(Boolean);
}

function dedupeStrings(values) {
  const seen = new Set();
  const result = [];
  for (let i = 0; i < values.length; i += 1) {
    const item = normalizeText(values[i]);
    if (!item || seen.has(item)) {
      continue;
    }
    seen.add(item);
    result.push(item);
  }
  return result;
}

function parseQuery(url) {
  const text = String(url || '');
  const queryIndex = text.indexOf('?');
  if (queryIndex < 0) {
    return {};
  }

  const query = text.slice(queryIndex + 1);
  const result = {};
  query.split('&').forEach((part) => {
    if (!part) {
      return;
    }
    const pairIndex = part.indexOf('=');
    const key = pairIndex >= 0 ? part.slice(0, pairIndex) : part;
    const value = pairIndex >= 0 ? part.slice(pairIndex + 1) : '';
    result[decodeURIComponent(key)] = decodeURIComponent(value);
  });
  return result;
}

function withQuery(url, params) {
  const text = String(url || '');
  const base = text.split('?')[0];
  const merged = {
    ...parseQuery(text),
    ...(params || {}),
  };

  const query = Object.keys(merged)
    .filter((key) => merged[key] != null && String(merged[key]).trim() !== '')
    .map(
      (key) =>
        `${encodeURIComponent(key)}=${encodeURIComponent(String(merged[key]))}`,
    )
    .join('&');

  return query ? `${base}?${query}` : base;
}

function readQueryParam(url, key) {
  const query = parseQuery(url);
  return normalizeText(query[key]);
}

function parseBookIdFromUrl(url) {
  return normalizeText(readQueryParam(url, 'bookid') || readQueryParam(url, 'book_id'));
}

function buildDetailUrl(bookId) {
  return withQuery(DETAIL_API, {
    bookid: bookId,
    type: 'novel',
  });
}

function buildTocUrl(bookId) {
  return withQuery(TOC_API, {
    bookid: bookId,
    type: 'novel',
  });
}

function buildContentUrl(itemId, bookId) {
  return withQuery(CONTENT_API, {
    item_id: itemId,
    type: 'novel',
    book_id: bookId,
  });
}

function extractPayloadData(response, label) {
  const payload = response && response.json ? response.json : null;
  if (!payload || typeof payload !== 'object') {
    throw new Error(`${label} 返回为空。`);
  }

  const code =
    payload.code != null
      ? String(payload.code)
      : payload.status != null
        ? String(payload.status)
        : '';
  if (code && code !== '0' && code.toLowerCase() !== 'success') {
    throw new Error(`${label} 失败: ${payload.message || payload.msg || code}`);
  }

  return payload;
}

function flattenSearchItems(tab) {
  const rows = Array.isArray(tab && tab.data) ? tab.data : [];
  const result = [];
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i] || {};
    const items = Array.isArray(row.book_data) ? row.book_data : [];
    for (let j = 0; j < items.length; j += 1) {
      result.push(items[j]);
    }
  }
  return result;
}

function mapItemToBook(ctx, item) {
  const bookId = normalizeText(item && item.book_id);
  const tags = dedupeStrings(
    parseTagNames(item && item.tags).concat(parseCategoryNames(item && item.category_schema)),
  );

  return createBook({
    title: normalizeText(item && item.book_name),
    author: normalizeText(item && item.author),
    cover: normalizeText(item && item.thumb_url),
    intro: normalizeMultilineText(item && (item.abstract || item.book_abstract_v2)),
    status: statusFromCreationStatus(item && item.creation_status),
    category: normalizeText(item && item.category),
    score: normalizeText(item && item.score),
    wordCount: normalizeText(item && item.word_number),
    updateTime: formatTimestamp(ctx, item && (item.last_publish_time || item.last_chapter_update_time)),
    tags,
    latestChapter: normalizeText(item && item.last_chapter_title),
    detailUrl: buildDetailUrl(bookId),
    tocUrl: buildTocUrl(bookId),
  });
}

function extractNovelTitle(html) {
  const match = String(html || '').match(
    /<div[^>]*class=["']tt-title["'][^>]*>([\s\S]*?)<\/div>/i,
  );
  return cleanupHtmlText(match ? match[1] : '');
}

function extractNovelBody(html) {
  const text = String(html || '');
  const article = text.match(/<article[^>]*>[\s\S]*<\/article>/i);
  if (article) {
    return article[0];
  }
  return text;
}

function discoverConfigs() {
  return [
    { tabType: 1, title: '男生', gender: 1 },
    { tabType: 0, title: '女生', gender: 0 },
    { tabType: 2, title: '出版', gender: 1 },
  ];
}

export default {
  meta: {
    name: '番茄小说（迁移版）',
    group: '有发现',
    author: 'codex-migration',
    description: '从 docs/js/番茄4.json 中只提取小说链路后的脚本源。',
    checkKeyword: '我不是戏神',
    domains: ['fanqie.shrtxs.cn'],
    homepage: SOURCE_HOST,
    enabled: false,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'fanqie.shrtxs.cn': {
        minIntervalMs: 600,
      },
    },
  },

  async search(ctx, keyword) {
    let normalizedKeyword = String(keyword == null ? '' : keyword).trim();
    if (
      normalizedKeyword.toLowerCase().startsWith('n:') ||
      normalizedKeyword.toLowerCase().startsWith('n：')
    ) {
      normalizedKeyword = normalizedKeyword.slice(2).trim();
    }

    if (/^\d{10,}$/.test(normalizedKeyword)) {
      return [
        createBook({
          title: `番茄作品 ${normalizedKeyword}`,
          detailUrl: buildDetailUrl(normalizedKeyword),
          tocUrl: buildTocUrl(normalizedKeyword),
        }),
      ];
    }

    const response = await requestJson(ctx, SEARCH_API, {
      query: {
        query: normalizedKeyword,
        offset: '0',
        tab_type: '3',
      },
    });
    const payload = extractPayloadData(response, '搜索');
    const tabs = Array.isArray(payload.search_tabs) ? payload.search_tabs : [];
    const bookTab = tabs.find((item) => Number(item && item.tab_type) === 3);
    const items = flattenSearchItems(bookTab);

    return items.map((item) => mapItemToBook(ctx, item));
  },

  async detail(ctx, book) {
    const bookId = parseBookIdFromUrl(book.detailUrl || book.tocUrl);
    if (!bookId) {
      throw new Error('详情阶段缺少 bookId。');
    }

    const response = await requestJson(ctx, DETAIL_API, {
      query: {
        bookid: bookId,
      },
    });
    const payload = extractPayloadData(response, '详情');
    const detail = payload.data || {};
    const tags = dedupeStrings(
      parseTagNames(detail.tags).concat(parseCategoryNames(detail.category_schema)),
    );

    return createBook({
      ...book,
      title: normalizeText(detail.book_name) || book.title,
      author: normalizeText(detail.author) || book.author,
      cover: normalizeText(detail.thumb_url) || book.cover,
      intro: normalizeMultilineText(detail.abstract || detail.book_abstract_v2) || book.intro,
      status: statusFromCreationStatus(detail.creation_status || detail.status),
      category: normalizeText(detail.category) || book.category,
      score: normalizeText(detail.score) || book.score,
      wordCount: normalizeText(detail.word_number) || book.wordCount,
      updateTime:
        formatTimestamp(ctx, detail.last_chapter_update_time || detail.last_publish_time) ||
        book.updateTime,
      tags: tags.length ? tags : book.tags,
      latestChapter: normalizeText(detail.last_chapter_title) || book.latestChapter,
      detailUrl: buildDetailUrl(bookId),
      tocUrl: buildTocUrl(bookId),
    });
  },

  async chapters(ctx, book) {
    const bookId = parseBookIdFromUrl(book.tocUrl || book.detailUrl);
    if (!bookId) {
      throw new Error('目录阶段缺少 bookId。');
    }

    const response = await requestJson(ctx, TOC_API, {
      query: {
        bookid: bookId,
      },
    });
    const payload = extractPayloadData(response, '目录');
    const items =
      payload.data && Array.isArray(payload.data.item_data_list)
        ? payload.data.item_data_list
        : [];

    const chapters = [];
    let currentVolume = '';

    for (let index = 0; index < items.length; index += 1) {
      const item = items[index] || {};
      const volumeName = normalizeText(item.volume_name);
      if (
        volumeName &&
        volumeName !== '第一卷：默认' &&
        volumeName !== currentVolume
      ) {
        currentVolume = volumeName;
        chapters.push(
          createChapter({
            title: volumeName,
            url: '',
            isVolume: true,
          }),
        );
      }

      const formattedTime = formatTimestamp(ctx, item.first_pass_time);
      const chapterWordCount = normalizeText(item.chapter_word_number);
      chapters.push(
        createChapter({
          title: normalizeText(item.title),
          url: buildContentUrl(item.item_id, bookId),
          updateTime:
            formattedTime && chapterWordCount && chapterWordCount !== '0'
              ? `${formattedTime} | ${chapterWordCount}字`
              : formattedTime,
          extra: {
            itemId: normalizeText(item.item_id),
            bookId,
          },
        }),
      );
    }

    return chapters;
  },

  async content(ctx, book, chapter) {
    const itemId = normalizeText(readQueryParam(chapter.url, 'item_id'));
    if (!itemId) {
      throw new Error('正文阶段缺少 itemId。');
    }

    const response = await requestJson(ctx, CONTENT_API, {
      query: {
        item_id: itemId,
        type: 'novel',
      },
    });
    const payload = extractPayloadData(response, '正文');
    const rawContent = String(payload.content == null ? '' : payload.content);

    return createContent({
      title: extractNovelTitle(rawContent) || chapter.title,
      content: extractNovelBody(rawContent),
    });
  },

  async discoverCategories(ctx) {
    const categories = [];
    const configs = discoverConfigs();

    for (let i = 0; i < configs.length; i += 1) {
      const config = configs[i];
      const response = await requestJson(ctx, DISCOVER_FRONT_API, {
        query: {
          update_version_code: '99999',
          distinct_style: '1',
          new_category_tab: String(config.tabType),
        },
      });
      const payload = extractPayloadData(response, `${config.title} 发现分类`);
      const tabData =
        payload.data &&
        payload.data.category_tab_data &&
        Array.isArray(payload.data.category_tab_data.cell_data)
          ? payload.data.category_tab_data
          : null;
      if (!tabData) {
        continue;
      }

      const seen = new Set();
      for (let rowIndex = 0; rowIndex < tabData.cell_data.length; rowIndex += 1) {
        const row = tabData.cell_data[rowIndex] || {};
        const atoms = Array.isArray(row.atom_data) ? row.atom_data : [];
        for (let atomIndex = 0; atomIndex < atoms.length; atomIndex += 1) {
          const atom = atoms[atomIndex] || {};
          const category = atom.category_data || {};
          const categoryId = normalizeText(category.category_id);
          const name = normalizeText(category.name);
          if (!categoryId || !name || seen.has(categoryId)) {
            continue;
          }
          seen.add(categoryId);
          categories.push(
            createDiscoverCategory({
              title: `${config.title} · ${name}`,
              url: withQuery(DISCOVER_LANDING_API, {
                category_id: categoryId,
                gender: config.gender,
                genre: '0',
                genre_type: String(config.tabType),
              }),
              style: {
                layoutFlexGrow: 1,
                layoutFlexBasisPercent: 50,
              },
            }),
          );
        }
      }
    }

    return categories;
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const requestUrl = withQuery(category.url, {
      limit: String(pageSize || 20),
      offset: String(Math.max(0, page - 1) * (pageSize || 20)),
    });
    const response = await requestJson(ctx, requestUrl);
    const payload = extractPayloadData(response, `发现书籍 ${category.title}`);
    const items =
      payload.data &&
      (payload.data.book_info || payload.data.book_list || payload.data.data);

    if (!Array.isArray(items)) {
      return [];
    }

    return items.map((item) => mapItemToBook(ctx, item));
  },
};
