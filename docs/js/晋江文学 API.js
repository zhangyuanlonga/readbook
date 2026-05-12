const API_HOST = 'https://android.jjwxc.net';
const APP_API_HOST = 'https://app.jjwxc.org';
const MOBILE_HOST = 'https://m.jjwxc.net';
const REQUEST_TIMEOUT = 20000;
const DEFAULT_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 15; Mobile Safari/537.36)',
  versiontype: 'reading',
};
const DISCOVER_CHANNELS = [
  ['古言推荐', `${MOBILE_HOST}/channel/index/gy`, 'html'],
  ['现言推荐', `${MOBILE_HOST}/channel/index/xy`, 'html'],
  ['纯爱推荐', `${MOBILE_HOST}/channel/index/dm`, 'html'],
  ['百合推荐', `${MOBILE_HOST}/channel/index/bh`, 'html'],
  ['无CP+推荐', `${MOBILE_HOST}/channel/index/nocp`, 'html'],
  ['今日限免', `${APP_API_HOST}/bookstore/getFullPage?channel=novelfree`, 'json'],
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

function normalizeText(value) {
  return ctx.utils.normalizeText(value || '');
}

function normalizeList(value) {
  return String(ctx.utils.firstNonEmpty([value], { fallback: '' }))
    .split(/[,\s]+/)
    .map((item) => normalizeText(item))
    .filter(Boolean);
}

async function requestJson(ctx, url, { method = 'GET', query, body, bodyType } = {}) {
  return await ctx.http.request({
    url,
    method,
    query,
    body,
    bodyType,
    timeoutMs: REQUEST_TIMEOUT,
    responseType: 'json',
    headers: DEFAULT_HEADERS,
  });
}

async function requestText(ctx, url, { method = 'GET', query, body, bodyType, charset = 'gb18030' } = {}) {
  return await ctx.http.request({
    url,
    method,
    query,
    body,
    bodyType,
    timeoutMs: REQUEST_TIMEOUT,
    responseType: 'text',
    charset,
    headers: DEFAULT_HEADERS,
  });
}

async function requestChapterPayload(ctx, url) {
  return await ctx.http.request({
    url,
    method: 'GET',
    timeoutMs: REQUEST_TIMEOUT,
    responseType: 'text',
    headers: DEFAULT_HEADERS,
  });
}

function detailUrlForNovel(novelId) {
  return `${API_HOST}/androidapi/novelbasicinfo?novelId=${encodeURIComponent(String(novelId || '').trim())}`;
}

function tocUrlForNovel(novelId, token = '') {
  const base = `${API_HOST}/androidapi/chapterList?novelId=${encodeURIComponent(String(novelId || '').trim())}&more=0&whole=1`;
  return token ? `${base}&token=${encodeURIComponent(token)}` : base;
}

function chapterUrlFor(bookId, chapterId, token = '') {
  const base = `${APP_API_HOST}/androidapi/chapterContent?versionCode=381&novelId=${encodeURIComponent(String(bookId || '').trim())}&chapterId=${encodeURIComponent(String(chapterId || '').trim())}`;
  return token ? `${base}&token=${encodeURIComponent(token)}` : base;
}

function parseStatus(step) {
  return String(step || '') === '2' ? '已完结' : '连载中';
}

function parseCover(detail) {
  return normalizeText(
    ctx.utils.firstNonEmpty([
      detail.originalCover,
      detail.novelCover,
      detail.cover,
    ]),
  );
}

function parseDetailBook(detail, extra = {}) {
  const novelId = normalizeText(detail.novelId || detail.novelid);
  const latestChapterTitle = normalizeText(
    ctx.utils.firstNonEmpty([detail.renewChapterName, detail.lastChapter]),
  );
  const latestUpdateTime = normalizeText(
    ctx.utils.firstNonEmpty([detail.renewDate, detail.chapterdateNewest]),
  );
  return createBook({
    title: normalizeText(detail.novelName || detail.novelname),
    author: normalizeText(detail.authorName || detail.authorname),
    cover: parseCover(detail),
    intro: normalizeText(
      ctx.utils.firstNonEmpty([
        detail.novelIntro,
        detail.novelIntroShort,
        detail.intro,
      ]),
    ),
    status: parseStatus(detail.novelStep),
    category: normalizeText(detail.novelClass),
    score: normalizeText(
      ctx.utils.firstNonEmpty([
        detail.novelReviewScore,
        detail.novelScore,
        detail.ranking,
      ]),
    ),
    wordCount: normalizeText(
      ctx.utils.firstNonEmpty([
        detail.novelsizeformat,
        detail.novelSizeformat,
        detail.novelSize,
      ]),
    ),
    updateTime: latestUpdateTime,
    tags: normalizeList(detail.novelTags || detail.tags),
    latestChapter: latestChapterTitle,
    detailUrl: detailUrlForNovel(novelId),
    tocUrl: tocUrlForNovel(novelId),
    extra: {
      novelId,
      authorId: normalizeText(detail.authorId || detail.authorid),
      protagonist: normalizeText(detail.protagonist),
      costar: normalizeText(detail.costar),
      other: normalizeText(detail.other),
      mainview: normalizeText(detail.mainview),
      isVipBook: String(detail.isVip || detail.isvip || '') === '1',
      ...extra,
    },
  });
}

function resolveNovelId(book) {
  return (
    normalizeText(book?.extra?.novelId) ||
    normalizeText(String(book?.detailUrl || '').match(/novelId=(\d+)/)?.[1]) ||
    normalizeText(String(book?.detailUrl || '').match(/(\d+)(?:[/?#].*)?$/)?.[1])
  );
}

function normalizeToken(value) {
  const raw = String(value || '').trim();
  const matched = raw.match(/\d+_[a-z\d]{16,}/i);
  return normalizeText(matched?.[0] || raw.replace(/^token=/i, '').split('&')[0]);
}

async function getLoginToken(ctx) {
  return normalizeToken(
    await ctx.sourceLogin.getToken({
      headerKeys: ['token', 'Token'],
      infoKeys: ['抓包token登录[与扫码账号三选一,其他登录会让旧token失效,要删除这里]'],
      fallback: '',
    }),
  );
}

function resolveNovelIdFromLink(url) {
  return normalizeText(String(url || '').match(/\/book2\/(\d+)/)?.[1]);
}

function cleanChapterTitle(chapter) {
  const chapterId = normalizeText(chapter.chapterid || chapter.chapterId);
  const rawTitle = normalizeText(chapter.chaptername || chapter.chapterName);
  if (!rawTitle) {
    return chapterId ? `第 ${chapterId} 章` : '未命名章节';
  }
  return rawTitle;
}

function buildChapterExtra(chapter) {
  return {
    chapterId: normalizeText(chapter.chapterid || chapter.chapterId),
    chapterType: normalizeText(chapter.chaptertype || chapter.chapterType),
    chapterIntro: normalizeText(chapter.chapterintro || chapter.chapterIntro),
    isLocked: String(chapter.islock || '') === '1',
    lockMessage: normalizeText(chapter.message || chapter.islockMessage),
    encryptType: normalizeText(chapter.encryptType),
  };
}

async function loadDetailBook(ctx, novelId) {
  if (!novelId) {
    return null;
  }

  try {
    const detailResponse = await requestJson(ctx, detailUrlForNovel(novelId));
    const detailJson = detailResponse.json || {};
    if (!detailJson || !normalizeText(detailJson.novelId || detailJson.novelid)) {
      return null;
    }
    return parseDetailBook(detailJson, { novelId });
  } catch (_) {
    return null;
  }
}

async function parseDiscoverHtmlBooks(ctx, category) {
  const response = await requestText(ctx, category.url);
  const doc = ctx.html.parse(response.text || '');
  const anchors = doc.querySelectorAll('a[href^="/book2/"]');
  const novelIds = [];
  const seen = new Set();

  for (const anchor of anchors) {
    const href = anchor.getAttribute('href') || '';
    const novelId = resolveNovelIdFromLink(href);
    if (!novelId || seen.has(novelId)) {
      continue;
    }
    seen.add(novelId);
    novelIds.push(novelId);
    if (novelIds.length >= 24) {
      break;
    }
  }

  const books = [];
  for (const novelId of novelIds) {
    const detailBook = await loadDetailBook(ctx, novelId);
    if (detailBook != null) {
      books.push(
        createBook({
          ...detailBook,
          extra: {
            ...detailBook.extra,
            discoverCategory: category.title,
          },
        }),
      );
    }
  }
  return books;
}

function parseDiscoverJsonBooks(category, payload) {
  const sections = Array.isArray(payload) ? payload : [];
  const books = [];

  for (const section of sections) {
    const items = Array.isArray(section?.data) ? section.data : [];
    for (const item of items) {
      const novelId = normalizeText(item.novelId || item.novelid);
      if (!novelId) {
        continue;
      }
      books.push(
        parseDetailBook(item, {
          novelId,
          discoverCategory: category.title,
        }),
      );
    }
  }

  return books;
}

function decryptChapterContent(payload) {
  const encrypted = normalizeText(payload.content);
  if (!encrypted) {
    return '';
  }
  return ctx.crypto.decryptPipeline(encrypted, [
    {
      method: 'desDecrypt',
      key: 'KW8Dvm2N',
      iv: '1ae2c94b',
      mode: 'cbc',
      inputEncoding: 'base64',
      outputEncoding: 'utf8',
    },
  ]);
}

function decryptVipEnvelope(rawText, headers = {}) {
  const encrypted = String(rawText || '').trim();
  const accessKey = normalizeText(headers.accesskey || headers.accessKey);
  const keyString = normalizeText(headers.keystring || headers.keyString);
  if (!encrypted || !accessKey || !keyString) {
    return null;
  }

  let checksum = 0;
  for (let index = 0; index < accessKey.length; index += 1) {
    checksum += accessKey.charCodeAt(index);
  }

  const offset = checksum % keyString.length;
  const length = Math.floor(checksum / 65);
  const secret = keyString.substring(
    offset,
    Math.min(keyString.length, offset + length),
  );
  if (!secret) {
    return null;
  }

  const lastCode = accessKey.charCodeAt(accessKey.length - 1);
  const marker = (lastCode & 1) !== 0
    ? encrypted.slice(-12)
    : encrypted.slice(0, 12);
  const cipherText = (lastCode & 1) !== 0
    ? encrypted.slice(0, -12)
    : encrypted.slice(12);
  if (!marker || !cipherText) {
    return null;
  }

  const key = ctx.crypto.md5(`${secret}${marker}`).slice(0, 8);
  const iv = ctx.crypto.md5(marker).slice(0, 8);
  const decrypted = ctx.crypto.decryptPipeline(cipherText, [
    {
      method: 'desDecrypt',
      key,
      iv,
      mode: 'cbc',
      inputEncoding: 'base64',
      outputEncoding: 'utf8',
    },
  ]);
  if (!decrypted) {
    return null;
  }

  try {
    return JSON.parse(decrypted);
  } catch (_) {
    return null;
  }
}

function buildContentMessage(payload, chapterTitle) {
  const chapterIntro = normalizeText(payload.chapterIntro);
  const sayBody = normalizeText(payload.sayBody);
  const pieces = [];
  if (chapterIntro) {
    pieces.push(`【章节简介】\n${chapterIntro}`);
  }
  if (sayBody) {
    pieces.push(`【作者有话说】\n${sayBody}`);
  }
  const extra = pieces.join('\n\n');
  return createContent({
    title: normalizeText(payload.chapterName) || chapterTitle,
    content: [decryptChapterContent(payload), extra].filter(Boolean).join('\n\n'),
  });
}

export default {
  meta: {
    name: '晋江文学a pi',
    group: '站点',
    author: 'codex-migration',
    description:
      '从阅读 JSON 规则迁移的晋江文学首版。当前支持公开搜索、详情、目录、免费正文，以及手动 token 登录后的已购 VIP 正文读取；扫码、账号密码、评论等高级能力仍待迁移。',
    checkKeyword: '凡人修仙传',
    domains: ['android.jjwxc.net', 'app.jjwxc.org', 'm.jjwxc.net'],
    homepage: 'https://m.jjwxc.net/channel/',
    capabilities: ['discover', 'search', 'detail', 'chapters', 'content'],
  },

  loginUi: async function(ctx, result) {
    const info = await ctx.sourceLogin.getInfoMap();
    return [
      {
        name: '抓包token登录[与扫码账号三选一,其他登录会让旧token失效,要删除这里]',
        type: 'password',
        default: info['抓包token登录[与扫码账号三选一,其他登录会让旧token失效,要删除这里]'] || '',
      },
      {
        name: '账号',
        type: 'text',
        default: info['账号'] || '',
      },
      {
        name: '密码',
        type: 'password',
        default: info['密码'] || '',
      },
      {
        name: '验证码（填完验证码后，要点👤登录）',
        type: 'text',
        default: info['验证码（填完验证码后，要点👤登录）'] || '',
      },
      {
        name: '使用说明',
        type: 'button',
        action: "await ctx.ui.longToast('当前最小登录实现已支持手动 token 登录。账号密码、扫码与验证码链路需要后续补充宿主兼容。');",
      },
    ];
  },

  login: async function(ctx, result) {
    const token = normalizeToken(
      ctx.utils.pickField(
        result,
        ['抓包token登录[与扫码账号三选一,其他登录会让旧token失效,要删除这里]'],
        '',
      ),
    );
    await ctx.sourceLogin.putInfo(JSON.stringify(result || {}));
    if (!token) {
      await ctx.ui.longToast('未检测到有效 token。当前版本先支持手动 token 登录。');
      return '未检测到有效 token';
    }
    await ctx.sourceLogin.putHeader(JSON.stringify({ token }));
    await ctx.ui.longToast('已保存晋江 token 登录态，请重新刷新目录或正文。');
    return '登录成功';
  },

  async discoverCategories(ctx) {
    return DISCOVER_CHANNELS.map(([title, url, mode]) =>
      createDiscoverCategory({
        title,
        url,
        style: {
          layoutFlexGrow: 1,
          layoutFlexBasisPercent: 0.33,
        },
        extra: {
          mode,
        },
      }),
    );
  },

  async discoverBooks(ctx, category, page, pageSize) {
    if ((page || 1) > 1) {
      return [];
    }

    const mode = normalizeText(category?.extra?.mode || 'html');
    if (mode === 'json') {
      const response = await requestJson(ctx, category.url);
      return parseDiscoverJsonBooks(category, response.json);
    }
    return await parseDiscoverHtmlBooks(ctx, category);
  },

  async search(ctx, keyword) {
    const response = await requestJson(
      ctx,
      `${API_HOST}/androidapi/search`,
      {
        query: {
          versionCode: '191',
          keyword,
          type: '1',
          page: '1',
          searchType: '8',
          sortMode: 'DESC',
        },
      },
    );
    const items = Array.isArray(response.json?.items) ? response.json.items : [];
    return items
      .map((item) => parseDetailBook(item))
      .filter((book) => book.title && book.detailUrl);
  },

  async detail(ctx, book) {
    const novelId = resolveNovelId(book);
    if (!novelId) {
      return book;
    }

    const detailResponse = await requestJson(ctx, detailUrlForNovel(novelId));
    const extraResponse = await requestJson(
      ctx,
      `${APP_API_HOST}/androidapi/getnovelOtherInfo`,
      {
        query: {
          novelId,
          type: 'novelbasicinfo',
          versionCode: '163',
        },
      },
    );

    const detailJson = detailResponse.json || {};
    const extraJson = extraResponse.json || {};
    const merged = {
      ...detailJson,
      ...extraJson,
    };
    return parseDetailBook(merged, {
      ...book.extra,
      isVipBook: String(detailJson.isVip || '') === '1',
    });
  },

  async chapters(ctx, book) {
    const novelId = resolveNovelId(book);
    if (!novelId) {
      return [];
    }

    const token = await getLoginToken(ctx);
    const response = await requestJson(ctx, tocUrlForNovel(novelId, token));
    const list = Array.isArray(response.json?.chapterlist)
      ? response.json.chapterlist
      : [];

    return list
      .map((chapter) => {
        const extra = buildChapterExtra(chapter);
        const chapterId = extra.chapterId;
        const isVolume = extra.chapterType === '1';
        return createChapter({
          title: cleanChapterTitle(chapter),
          url: isVolume ? '' : chapterUrlFor(novelId, chapterId, token),
          isVolume,
          isVip: String(chapter.isvip || '') === '1',
          isPay:
            String(chapter.isvip || '') === '1' &&
            String(chapter.point || '') !== '0',
          updateTime: normalizeText(chapter.chapterdate),
          extra,
        });
      })
      .filter((chapter) => chapter.isVolume || chapter.url);
  },

  async content(ctx, book, chapter) {
    const token = await getLoginToken(ctx);
    const chapterId = normalizeText(
      chapter?.extra?.chapterId || chapter?.id || '',
    );
    const chapterUrl = normalizeText(
      chapter.url || chapterUrlFor(resolveNovelId(book), chapterId, token),
    );
    if (!chapterUrl) {
      return createContent({
        title: chapter.title,
        content: '当前目录节点是分卷标题，不能直接阅读。',
      });
    }

    const response = await requestChapterPayload(ctx, chapterUrl);
    const rawText = String(response.text || '').trim();
    let payload = {};

    if (rawText.startsWith('{') || rawText.startsWith('[')) {
      try {
        payload = JSON.parse(response.text || '{}');
      } catch (_) {
        payload = {};
      }
    } else if (token) {
      payload = decryptVipEnvelope(rawText, response.headers || {}) || {};
      if (!payload || Object.keys(payload).length === 0) {
        const decrypted = ctx.crypto.desDecrypt({
          data: rawText,
          key: 'KW8Dvm2N',
          iv: '1ae2c94b',
          mode: 'cbc',
          inputEncoding: 'base64',
          outputEncoding: 'utf8',
        });
        return createContent({
          title: chapter.title,
          content: decrypted,
        });
      }
    }

    const code = normalizeText(payload.code);
    const message = normalizeText(payload.message);

    if (code && code !== '0') {
      return createContent({
        title: chapter.title,
        content: message || `正文加载失败（code=${code}）。`,
      });
    }

    if (String(payload.islock || '') === '1') {
      return createContent({
        title: chapter.title,
        content: message || '该章节已锁定，当前版本暂不支持读取。',
      });
    }

    if (!normalizeText(payload.content)) {
      return createContent({
        title: chapter.title,
        content: message || '正文为空或当前章节暂不可读。',
      });
    }

    return buildContentMessage(payload, chapter.title);
  },
};