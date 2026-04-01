const SOURCE_HOST = 'https://www.example.com';

// 统一对象工厂：
// 1) 保证每一步返回结构稳定
// 2) 只覆盖当前步骤拿到的字段
// 3) 站点私有参数统一放到 extra，调试信息放 debug
function createBook(partial = {}) {
  return {
    // 可选：站点有稳定主键时填写；没有可留空，宿主可兜底生成。
    id: '',
    // MVP 建议至少保证：title、detailUrl
    title: '',
    // 作品类型：novel(小说) / comic(漫画) / audio(听书)
    type: '',
    // 目录入口 URL：建议在 detail 阶段补齐，chapters 阶段优先使用
    tocUrl: '',
    author: '',
    cover: '',
    intro: '',
    status: '',
    category: '',
    // 以下字段当前运行时仍支持，适合搜索结果增强展示。
    score: '',
    wordCount: '',
    updateTime: '',
    tags: [],
    latestChapter: '',
    detailUrl: '',
    sourceId: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

function createChapter(partial = {}) {
  return {
    // 可选：站点有稳定章节主键时填写；没有可留空。
    id: '',
    // MVP 建议至少保证：title、url
    title: '',
    url: '',
    // 是否 VIP 章节（身份限制）
    isVip: false,
    // 是否已购买（支付状态）
    isPay: false,
    index: 0,
    updateTime: '',
    sourceId: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

function createContent(partial = {}) {
  return {
    // MVP 建议至少保证：title、content
    // 文本正文放 content；图片型正文可额外返回 images。
    title: '',
    content: '',
    nextUrl: null,
    images: [],
    sourceId: '',
    extra: {},
    debug: {},
    ...partial,
  };
}

// 官方推荐写法：helper 显式接收 ctx，便于复用与测试。
function requestJson(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    ...options,
  });
}

// 简化版写法：直接使用全局 ctx。
// 建议只在非常简单的脚本里使用；复杂源优先使用 requestJson(ctx, ...)。
function requestJsonLite(url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    ...options,
  });
}

