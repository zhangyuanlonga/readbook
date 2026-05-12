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
  fqpara: 'on',
  reading: '0',
  info: 'on',
  pstyle: '0',
  plcolor: '#000000',
  controlUrl: '',
};

const SOURCE_OPTIONS = ['全部', '番茄', '七猫', '书旗', '塔读', 'QQ阅读', '酷我小说'];
const TAB_OPTIONS = ['小说', '听书', '漫画', '短剧'];
const CHANNEL_OPTIONS = ['男频', '女频'];
const LOCAL_VERSION = '5.4.23';

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
    proxy: normalizeText(formData['阅读代理']) || current.proxy,
    close_img: normalizeText(formData['关闭图片']) || current.close_img,
    disabled_sources:
      normalizeText(formData['搜索全部来源']) || current.disabled_sources,
    fqpara: normalizeText(formData['段评开关']) || current.fqpara,
    reading: normalizeText(formData['同步书架']) || current.reading,
    info: normalizeText(formData['完整简介']) || current.info,
    plcolor: normalizeText(formData['自定义评论颜色(可不填)']) || current.plcolor,
    pstyle: normalizeText(formData['段评气泡样式(0-4)']) || current.pstyle,
  };
  await ctx.sourceLogin.setVariable(JSON.stringify(next));
  return next;
}

async function patchSettings(ctx, patch = {}) {
  const current = await getSettings(ctx);
  const next = {
    ...current,
    ...(patch || {}),
  };
  await ctx.sourceLogin.patchVariable(next);
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

async function getAuthState(ctx) {
  const header = await ctx.sourceLogin.getHeaderMap();
  const info = await ctx.sourceLogin.getInfoMap();
  const qttoken = normalizeText(
    ctx.utils.firstNonEmpty([
      header.qttoken,
      ctx.utils.pickField(header.cookie || '', ['qttoken'], ''),
      info.密钥,
    ]),
  );
  const cookie = normalizeText(
    ctx.utils.firstNonEmpty([header.cookie, buildCookieHeader(qttoken, header.deviceId)]),
  );
  return {
    qttoken,
    cookie,
    deviceId: normalizeText(header.deviceId),
  };
}

async function requestWithAuth(ctx, url, { method = 'GET', query, body, bodyType } = {}) {
  const auth = await getAuthState(ctx);
  if (!auth.cookie) {
    throw new Error('请先登录晴天聚合账号');
  }
  return await requestJson(ctx, url, {
    method,
    query,
    body,
    bodyType,
    headers: {
      cookie: auth.cookie,
    },
  });
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

async function fetchCurrentUser(ctx, settings) {
  const response = await requestWithAuth(ctx, `${settings.server}/user_api`, {
    method: 'POST',
  });
  const payload = response.json || {};
  if (payload?.id == null && !normalizeText(payload?.email)) {
    throw new Error(normalizeText(payload?.msg) || '登录状态无效');
  }
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

async function checkStatusAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const user = await fetchCurrentUser(ctx, settings);
  await ctx.sourceLogin.patchInfo({
    邮箱: normalizeText(user.email),
    密钥: normalizeText(user.user_key),
  });
  const nickname = normalizeText(user.nickname) || '未设置';
  const email = normalizeText(user.email);
  const deviceCount = (() => {
    try {
      const value = ctx.utils.safeJsonParse(user.device, {});
      return String(Object.keys(value || {}).length);
    } catch (_) {
      return normalizeText(user.device) ? '1' : '0';
    }
  })();
  const isVip = user.is_vips ? '已开通' : '未开通';
  const banned = user.is_banned ? '已封禁' : '正常';
  const registerAt = user.register_time
    ? ctx.utils.timeFormat(Number(user.register_time) * 1000, 'yyyy-MM-dd HH:mm:ss')
    : '未知';
  const lastReadAt = user.last_read_time
    ? ctx.utils.timeFormat(Number(user.last_read_time) * 1000, 'yyyy-MM-dd HH:mm:ss')
    : '未阅读';
  return [
    `昵称：${nickname}`,
    `邮箱：${email}`,
    `密钥：${normalizeText(user.user_key).slice(0, 4)}***${normalizeText(user.user_key).slice(-4)}`,
    `注册时间：${registerAt}`,
    `累计阅读：${normalizeText(user.all_read_count) || '0'}`,
    `最后阅读：${lastReadAt}`,
    `在线设备：${deviceCount}`,
    `会员状态：${isVip}`,
    `封禁状态：${banned}`,
  ].join('\n');
}

async function clearDeviceAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const ok = await ctx.ui.confirm({
    title: '清空设备',
    message: '确认清空当前晴天聚合在线设备记录吗？',
    confirmText: '清空',
    cancelText: '取消',
  });
  if (!ok) {
    return '已取消';
  }
  const response = await requestWithAuth(ctx, `${settings.server}/clear`, {
    method: 'POST',
  });
  const payload = response.json || {};
  return String(payload.code) === '0'
    ? '设备清除成功'
    : (normalizeText(payload.msg) || '设备清除失败');
}

async function openUserCenterAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const auth = await getAuthState(ctx);
  if (!auth.qttoken) {
    return '请先登录';
  }
  await ctx.ui.openBrowserAwait({
    url: `${settings.server}/user`,
    title: '晴天聚合后台',
    refetchAfterSuccess: false,
  });
  return '已打开用户后台';
}

