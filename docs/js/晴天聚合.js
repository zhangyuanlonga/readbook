const HOSTS = [
  'https://v1.gyks.cf',
  'https://v2.gyks.cf',
  'https://v3.gyks.cf',
  'https://v4.gyks.cf',
  'https://v5.gyks.cf',
  'https://v6.gyks.cf',
  'https://v7.gyks.cf',
  'http://101.35.133.34:8888',
];

const DEFAULT_TIMEOUT = 25000;
const DEFAULT_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 15; Mobile Safari/537.36)',
};

const DEFAULT_SETTINGS = {
  server: HOSTS[0],
  tab: '小说',
  sources: '全部',
  source_type: '男频',
  tone_id: '4',
  disabled_sources: '0',
  proxy: '服务器',
  close_img: 'off',
};

const SOURCE_OPTIONS = ['全部', '番茄', '七猫', '书旗', '塔读', 'QQ阅读', '酷我小说'];
const TAB_OPTIONS = ['小说', '听书', '漫画', '短剧'];
const CHANNEL_OPTIONS = ['男频', '女频'];

function createDiscoverCategory(partial = {}) {
  return {
    title: '',
    url: '',
    style: {
      layoutFlexGrow: 1,
      layoutFlexBasisPercent: 0.45,
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

function normalizeText(value) {
  return ctx.utils.normalizeText(value || '');
}

function normalizeBaseUrl(value) {
  return normalizeText(value).replace(/\/+$/, '');
}

async function getSettings(ctx) {
  const saved = await ctx.sourceLogin.getVariableMap({});
  const merged = {
    ...DEFAULT_SETTINGS,
    ...(saved || {}),
  };
  merged.server = normalizeBaseUrl(
    ctx.utils.firstNonEmpty([merged.server, HOSTS[0]], { fallback: HOSTS[0] }),
  );
  merged.tab = normalizeText(
    ctx.utils.firstNonEmpty([merged.tab, DEFAULT_SETTINGS.tab], {
      fallback: DEFAULT_SETTINGS.tab,
    }),
  );
  merged.sources = normalizeText(
    ctx.utils.firstNonEmpty([merged.sources, DEFAULT_SETTINGS.sources], {
      fallback: DEFAULT_SETTINGS.sources,
    }),
  );
  merged.source_type = normalizeText(
    ctx.utils.firstNonEmpty([merged.source_type, DEFAULT_SETTINGS.source_type], {
      fallback: DEFAULT_SETTINGS.source_type,
    }),
  );
  merged.tone_id = normalizeText(
    ctx.utils.firstNonEmpty([merged.tone_id, DEFAULT_SETTINGS.tone_id], {
      fallback: DEFAULT_SETTINGS.tone_id,
    }),
  );
  merged.disabled_sources = normalizeText(
    ctx.utils.firstNonEmpty(
      [merged.disabled_sources, DEFAULT_SETTINGS.disabled_sources],
      { fallback: DEFAULT_SETTINGS.disabled_sources },
    ),
  );
  merged.proxy = normalizeText(
    ctx.utils.firstNonEmpty([merged.proxy, DEFAULT_SETTINGS.proxy], {
      fallback: DEFAULT_SETTINGS.proxy,
    }),
  );
  merged.close_img = normalizeText(
    ctx.utils.firstNonEmpty([merged.close_img, DEFAULT_SETTINGS.close_img], {
      fallback: DEFAULT_SETTINGS.close_img,
    }),
  );
  return merged;
}

async function saveSettingsFromForm(ctx, formData = {}) {
  const current = await getSettings(ctx);
  const customServer = normalizeBaseUrl(formData['自定义服务器(可不填)']);
  const selectServer = normalizeBaseUrl(formData['服务器']);
  const customSource = normalizeText(formData['自定义搜索源(多个用英文,分割)']);
  const selectSource = normalizeText(formData['来源']);
  const next = {
    ...current,
    server: customServer || selectServer || current.server,
    tab: normalizeText(formData['当前模式']) || current.tab,
    sources: customSource || selectSource || current.sources,
    source_type: normalizeText(formData['男/女频道']) || current.source_type,
  };
  await ctx.sourceLogin.setVariable(JSON.stringify(next));
  return next;
}

function buildCookieHeader(qttoken, deviceId) {
  const token = normalizeText(qttoken);
  if (!token) {
    return '';
  }
  const normalizedDeviceId = normalizeText(deviceId) || 'appread-device';
  return `qttoken=${token};deviceId=${normalizedDeviceId}`;
}

async function getDeviceId(ctx) {
  const device = await ctx.utils.getDeviceInfo();
  return normalizeText(
    ctx.utils.firstNonEmpty([
      device?.installId,
      device?.deviceId,
      device?.id,
      device?.platform,
    ]),
  ) || 'appread-device';
}

async function saveAuthState(ctx, qttoken, deviceId, extraInfo = {}) {
  const cookie = buildCookieHeader(qttoken, deviceId);
  if (!cookie) {
    return;
  }
  const currentInfo = await ctx.sourceLogin.getInfoMap();
  await ctx.sourceLogin.putHeader(
    JSON.stringify({
      cookie,
      qttoken: normalizeText(qttoken),
      deviceId: normalizeText(deviceId),
    }),
  );
  await ctx.sourceLogin.putInfo(
    JSON.stringify({
      ...currentInfo,
      ...extraInfo,
      密钥: normalizeText(qttoken),
    }),
  );
}

async function validateKeyLogin(ctx, baseUrl, qttoken) {
  const deviceId = await getDeviceId(ctx);
  const cookie = buildCookieHeader(qttoken, deviceId);
  const response = await requestJson(ctx, `${baseUrl}/user_api`, {
    method: 'POST',
    headers: {
      cookie,
    },
  });
  const payload = response.json || {};
  if (payload?.id == null && !normalizeText(payload?.email)) {
    throw new Error('密钥校验失败');
  }
  await saveAuthState(ctx, qttoken, deviceId, {
    邮箱: normalizeText(payload.email),
  });
  return payload;
}

async function loginWithEmail(ctx, baseUrl, email, password) {
  const response = await requestJson(ctx, `${baseUrl}/login_api`, {
    method: 'POST',
    bodyType: 'json',
    headers: {
      'Content-Type': 'application/json',
    },
    body: {
      register_email: email,
      password,
    },
  });
  const payload = response.json || {};
  if (String(payload.code) !== '0' || !normalizeText(payload.key)) {
    throw new Error(normalizeText(payload.msg) || '登录失败');
  }
  const deviceId = await getDeviceId(ctx);
  await saveAuthState(ctx, payload.key, deviceId, {
    邮箱: email,
    密钥: normalizeText(payload.key),
  });
  return payload;
}

function cleanTitle(value) {
  return normalizeText(String(value || '').replace(/（别名：.*?）/g, ''));
}

function normalizeTags(value) {
  return String(value || '')
    .split(/[,\s]+/)
    .map((item) => normalizeText(item))
    .filter(Boolean);
}

function parseBook(item, settings) {
  const bookId = normalizeText(item.book_id);
  const source = normalizeText(item.source || settings.sources);
  const tab = normalizeText(item.tab || settings.tab || '小说');
  const detailUrl = `${normalizeBaseUrl(settings.server)}/detail?book_id=${encodeURIComponent(bookId)}&source=${encodeURIComponent(source)}&tab=${encodeURIComponent(tab)}`;
  const tocUrl = `${normalizeBaseUrl(settings.server)}/catalog?book_id=${encodeURIComponent(bookId)}&source=${encodeURIComponent(source)}&tab=${encodeURIComponent(tab)}`;
  return createBook({
    title: cleanTitle(item.book_name),
    author: normalizeText(item.author),
    cover: normalizeText(item.thumb_url),
    intro: normalizeText(item.abstract),
    status: normalizeText(item.status),
    category: normalizeText(item.category),
    score: normalizeText(item.score),
    wordCount: normalizeText(item.word_number),
    updateTime: normalizeText(item.last_chapter_update_time),
    tags: normalizeTags(item.tags),
    latestChapter: normalizeText(
      ctx.utils.firstNonEmpty([
        item.last_chapter_title,
        item.last_update_time,
      ]),
    ),
    detailUrl,
    tocUrl,
    extra: {
      bookId,
      source,
      tab,
      role: normalizeText(item.role),
      bookUrl: normalizeText(item.book_url),
      tocUrlRaw: normalizeText(item.toc_url),
      detailUrlRaw: normalizeText(item.detail_url),
      copyrightInfo: normalizeText(item.copyright_info),
      bookTts: normalizeText(item.book_tts),
    },
  });
}

function buildDetailVariable(book) {
  return JSON.stringify({
    custom: normalizeText(book?.extra?.custom || ''),
  });
}

async function requestJson(ctx, url, { method = 'GET', query, body, bodyType, headers } = {}) {
  return await ctx.http.request({
    url,
    method,
    query,
    body,
    bodyType,
    timeoutMs: DEFAULT_TIMEOUT,
    responseType: 'json',
    headers: {
      ...DEFAULT_HEADERS,
      ...(headers || {}),
    },
  });
}

async function requestDiscoverStyle(ctx, settings) {
  const response = await requestJson(
    ctx,
    `${settings.server}/discovestyle`,
    {
      query: {
        source: settings.sources,
        source_type: settings.source_type,
        tab: settings.tab,
      },
    },
  );
  return Array.isArray(response.json?.data) ? response.json.data : [];
}

async function loadDetailPayload(ctx, book, settings) {
  const bookId = normalizeText(book?.extra?.bookId);
  const source = normalizeText(book?.extra?.source || settings.sources);
  const tab = normalizeText(book?.extra?.tab || settings.tab);
  if (!bookId || !source || !tab) {
    return null;
  }
  const response = await requestJson(ctx, `${settings.server}/detail`, {
    method: 'POST',
    query: {
      book_id: bookId,
      source,
      tab,
      variable: buildDetailVariable(book),
    },
    bodyType: 'json',
    body: {
      html: '',
    },
  });
  return response.json?.data || null;
}

async function loadCatalogPayload(ctx, book, settings) {
  const bookId = normalizeText(book?.extra?.bookId);
  const source = normalizeText(book?.extra?.source || settings.sources);
  const tab = normalizeText(book?.extra?.tab || settings.tab);
  if (!bookId || !source || !tab) {
    return [];
  }
  const response = await requestJson(ctx, `${settings.server}/catalog`, {
    method: 'POST',
    query: {
      book_id: bookId,
      source,
      tab,
      variable: buildDetailVariable(book),
    },
    bodyType: 'json',
    body: {
      html: '',
    },
  });
  return Array.isArray(response.json?.data) ? response.json.data : [];
}

function extractImageUrls(content) {
  const html = String(content || '');
  const matches = html.match(/<img\b[^>]*src=['"]([^'"]+)['"][^>]*>/gi) || [];
  return matches
    .map((item) => item.match(/src=['"]([^'"]+)['"]/)?.[1] || '')
    .map((item) => normalizeText(item))
    .filter(Boolean);
}

function normalizeContentText(content) {
  const html = String(content || '');
  if (!html.trim()) {
    return '';
  }
  return normalizeText(ctx.utils.htmlFormat(html));
}

async function applySettingsAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result);
  await ctx.ui.longToast(`已保存书源设置：${settings.sources} / ${settings.tab}`);
  return '设置已保存';
}

async function clearSettingsAction(ctx) {
  await ctx.sourceLogin.removeHeader();
  await ctx.sourceLogin.removeInfo();
  await ctx.sourceLogin.removeVariable();
  await ctx.ui.longToast('已清空晴天聚合登录态和书源设置。');
  return '已清空设置';
}

async function logoutAction(ctx) {
  await ctx.sourceLogin.removeHeader();
  await ctx.ui.longToast('已退出晴天聚合登录。');
  return '已退出登录';
}

export default {
  meta: {
    name: '晴天聚合',
    group: '聚合',
    author: 'codex-migration',
    description:
      '从阅读 JSON 迁移的晴天聚合首版。当前优先支持后台登录、搜索、发现、详情、目录与正文主链路；本地代理、评论、番茄书架同步等高级能力暂未迁移。',
    checkKeyword: '我的26岁女房客@番茄',
    domains: HOSTS.map((item) => item.replace(/^https?:\/\//, '')),
    homepage: HOSTS[0],
    capabilities: ['discover', 'search', 'detail', 'chapters', 'content'],
  },

  loginUi: async function(ctx) {
    const info = await ctx.sourceLogin.getInfoMap();
    const settings = await getSettings(ctx);
    return [
      {
        name: '服务器',
        type: 'select',
        chars: HOSTS,
        default: settings.server,
      },
      {
        name: '自定义服务器(可不填)',
        type: 'text',
        default: info['自定义服务器(可不填)'] || '',
      },
      {
        name: '邮箱',
        type: 'text',
        default: info['邮箱'] || '',
      },
      {
        name: '密码',
        type: 'password',
        default: info['密码'] || '',
      },
      {
        name: '密钥',
        type: 'password',
        default: info['密钥'] || '',
      },
      {
        name: '来源',
        type: 'select',
        chars: SOURCE_OPTIONS,
        default: settings.sources,
      },
      {
        name: '自定义搜索源(多个用英文,分割)',
        type: 'text',
        default: info['自定义搜索源(多个用英文,分割)'] || '',
      },
      {
        name: '当前模式',
        type: 'select',
        chars: TAB_OPTIONS,
        default: settings.tab,
      },
      {
        name: '男/女频道',
        type: 'select',
        chars: CHANNEL_OPTIONS,
        default: settings.source_type,
      },
      {
        name: '♥登录书源',
        type: 'button',
        action: 'result = await source.login(ctx, result);',
      },
      {
        name: '✨应用设置',
        type: 'button',
        action: 'result = await applySettingsAction(ctx, result);',
      },
      {
        name: '🔚 退出登录',
        type: 'button',
        action: 'result = await logoutAction(ctx);',
      },
      {
        name: '⛔️清空设置',
        type: 'button',
        action: 'result = await clearSettingsAction(ctx);',
      },
      {
        name: '📐 使用说明',
        type: 'button',
        action: "await ctx.ui.longToast('晴天聚合首版当前优先支持后台登录、搜索、发现、详情、目录与正文。复杂控制台、本地代理、评论与同步能力后续补充。');",
      },
    ];
  },

  login: async function(ctx, result) {
    const settings = await saveSettingsFromForm(ctx, result || {});
    const email = normalizeText(result?.邮箱);
    const password = normalizeText(result?.密码);
    const key = normalizeText(result?.密钥);

    await ctx.sourceLogin.putInfo(
      JSON.stringify({
        ...(await ctx.sourceLogin.getInfoMap()),
        ...(result || {}),
      }),
    );

    if (email && password) {
      await loginWithEmail(ctx, settings.server, email, password);
      await ctx.ui.longToast('晴天聚合登录成功。');
      return '登录成功';
    }

    if (key) {
      await validateKeyLogin(ctx, settings.server, key);
      await ctx.ui.longToast('晴天聚合密钥登录成功。');
      return '登录成功';
    }

    await ctx.ui.longToast('未填写登录凭据，已仅保存书源设置。');
    return '已保存设置';
  },

  async discoverCategories(ctx) {
    const settings = await getSettings(ctx);
    const items = await requestDiscoverStyle(ctx, settings);
    return items
      .filter((item) => normalizeText(item.url))
      .map((item) =>
        createDiscoverCategory({
          title: normalizeText(item.title),
          url: normalizeText(item.url),
          style: {
            layoutFlexGrow: Number(item.style?.layoutFlexGrow || 1),
            layoutFlexBasisPercent: Number(
              item.style?.layoutFlexBasisPercent || 0.45,
            ),
          },
          extra: {
            source: settings.sources,
            tab: settings.tab,
          },
        }),
      );
  },

  async discoverBooks(ctx, category, page, pageSize) {
    const url = normalizeText(category?.url).replace('{{page}}', String(page || 1));
    if (!url) {
      return [];
    }
    const response = await requestJson(ctx, url);
    const settings = await getSettings(ctx);
    const list = Array.isArray(response.json?.data) ? response.json.data : [];
    return list.map((item) => parseBook(item, settings));
  },

  async search(ctx, keyword) {
    const settings = await getSettings(ctx);
    let searchKeyword = normalizeText(keyword);
    let tab = settings.tab;
    let sources = settings.sources;

    if (/^[xxttmmdd][:：]/i.test(searchKeyword)) {
      const prefix = searchKeyword.slice(0, 1).toLowerCase();
      tab = ({
        x: '小说',
        t: '听书',
        m: '漫画',
        d: '短剧',
      })[prefix] || tab;
      searchKeyword = searchKeyword.slice(2).trim();
    }

    if (searchKeyword.includes('@')) {
      const parts = searchKeyword.split('@');
      searchKeyword = normalizeText(parts[0]);
      sources = normalizeText(parts[1]) || sources;
    }

    const response = await requestJson(ctx, `${settings.server}/search`, {
      query: {
        title: searchKeyword,
        tab,
        source: sources,
        page: '1',
        disabled_sources: settings.disabled_sources,
      },
    });
    const list = Array.isArray(response.json?.data) ? response.json.data : [];
    return list.map((item) => parseBook(item, { ...settings, tab, sources }));
  },

  async detail(ctx, book) {
    const settings = await getSettings(ctx);
    const payload = await loadDetailPayload(ctx, book, settings);
    if (!payload) {
      return book;
    }
    const merged = parseBook(payload, settings);
    return createBook({
      ...merged,
      intro: normalizeText(
        ctx.utils.firstNonEmpty([
          payload.abstract,
          merged.intro,
          book.intro,
        ]),
      ),
      extra: {
        ...book.extra,
        ...merged.extra,
        detailPayload: payload,
      },
    });
  },

  async chapters(ctx, book) {
    const settings = await getSettings(ctx);
    const list = await loadCatalogPayload(ctx, book, settings);
    return list.map((item, index) =>
      createChapter({
        title: normalizeText(item.title) || `第 ${index + 1} 章`,
        url: normalizeText(item.content_url)
          ? `${settings.server}${normalizeText(item.content_url)}`
          : '',
        isVolume: item.is_volume === true || normalizeText(item.source) === '卷',
        isVip: item.is_pay === true,
        isPay: item.is_pay === true,
        updateTime: normalizeText(item.first_pass_time),
        extra: {
          itemId: normalizeText(item.item_id),
          source: normalizeText(item.source || book?.extra?.source),
          tab: normalizeText(item.tab || book?.extra?.tab),
          tocUrlRaw: normalizeText(item.toc_url),
          contentUrlRaw: normalizeText(item.content_url),
        },
      }),
    );
  },

  async content(ctx, book, chapter) {
    const settings = await getSettings(ctx);
    const itemId = normalizeText(chapter?.extra?.itemId);
    const source = normalizeText(chapter?.extra?.source || book?.extra?.source);
    const tab = normalizeText(chapter?.extra?.tab || book?.extra?.tab || settings.tab);
    if (!itemId || !source || !tab) {
      return createContent({
        title: chapter?.title || '',
        content: '章节参数不完整，无法加载正文。',
      });
    }

    const custom = await ctx.bookState.getCustom(book);
    const response = await requestJson(ctx, `${settings.server}/content`, {
      method: 'POST',
      bodyType: 'json',
      headers: {
        'Content-Type': 'application/json',
      },
      body: {
        html: '',
        item_id: itemId,
        source,
        tab,
        tone_id: settings.tone_id,
        variable: JSON.stringify({
          custom: normalizeText(custom),
        }),
        version: '4.11.5.1',
      },
    });

    const payload = response.json || {};
    const rawContent = String(payload.content || '');
    if (!rawContent.trim()) {
      return createContent({
        title: normalizeText(payload.title) || chapter.title,
        content: normalizeText(payload.msg) || '正文为空或当前模式暂不支持。',
      });
    }

    const imageUrls = settings.close_img === 'on' ? [] : extractImageUrls(rawContent);
    const textContent = normalizeContentText(
      settings.close_img === 'on'
        ? rawContent.replace(/<img\b[^>]*>/gi, '')
        : rawContent,
    );

    if (imageUrls.length > 0 && !textContent) {
      return createContent({
        title: normalizeText(payload.title) || chapter.title,
        images: imageUrls,
        content: '',
      });
    }

    return createContent({
      title: normalizeText(payload.title) || chapter.title,
      content: textContent || rawContent,
      images: imageUrls.length > 0 && !textContent ? imageUrls : [],
      extra: {
        source,
        tab,
      },
    });
  },
};