export default {
  meta: {
    // 建议给用户可读的名称与描述，方便在源列表中识别。
    name: '示例书源',
    group: '默认分组',
    author: 'your_name',
    description: '一个演示 API / HTML / 浏览器混合流程的模板书源。',
    domains: ['www.example.com'],
    homepage: SOURCE_HOST,
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
    rateLimits: {
      'www.example.com': {
        minIntervalMs: 800,
      },
      'api.example.com': {
        minIntervalMs: 300,
      },
    },
  },

  async init(ctx, task) {
    // init 是可选预热步骤：
    // - 仅在某些 step 之前做准备动作（例如拿 token）
    // - 不建议做重请求，避免拖慢每次执行
    if (task.step !== 'search') {
      return;
    }

    // 例子：预取 token 并放入 session，后续方法可复用。
    if (!ctx.session.get('bootstrapToken')) {
      const bootstrap = await ctx.http.request({
        url: 'https://api.example.com/bootstrap',
        method: 'GET',
        timeoutMs: 5000,
      });

      if (bootstrap.json?.token) {
        ctx.session.set('bootstrapToken', bootstrap.json.token);
      }
    }

    // 例子：如果源标记为需要登录，先走挑战流程。
    if (ctx.session.get('needLogin') === true) {
      await ctx.browser.challenge({
        url: `${SOURCE_HOST}/login`,
        reason: 'login_required',
        timeoutMs: 120000,
      });
    }
  },

  async search(ctx, keyword) {
    // Step 1: 请求搜索页/接口
    const response = await requestJson(ctx, `${SOURCE_HOST}/search`, {
      query: {
        q: keyword,
      },
      responseType: 'text',
      timeoutMs: 6000,
    });

    // Step 2: 如遇挑战页，先走浏览器验证
    if (ctx.http.isChallenge(response)) {
      await ctx.browser.challenge({
        url: response.url,
        reason: 'captcha',
        timeoutMs: 120000,
      });
    }

    // Step 3: 验证后重试一次请求
    const retryResponse = ctx.http.isChallenge(response)
      ? await ctx.http.request({
          url: `${SOURCE_HOST}/search`,
          method: 'GET',
          query: {
            q: keyword,
          },
          timeoutMs: 6000,
        })
      : response;

    // Step 4: 解析列表，映射为 Book[]
    // 注意：把你站点的选择器（.book-item/.book-title/...）改成真实选择器。
    const doc = ctx.html.parse(retryResponse.text);
    const items = doc.querySelectorAll('.book-item');

    return ctx.html.collect(items, (item, index) => {
      const titleNode = item.querySelector('.book-title');
      const authorNode = item.querySelector('.book-author');
      const linkNode = item.querySelector('a');

      return createBook({
        title: ctx.html.text(titleNode),
        type: 'novel',
        author: ctx.html.text(authorNode),
        detailUrl: ctx.utils.absoluteUrl(
          SOURCE_HOST,
          linkNode?.getAttribute('href') || '',
        ),
        wordCount: '',
        updateTime: '',
        extra: {
          // 仅放后续步骤会用到的信息
          fromSearch: true,
          rawSearchIndex: index,
        },
      });
    });
  },

  async detail(ctx, book) {
    // 输入是 search 阶段返回的 book，输出是补齐后的单本 Book
    const response = await ctx.http.request({
      url: ctx.utils.absoluteUrl(SOURCE_HOST, book.detailUrl),
      method: 'GET',
      timeoutMs: 6000,
    });

    // 详情页同样可能命中挑战页
    if (ctx.http.isChallenge(response)) {
      await ctx.browser.challenge({
        url: response.url,
        reason: 'detail_captcha',
        timeoutMs: 120000,
      });
    }

    // 挑战后重试
    const retryResponse = ctx.http.isChallenge(response)
      ? await ctx.http.request({
          url: ctx.utils.absoluteUrl(SOURCE_HOST, book.detailUrl),
          method: 'GET',
          timeoutMs: 6000,
        })
      : response;

    const doc = ctx.html.parse(retryResponse.text);

    return createBook({
      ...book,
      intro: ctx.html.text(doc.querySelector('.book-intro')),
      cover: ctx.utils.absoluteUrl(
        SOURCE_HOST,
        doc.querySelector('.book-cover img')?.getAttribute('src') || '',
      ),
      status: ctx.html.text(doc.querySelector('.book-status')),
      category: ctx.html.text(doc.querySelector('.book-category')),
      wordCount: ctx.html.text(doc.querySelector('.book-words')),
      updateTime: ctx.html.text(doc.querySelector('.book-update-time')),
      latestChapter: ctx.html.text(doc.querySelector('.book-latest')),
      // search/detail 统一使用同一个 Book 模型，目录入口在 detail 阶段补齐到 tocUrl。
      tocUrl: ctx.utils.absoluteUrl(
        SOURCE_HOST,
        doc.querySelector('.book-catalog-link')?.getAttribute('href') || '',
      ),
      extra: {
        ...book.extra,
      },
    });
  },

  async chapters(ctx, book) {
    // 目录优先使用 detail 阶段补齐的 tocUrl，回退到 detailUrl
    const response = await ctx.http.request({
      url: book.tocUrl || ctx.utils.absoluteUrl(SOURCE_HOST, book.detailUrl),
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);
    const chapterNodes = doc.querySelectorAll('.chapter-item a');

    // 把目录映射为 Chapter[]
    return ctx.html.collect(chapterNodes, (node) =>
      createChapter({
        title: ctx.html.text(node),
        url: ctx.utils.absoluteUrl(
          SOURCE_HOST,
          node.getAttribute('href') || '',
        ),
        updateTime: ctx.html.text(node.parentElement?.querySelector('.chapter-time')),
      }),
    );
  },

  async content(ctx, book, chapter) {
    // 输入是当前 book + chapter，输出正文 Content
    const response = await ctx.http.request({
      url: chapter.url,
      method: 'GET',
      timeoutMs: 6000,
    });

    // 正文页可能更容易触发反爬，保留挑战处理
    if (ctx.http.isChallenge(response)) {
      await ctx.browser.challenge({
        url: response.url,
        reason: 'content_captcha',
        timeoutMs: 120000,
      });
    }

    // 挑战后重试
    const retryResponse = ctx.http.isChallenge(response)
      ? await ctx.http.request({
          url: chapter.url,
          method: 'GET',
          timeoutMs: 6000,
        })
      : response;

    // 仅在需要时升级浏览器执行（如纯前端渲染正文）
    if (book.extra.forceBrowserContent === true) {
      const browserResult = await ctx.browser.eval({
        url: chapter.url,
        script: `
          const title = document.querySelector('.chapter-title')?.innerText || '';
          const content = document.querySelector('.chapter-content')?.innerText || '';
          return { title, content };
        `,
        timeoutMs: 10000,
      });

      return createContent({
        title: browserResult.title || chapter.title,
        content: browserResult.content || '',
      });
    }

    // 常规 HTML 正文提取
    const doc = ctx.html.parse(retryResponse.text);
    return createContent({
      title: ctx.html.text(doc.querySelector('.chapter-title')) || chapter.title,
      content: ctx.html.text(doc.querySelector('.chapter-content')),
    });
  },
};