async function registerAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  await ctx.ui.openBrowserAwait({
    url: `${settings.server}/register`,
    title: '晴天聚合注册',
    refetchAfterSuccess: false,
  });
  return '已打开注册页面';
}

async function vipAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const auth = await getAuthState(ctx);
  if (!auth.qttoken) {
    return '请先登录';
  }
  await ctx.ui.openBrowserAwait({
    url: `${settings.server}/coffee`,
    title: '晴天聚合会员',
    refetchAfterSuccess: false,
  });
  return '已打开会员页面';
}

async function versionAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  await ctx.ui.openBrowserAwait({
    url: `${settings.server}/version?id=${encodeURIComponent(LOCAL_VERSION)}`,
    title: '晴天聚合更新',
    refetchAfterSuccess: false,
  });
  const response = await requestJson(
    ctx,
    `${settings.server}/version`,
    {
      query: { id: LOCAL_VERSION },
    },
  );
  const payload = response.json || {};
  const latest = normalizeText(payload.rssVersion3);
  const updatedAt = normalizeText(payload.last_updated);
  const logs = payload.update_log || {};
  const lines = [`当前版本：${LOCAL_VERSION}`];
  if (latest) {
    lines.push(`最新版本：${latest}`);
  }
  if (updatedAt) {
    lines.push(`更新时间：${updatedAt}`);
  }
  const recentEntries = Object.entries(logs).slice(0, 6);
  if (recentEntries.length > 0) {
    lines.push('', '更新日志：');
    for (const [version, text] of recentEntries) {
      lines.push(`${version} - ${normalizeText(text)}`);
    }
  }
  return lines.join('\n');
}

async function tutorialAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  await ctx.ui.openBrowserAwait({
    url: `${settings.server}/help`,
    title: '使用说明',
    refetchAfterSuccess: false,
  });
  return [
    '搜索：直接搜全部来源，或用 书名@来源 精准搜索。',
    '模式：支持 小说 / 听书 / 漫画 / 短剧。',
    '设置：先在登录页里保存服务器、来源和模式，再进入发现页刷新。',
    '登录：当前首版优先支持晴天后台账号/密钥登录。',
  ].join('\n');
}

function currentModeLabel(settings) {
  return `${settings.sources} / ${settings.tab} / ${settings.source_type}`;
}

async function toggleInfoAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const nextValue = settings.info === 'off' ? 'on' : 'off';
  const next = await patchSettings(ctx, { info: nextValue });
  return JSON.stringify({
    完整简介: next.info,
    message: nextValue === 'off' ? '已精简详情页简介' : '已恢复详情页详细简介',
  });
}

async function toggleParagraphAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const nextValue = settings.fqpara === 'on' ? 'off' : 'on';
  const next = await patchSettings(ctx, { fqpara: nextValue });
  return JSON.stringify({
    段评开关: next.fqpara,
    message:
      nextValue === 'on'
        ? '段评已开启'
        : '段评已关闭',
  });
}

