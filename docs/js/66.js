const SOURCE_HOST = 'https://66story.com';

export default {
  meta: {
    name: '66成人小说',
    group: '🌞',
    author: 'converted',
    description: '66成人小说书源，支持搜索、详情、目录、正文',
    checkKeyword: '凡人修仙传',
    domains: ['66story.com'],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      '66story.com': {
        minIntervalMs: 800,
      },
    },
  },

  // ========== 发现页 ==========
  async discoverCategories(ctx) {
    // 从 exploreUrl 的 JSON 数组转换而来
    const categories = [
      { title: '♕ 分类 ♕', url: '', isHeader: true, style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 1 } },
      { title: '校园春色', url: '/index.php/book/category/list/3', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '东方玄幻', url: '/index.php/book/category/list/4', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '乡村爱情', url: '/index.php/book/category/list/5', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '都市激情', url: '/index.php/book/category/list/6', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '家庭乱伦', url: '/index.php/book/category/list/7', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '娱乐明星', url: '/index.php/book/category/list/8', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '♕ 排行 ♕', url: '', isHeader: true, style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 1 } },
      { title: '人气榜', url: '/index.php/custom/book-hot', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '收藏榜', url: '/index.php/custom/book-fav', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '月票榜', url: '/index.php/custom/book-ticket', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
      { title: '打赏榜', url: '/index.php/custom/book-gift', style: { layoutFlexGrow: 1, layoutFlexBasisPercent: 0.25 } },
    ];

    return categories
      .filter(cat => !cat.isHeader) // 过滤掉标题行，只返回可点击的分类
      .map(cat => ({
        title: cat.title,
        url: ctx.utils.absoluteUrl(SOURCE_HOST, cat.url),
        style: cat.style,
        extra: {
          urlPath: cat.url,
        },
      }));
  },

  async discoverBooks(ctx, category, page, pageSize) {
    // 注意：这个网站的发现页可能是单页滚动加载，没有标准分页
    // 这里假设是第一页，如果需要分页，可能需要根据网站实际规则调整
    const fullUrl = ctx.utils.absoluteUrl(SOURCE_HOST, category.extra?.urlPath || category.url);

    const response = await ctx.http.request({
      url: fullUrl,
      method: 'GET',
      timeoutMs: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 9) Mobile Safari/537.36',
      },
    });

    if (!response.ok) {
      throw new Error(`发现页请求失败: ${response.status}`);
    }

    const doc = ctx.html.parse(response.text);

    // ruleExplore: bookList = ".book-list@li || .story-top__rank-list@a"
    let items = doc.querySelectorAll('.book-list li');
    if (items.length === 0) {
      items = doc.querySelectorAll('.story-top__rank-list a');
    }

    return ctx.html.collect(items, (item) => {
      // ruleExplore: name = ".title@text || .title@text"
      let name = '';
      const nameNode = item.querySelector('.title');
      if (nameNode) {
        name = ctx.html.text(nameNode);
      }

      // ruleExplore: bookUrl = "a.0@href" - 取第一个 a 标签的 href
      let detailUrl = '';
      const firstLink = item.querySelector('a');
      if (firstLink) {
        detailUrl = ctx.utils.absoluteUrl(SOURCE_HOST, ctx.html.attr(firstLink, 'href') || '');
      }

      // ruleExplore: author = ".author@text || .author@text"
      let author = '';
      const authorNode = item.querySelector('.author');
      if (authorNode) {
        author = ctx.html.text(authorNode);
      }

      // ruleExplore: coverUrl = "img@data-src || img@data-src"
      let coverUrl = '';
      const img = item.querySelector('img');
      if (img) {
        coverUrl = ctx.html.attr(img, 'data-src') || ctx.html.attr(img, 'src') || '';
        coverUrl = ctx.utils.absoluteUrl(SOURCE_HOST, coverUrl);
      }

      // ruleExplore: intro = ".desc@text || .desc@text"
      let intro = '';
      const introNode = item.querySelector('.desc');
      if (introNode) {
        intro = ctx.html.text(introNode);
      }

      // ruleExplore: wordCount = "div.-1@text || div.-3@text"
      let wordCount = '';
      const divs = item.querySelectorAll('div');
      if (divs.length >= 1) {
        wordCount = ctx.html.text(divs[divs.length - 1]);
      }

      return {
        title: name,
        author: author,
        detailUrl: detailUrl,
        cover: coverUrl,
        intro: intro,
        wordCount: wordCount,
        type: 'novel',
        extra: {},
      };
    });
  },

  // ========== 搜索 ==========
  async search(ctx, keyword) {
    const url = `${SOURCE_HOST}/index.php/book/search?key=${encodeURIComponent(keyword)}`;

    const response = await ctx.http.request({
      url: url,
      method: 'GET',
      timeoutMs: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 9) Mobile Safari/537.36',
      },
    });

    if (!response.ok) {
      throw new Error(`搜索请求失败: ${response.status}`);
    }

    const doc = ctx.html.parse(response.text);

    // ruleSearch: bookList = ".search-result@div"
    const items = doc.querySelectorAll('.search-result div');

    return ctx.html.collect(items, (item) => {
      // ruleSearch: name = "div.0@p.0@text" - 第一个 div 下的第一个 p
      let name = '';
      const firstDiv = item.querySelector('div');
      if (firstDiv) {
        const firstP = firstDiv.querySelector('p');
        if (firstP) {
          name = ctx.html.text(firstP);
        }
      }

      // ruleSearch: bookUrl = "a.0@href"
      let detailUrl = '';
      const link = item.querySelector('a');
      if (link) {
        detailUrl = ctx.utils.absoluteUrl(SOURCE_HOST, ctx.html.attr(link, 'href') || '');
      }

      // ruleSearch: coverUrl = "a.0@img@src"
      let coverUrl = '';
      if (link) {
        const img = link.querySelector('img');
        if (img) {
          coverUrl = ctx.utils.absoluteUrl(SOURCE_HOST, ctx.html.attr(img, 'src') || '');
        }
      }

      // ruleSearch: author = "div.0@p.1@text"
      let author = '';
      if (firstDiv) {
        const ps = firstDiv.querySelectorAll('p');
        if (ps.length >= 2) {
          author = ctx.html.text(ps[1]);
        }
      }

      // ruleSearch: intro = "div.0@p.-1@text" - 最后一个 p
      let intro = '';
      if (firstDiv) {
        const ps = firstDiv.querySelectorAll('p');
        if (ps.length >= 1) {
          intro = ctx.html.text(ps[ps.length - 1]);
        }
      }

      // ruleSearch: wordCount = "div.0@p.2@text"
      let wordCount = '';
      if (firstDiv) {
        const ps = firstDiv.querySelectorAll('p');
        if (ps.length >= 3) {
          wordCount = ctx.html.text(ps[2]).replace(/.*共/g, '');
        }
      }

      return {
        title: name,
        author: author,
        detailUrl: detailUrl,
        cover: coverUrl,
        intro: intro,
        wordCount: wordCount,
        type: 'novel',
        extra: {},
      };
    });
  },

  // ========== 详情 ==========
  async detail(ctx, book) {
    const response = await ctx.http.request({
      url: book.detailUrl,
      method: 'GET',
      timeoutMs: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 9) Mobile Safari/537.36',
      },
    });

    if (!response.ok) {
      throw new Error(`详情页请求失败: ${response.status}`);
    }

    const doc = ctx.html.parse(response.text);

    // ruleBookInfo: name = ".title.0@text"
    let name = '';
    const titleNode = doc.querySelector('.title');
    if (titleNode) {
      name = ctx.html.text(titleNode);
    }

    // ruleBookInfo: author = ".author@text"
    let author = '';
    const authorNode = doc.querySelector('.author');
    if (authorNode) {
      author = ctx.html.text(authorNode);
    }

    // ruleBookInfo: coverUrl = ".cover-wrapper@img@data-src"
    let coverUrl = '';
    const coverWrapper = doc.querySelector('.cover-wrapper');
    if (coverWrapper) {
      const img = coverWrapper.querySelector('img');
      if (img) {
        coverUrl = ctx.html.attr(img, 'data-src') || ctx.html.attr(img, 'src') || '';
        coverUrl = ctx.utils.absoluteUrl(SOURCE_HOST, coverUrl);
      }
    }

    // ruleBookInfo: intro = ".story-detail__info-desc@text"
    let intro = '';
    const introNode = doc.querySelector('.story-detail__info-desc');
    if (introNode) {
      intro = ctx.html.text(introNode).replace(/\- 展开 \-/g, '').trim();
    }

    // ruleBookInfo: kind = ".multi@text"
    let kind = '';
    const kindNode = doc.querySelector('.multi');
    if (kindNode) {
      kind = ctx.html.text(kindNode);
    }

    // ruleBookInfo: tocUrl = "text.目录@href"
    let tocUrl = '';
    // 查找包含"目录"文字的链接
    const links = doc.querySelectorAll('a');
    for (const link of links) {
      const linkText = ctx.html.text(link);
      if (linkText.includes('目录')) {
        tocUrl = ctx.utils.absoluteUrl(book.detailUrl, ctx.html.attr(link, 'href') || '');
        break;
      }
    }

    return {
      ...book,
      title: name || book.title,
      author: author || book.author,
      cover: coverUrl || book.cover,
      intro: intro || book.intro,
      category: kind || book.category,
      tocUrl: tocUrl,
    };
  },

  // ========== 目录 ==========
  async chapters(ctx, book) {
    // 优先使用 detail 中获取的 tocUrl，否则使用 detailUrl
    const url = book.tocUrl || book.detailUrl;

    const response = await ctx.http.request({
      url: url,
      method: 'GET',
      timeoutMs: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 9) Mobile Safari/537.36',
      },
    });

    if (!response.ok) {
      throw new Error(`目录页请求失败: ${response.status}`);
    }

    const doc = ctx.html.parse(response.text);

    // ruleToc: chapterList = ".j-catalog-list@li"
    const chapterNodes = doc.querySelectorAll('.j-catalog-list li');

    if (chapterNodes.length === 0) {
      // 书本身在网站上并无目录，返回空数组
      ctx.log(`目录为空: ${book.title}`);
      return [];
    }

    return ctx.html.collect(chapterNodes, (node) => {
      // ruleToc: chapterName = ".title-text@text"
      let title = '';
      const titleNode = node.querySelector('.title-text');
      if (titleNode) {
        title = ctx.html.text(titleNode);
      }

      // ruleToc: chapterUrl = "a@href"
      let chapterUrl = '';
      const link = node.querySelector('a');
      if (link) {
        chapterUrl = ctx.utils.absoluteUrl(book.detailUrl, ctx.html.attr(link, 'href') || '');
      }

      // ruleToc: updateTime = "div.-1@text"
      let updateTime = '';
      const divs = node.querySelectorAll('div');
      if (divs.length >= 1) {
        updateTime = ctx.html.text(divs[divs.length - 1]);
      }

      // 处理 chapterName 中的卷标记
      // 原始规则中的复杂处理：提取第X卷，或者保留原标题
      let processedTitle = title;
      const volumeMatch = title.match(/第.*卷/);
      if (volumeMatch) {
        // 如果是卷标题，标记为卷
        return {
          title: title,
          url: chapterUrl,
          isVolume: true,
          updateTime: updateTime,
          extra: {},
        };
      }

      return {
        title: title,
        url: chapterUrl,
        updateTime: updateTime,
        extra: {},
      };
    });
  },

  // ========== 正文 ==========
  async content(ctx, book, chapter) {
    const response = await ctx.http.request({
      url: chapter.url,
      method: 'GET',
      timeoutMs: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 9) Mobile Safari/537.36',
      },
    });

    if (!response.ok) {
      throw new Error(`正文页请求失败: ${response.status}`);
    }

    const doc = ctx.html.parse(response.text);

    // ruleContent: content = ".chapter-preview@html"
    let content = '';
    const contentNode = doc.querySelector('.chapter-preview');
    if (contentNode) {
      // 获取 HTML 内容，保留格式
      content = contentNode.innerHTML || ctx.html.text(contentNode);
    }

    // 如果没找到，尝试其他常见选择器
    if (!content) {
      const altNode = doc.querySelector('.content, #nr, .read-content, .chapter-content');
      if (altNode) {
        content = altNode.innerHTML || ctx.html.text(altNode);
      }
    }

    return {
      title: chapter.title,
      content: content || '正文内容获取失败',
    };
  },
};