async function toggleReadingSyncAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const nextValue = settings.reading === '1' ? '0' : '1';
  const next = await patchSettings(ctx, { reading: nextValue });
  return JSON.stringify({
    同步书架: next.reading,
    message:
      nextValue === '1'
        ? '晴天书架同步已开启'
        : '晴天书架同步已关闭',
  });
}

async function toggleSourceTypeAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const nextValue = settings.source_type === '女频' ? '男频' : '女频';
  const next = await patchSettings(ctx, { source_type: nextValue });
  return JSON.stringify({
    '男/女频道': next.source_type,
    message: `发现页已设置为：${nextValue}`,
  });
}

async function toggleDisabledSourcesAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const nextValue = settings.disabled_sources === '1' ? '0' : '1';
  const next = await patchSettings(ctx, {
    disabled_sources: nextValue,
    ...(nextValue === '1' ? { sources: '全部' } : {}),
  });
  return JSON.stringify({
    来源: next.sources,
    搜索全部来源: next.disabled_sources,
    message:
      nextValue === '1'
        ? '强制搜索禁用源已开启，搜索会变慢'
        : '强制搜索禁用源已关闭',
  });
}

async function toggleCloseImageAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const nextValue = settings.close_img === 'on' ? 'off' : 'on';
  const next = await patchSettings(ctx, { close_img: nextValue });
  return JSON.stringify({
    关闭图片: next.close_img,
    message: nextValue === 'on' ? '图片显示已关闭' : '图片显示已开启',
  });
}

async function getMediaAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  return [
    `当前服务器：${settings.server}`,
    `当前来源：${settings.sources}`,
    `当前模式：${settings.tab}`,
    `当前频道：${settings.source_type}`,
  ].join('\n');
}

async function setMediaAction(ctx, result, media) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const allowMap = {
    喜马拉雅: ['听书'],
    番茄: '*',
    七猫: ['小说', '听书', '短剧'],
    全部: '*',
    默认: ['小说'],
  };
  const allow = allowMap[settings.sources] || allowMap.默认;
  const nextMedia =
    allow === '*' || (Array.isArray(allow) && allow.includes(media))
      ? media
      : Array.isArray(allow)
        ? allow[0]
        : '小说';
  const next = await patchSettings(ctx, { tab: nextMedia });
  return JSON.stringify({
    当前模式: next.tab,
    message:
      nextMedia == media
        ? `已切换至：${nextMedia}`
        : `当前来源不支持 ${media}，已自动切换至：${nextMedia}`,
  });
}

async function cycleServerAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const customServer = normalizeBaseUrl(result?.['自定义服务器(可不填)']);
  if (customServer) {
    const next = await patchSettings(ctx, { server: customServer });
    return JSON.stringify({
      服务器: next.server,
      message: `已切换到自定义服务器：${next.server}`,
    });
  }
  const currentIndex = HOSTS.indexOf(settings.server);
  const nextServer = HOSTS[(currentIndex + 1 + HOSTS.length) % HOSTS.length];
  const next = await patchSettings(ctx, { server: nextServer });
  return JSON.stringify({
    服务器: next.server,
    message: `已切换服务器：${next.server}`,
  });
}

async function checkServerAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const startedAt = Date.now();
  const response = await ctx.http.request({
    url: `${settings.server}/health`,
    timeoutMs: 8000,
    responseType: 'json',
    headers: DEFAULT_HEADERS,
  });
  const elapsed = Date.now() - startedAt;
  const payload = response.json || {};
  const healthy = normalizeText(payload.status) === 'healthy';
  return healthy
    ? `服务器可用\n地址：${settings.server}\n耗时：${elapsed}ms`
    : `服务器异常\n地址：${settings.server}\n耗时：${elapsed}ms`;
}

async function openHomeAction() {
  await ctx.ui.openBrowserAwait({
    url: 'http://vip.gyks.cf',
    title: '晴天发布页',
    refetchAfterSuccess: false,
  });
  return '已打开发布页';
}

async function openBookStoreAction() {
  await ctx.ui.openBrowserAwait({
    url: 'https://sk.gyks.cf',
    title: '晴天书库',
    refetchAfterSuccess: false,
  });
  return '已打开晴天书库';
}

async function openRecommendAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  await ctx.ui.openBrowserAwait({
    url: `${settings.server}/put_book`,
    title: '我来推荐',
    refetchAfterSuccess: false,
  });
  return '已打开推荐页面';
}

async function openControlAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  await patchSettings(ctx, { controlUrl: settings.server });
  await ctx.ui.openBrowserAwait({
    url: `${settings.server}/control`,
    title: '晴天设置中心',
    refetchAfterSuccess: false,
  });
  const cookieMap = ctx.cookie.getForUrl(settings.server) || {};
  const patch = {};
  const knownKeys = [
    'server',
    'proxy',
    'tab',
    'source_type',
    'sources',
    'fqpara',
    'disabled_sources',
    'reading',
    'info',
    'close_img',
    'plcolor',
    'pstyle',
  ];
  for (const key of knownKeys) {
    const value = normalizeText(cookieMap[key]);
    if (value) {
      patch[key] = value;
    }
  }
  if (Object.keys(patch).length > 0) {
    const next = await patchSettings(ctx, patch);
    return JSON.stringify({
      服务器: next.server,
      来源: next.sources,
      当前模式: next.tab,
      '男/女频道': next.source_type,
      阅读代理: next.proxy,
      message: '已同步网页版控制台设置',
    });
  }
  return '网页控制台已关闭，未检测到新的设置变更。';
}

async function syncBrowserSettingsAction(ctx, result) {
  return await openControlAction(ctx, result);
}

async function clearBrowserSettingsAction(ctx, result) {
  const settings = await saveSettingsFromForm(ctx, result || {});
  const next = await patchSettings(ctx, {
    server: HOSTS[0],
    proxy: DEFAULT_SETTINGS.proxy,
    tab: DEFAULT_SETTINGS.tab,
    source_type: DEFAULT_SETTINGS.source_type,
    sources: DEFAULT_SETTINGS.sources,
    fqpara: DEFAULT_SETTINGS.fqpara,
    disabled_sources: DEFAULT_SETTINGS.disabled_sources,
    reading: DEFAULT_SETTINGS.reading,
    info: DEFAULT_SETTINGS.info,
  });
  return JSON.stringify({
    服务器: next.server,
    来源: next.sources,
    当前模式: next.tab,
    '男/女频道': next.source_type,
    段评开关: next.fqpara,
    搜索全部来源: next.disabled_sources,
    同步书架: next.reading,
    完整简介: next.info,
    message: '已重置控制台设置到默认值',
  });
}

async function fanqieLoginAction(ctx, result) {
  await saveSettingsFromForm(ctx, result || {});
  await ctx.ui.openBrowserAwait({
    url: 'https://fanqienovel.com/',
    title: '番茄登录',
    refetchAfterSuccess: false,
  });
  const sessionId = normalizeText(
    ctx.cookie.getForUrl('https://fanqienovel.com/', 'sessionid'),
  );
  if (sessionId) {
    const token = `sessionid=${sessionId}`;
    await ctx.sourceLogin.patchInfo({
      '手动填写番茄token(可不填)': token,
    });
    return '番茄登录成功，已同步 sessionid';
  }
  const token = await ctx.ui.prompt({
    title: '番茄登录 Token',
    message: '未自动检测到 sessionid。若网页登录已完成，请手动粘贴 token 或 sessionid。',
    initialValue: result?.['手动填写番茄token(可不填)'] || '',
    confirmText: '保存',
    cancelText: '跳过',
  });
  if (token == null) {
    return '已打开番茄网页登录';
  }
  await ctx.sourceLogin.patchInfo({
    '手动填写番茄token(可不填)': normalizeText(token),
  });
  return '已保存番茄 token';
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
        name: '晴天聚合控制台',
        type: 'divider',
      },
      {
        name: `当前配置：${currentModeLabel(settings)}`,
        type: 'note',
      },
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
        name: '阅读代理',
        type: 'toggle',
        chars: ['服务器', '本地'],
        default: settings.proxy,
      },
      {
        name: '关闭图片',
        type: 'toggle',
        chars: ['off', 'on'],
        default: settings.close_img,
      },
      {
        name: '段评开关',
        type: 'toggle',
        chars: ['off', 'on'],
        default: settings.fqpara,
      },
      {
        name: '同步书架',
        type: 'toggle',
        chars: ['0', '1'],
        default: settings.reading,
      },
      {
        name: '完整简介',
        type: 'toggle',
        chars: ['on', 'off'],
        default: settings.info,
      },
      {
        name: '搜索全部来源',
        type: 'toggle',
        chars: ['0', '1'],
        default: settings.disabled_sources,
      },
      {
        name: '自定义评论颜色(可不填)',
        type: 'text',
        default: settings.plcolor,
      },
      {
        name: '段评气泡样式(0-4)',
        type: 'text',
        default: settings.pstyle,
      },
      {
        name: '手动填写番茄token(可不填)',
        type: 'password',
        default: info['手动填写番茄token(可不填)'] || '',
      },
      {
        name: '设置动作',
        type: 'divider',
      },
      {
        name: '♥登录书源',
        type: 'button',
        action: 'result = await source.login(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '✨应用设置',
        type: 'button',
        action: 'result = await applySettingsAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🔮检测登录',
        type: 'button',
        action: 'result = await checkStatusAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🔚 退出登录',
        type: 'button',
        action: 'result = await logoutAction(ctx);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '⛔️清空设置',
        type: 'button',
        action: 'result = await clearSettingsAction(ctx);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🗑清除设备',
        type: 'button',
        action: 'result = await clearDeviceAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '页面入口',
        type: 'divider',
      },
      {
        name: '🏝用户后台',
        type: 'button',
        action: 'result = await openUserCenterAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🔐注册书源',
        type: 'button',
        action: 'result = await registerAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '☕打赏享福利',
        type: 'button',
        action: 'result = await vipAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '❇️ 更新书源',
        type: 'button',
        action: 'result = await versionAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '📐 使用说明',
        type: 'button',
        action: 'result = await tutorialAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 1,
        },
      },
      {
        name: '兼容动作',
        type: 'divider',
      },
      {
        name: '⚙️书源设置',
        type: 'button',
        action: 'result = await openControlAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '✨同步网页设置',
        type: 'button',
        action: 'result = await syncBrowserSettingsAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '⛔️重置网页设置',
        type: 'button',
        action: 'result = await clearBrowserSettingsAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '📝段评开关',
        type: 'button',
        action: 'result = await toggleParagraphAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '📚同步书架',
        type: 'button',
        action: 'result = await toggleReadingSyncAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '♋️男/女频道',
        type: 'button',
        action: 'result = await toggleSourceTypeAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '💢强制搜索全部',
        type: 'button',
        action: 'result = await toggleDisabledSourcesAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🍅番茄登录',
        type: 'button',
        action: 'result = await fanqieLoginAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '➿️图片显示',
        type: 'button',
        action: 'result = await toggleCloseImageAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🗂当前模式',
        type: 'button',
        action: 'result = await getMediaAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 1,
        },
      },
      {
        name: '📖小说模式',
        type: 'button',
        action: "result = await setMediaAction(ctx, result, '小说');",
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🔊听书模式',
        type: 'button',
        action: "result = await setMediaAction(ctx, result, '听书');",
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🏞漫画模式',
        type: 'button',
        action: "result = await setMediaAction(ctx, result, '漫画');",
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🖲短剧模式',
        type: 'button',
        action: "result = await setMediaAction(ctx, result, '短剧');",
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '🎚切换服务器',
        type: 'button',
        action: 'result = await cycleServerAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '♻️检测当前服务器',
        type: 'button',
        action: 'result = await checkServerAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '⚕️本地/服务器',
        type: 'button',
        action: "result = await applySettingsAction(ctx, { ...result, '阅读代理': (result['阅读代理'] === '本地' ? '服务器' : '本地') });",
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '📌永久发布页📌',
        type: 'button',
        action: 'result = await openHomeAction();',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '📤我来上传',
        type: 'button',
        action: 'result = await openBookStoreAction();',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '💖我来推荐',
        type: 'button',
        action: 'result = await openRecommendAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '📑更少简介',
        type: 'button',
        action: 'result = await toggleInfoAction(ctx, result);',
        style: {
          layout_flexBasisPercent: 0.45,
        },
      },
      {
        name: '番茄网页登录、本地代理、评论与书架同步仍在后续迁移范围内。',
        type: 'note',
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
