const SOURCE_HOST = 'http://www.gdbzkz.com';
const DEFAULT_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

export default {
  meta: {
    name: '🌐 鬼吹灯网',
    group: '默认分组',
    author: 'converted',
    description: '鬼吹灯网书源，支持搜索、详情、目录、正文',
    checkKeyword: '凡人修仙传',
    domains: ['www.gdbzkz.com'],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
    rateLimits: {
      'www.gdbzkz.com': { minIntervalMs: 800 },
    },
  },

  async discoverCategories(ctx) {
    const categories = [
      { title: '玄幻小说', url: '/fenlei/1/{{page}}.html' },
      { title: '仙侠小说', url: '/fenlei/2/{{page}}.html' },
      { title: '都市小说', url: '/fenlei/3/{{page}}.html' },
      { title: '军史小说', url: '/fenlei/4/{{page}}.html' },
      { title: '网游小说', url: '/fenlei/5/{{page}}.html' },
      { title: '科幻小说', url: '/fenlei/6/{{page}}.html' },
      { title: '恐怖小说', url: '/fenlei/7/{{page}}.html' },
    ];
    return categories.map(cat => ({
      title: cat.title,
      url: ctx.utils.absoluteUrl(SOURCE_HOST, cat.url),
      extra: { urlPattern: cat.url },
    }));
  },

  async discoverBooks(ctx, category, page, pageSize) {
    let url = category.extra?.urlPattern || category.url;
    url = url.replace('{{page}}', page.toString());
    const fullUrl = ctx.utils.absoluteUrl(SOURCE_HOST, url);
    const response = await ctx.http.request({
      url: fullUrl,
      method: 'GET',
      timeoutMs: 10000,
      headers: { 'User-Agent': DEFAULT_USER_AGENT },
    });
    if (!response.ok) throw new Error(`发现页请求失败: ${response.status}`);
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.l li');
    return ctx.html.collect(items, (item) => {
      const nameNode = item.querySelector('.s2 a');
      const name = ctx.html.text(nameNode).replace(/（.*|\(.*|免费阅读|全文.*阅读|最新章节|笔趣阁|小说/g, '').trim();
      const detailUrl = ctx.utils.absoluteUrl(SOURCE_HOST, ctx.html.attr(nameNode, 'href') || '');
      const author = ctx.html.text(item.querySelector('.s4'));
      const latestChapter = ctx.html.text(item.querySelector('.s3 a'));
      const categoryName = ctx.html.text(item.querySelector('.s5'));
      return { title: name, author: author, detailUrl: detailUrl, latestChapter: latestChapter, category: categoryName, extra: {} };
    });
  },

  async search(ctx, keyword) {
    const url = `${SOURCE_HOST}/s.php?ie=utf-8&q=${encodeURIComponent(keyword)}`;
    const response = await ctx.http.request({
      url: url,
      method: 'GET',
      timeoutMs: 10000,
      headers: { 'User-Agent': DEFAULT_USER_AGENT },
    });
    if (!response.ok) throw new Error(`搜索请求失败: ${response.status}`);
    const doc = ctx.html.parse(response.text);
    const items = doc.querySelectorAll('.bookbox');
    return ctx.html.collect(items, (item) => {
      const nameNode = item.querySelector('.bookname a');
      const name = ctx.html.text(nameNode).replace(/（.*|\(.*|免费阅读|全文.*阅读|最新章节|笔趣阁|小说/g, '').trim();
      const detailUrl = ctx.utils.absoluteUrl(SOURCE_HOST, ctx.html.attr(nameNode, 'href') || '');
      let author = ctx.html.text(item.querySelector('.author')).replace(/作者：/g, '').trim();
      const coverUrl = ctx.utils.absoluteUrl(SOURCE_HOST, ctx.html.attr(item.querySelector('.bookimg img'), 'src') || '');
      const intro = ctx.html.text(item.querySelector('.bookinfo p'));
      let kind = ctx.html.text(item.querySelector('.cat')).replace(/分类：/g, '').trim();
      const lastChapterNode = item.querySelector('.update a');
      const lastChapter = lastChapterNode ? ctx.html.text(lastChapterNode).replace(/百度搜索.*/g, '').trim() : '';
      return { title: name, author: author, detailUrl: detailUrl, cover: coverUrl, intro: intro, category: kind, latestChapter: lastChapter, type: 'novel', extra: {} };
    });
  },

  async detail(ctx, book) {
    const response = await ctx.http.request({
      url: book.detailUrl,
      method: 'GET',
      timeoutMs: 10000,
      headers: { 'User-Agent': DEFAULT_USER_AGENT },
    });
    if (!response.ok) throw new Error(`详情页请求失败: ${response.status}`);
    const doc = ctx.html.parse(response.text);
    let name = ctx.html.text(doc.querySelector('.info h2')).replace(/（.*|\(.*|免费阅读|全文.*阅读|最新章节|笔趣阁|小说/g, '').trim();
    const coverUrl = ctx.utils.absoluteUrl(SOURCE_HOST, ctx.html.attr(doc.querySelector('.cover img'), 'src') || '');
    const spans = doc.querySelectorAll('.small span');
    let author = spans.length > 0 ? ctx.html.text(spans[0]).replace(/作 者：/g, '').trim() : '';
    let intro = '';
    const introNode = doc.querySelector('.intro');
    if (introNode) intro = ctx.html.text(introNode).replace(/作者.*|无弹窗.*/g, '').trim();
    let kind = '', status = '', updateTime = '';
    if (spans.length >= 3) {
      kind = ctx.html.text(spans[1]).replace(/分类：/g, '').trim();
      status = ctx.html.text(spans[2]).replace(/状态：/g, '').trim();
      if (spans.length >= 4) updateTime = ctx.html.text(spans[3]).replace(/更新时间：/g, '').trim();
    }
    let wordCount = spans.length >= 4 ? ctx.html.text(spans[3]).replace(/字数：/g, '').trim() : '';
    let lastChapter = '';
    if (spans.length >= 6) {
      const lastChapterNode = spans[5].querySelector('a');
      if (lastChapterNode) lastChapter = ctx.html.text(lastChapterNode).replace(/百度搜索.*/g, '').trim();
    }
    return {
      ...book,
      title: name || book.title,
      cover: coverUrl || book.cover,
      author: author || book.author,
      intro: intro || book.intro,
      category: kind || book.category,
      status: status,
      wordCount: wordCount,
      updateTime: updateTime,
      latestChapter: lastChapter || book.latestChapter,
    };
  },

  async chapters(ctx, book) {
    const url = book.detailUrl;
    ctx.log(`获取目录: ${url}`);
    const response = await ctx.http.request({
      url: url,
      method: 'GET',
      timeoutMs: 10000,
      headers: { 'User-Agent': DEFAULT_USER_AGENT },
    });
    if (!response.ok) throw new Error(`目录页请求失败: ${response.status}`);
    const doc = ctx.html.parse(response.text);
    let allDDs = doc.querySelectorAll('.listmain dd');
    if (allDDs.length === 0) {
      allDDs = doc.querySelectorAll('#list dd, .chapter-list dd, .catalog dd');
    }
    ctx.log(`找到 ${allDDs.length} 个 dd 元素`);
    const excludeCount = 12;
    let chapterNodes = allDDs.length > excludeCount ? Array.from(allDDs).slice(excludeCount) : Array.from(allDDs);
    if (chapterNodes.length === 0) return [];
    const chapters = [];
    for (const node of chapterNodes) {
      const link = node.querySelector('a');
      if (!link) continue;
      let title = ctx.html.text(link).trim();
      if (!title) continue;
      let chapterUrl = ctx.html.attr(link, 'href') || '';
      chapterUrl = ctx.utils.absoluteUrl(book.detailUrl, chapterUrl);
      chapters.push({ title: title, url: chapterUrl, extra: {} });
    }
    ctx.log(`成功解析 ${chapters.length} 个章节`);
    return chapters;
  },

  async content(ctx, book, chapter) {
    const response = await ctx.http.request({
      url: chapter.url,
      method: 'GET',
      timeoutMs: 10000,
      headers: { 'User-Agent': DEFAULT_USER_AGENT },
    });
    if (!response.ok) throw new Error(`正文页请求失败: ${response.status}`);
    const doc = ctx.html.parse(response.text);
    let content = '';
    // 使用 querySelector 替代 getElementById，彻底避免方法名错误
    const contentNode = doc.querySelector('#content');
    if (contentNode) {
      // 先获取 innerHTML，保留 <br> 标签，然后替换为换行符
      let html = contentNode.innerHtml || '';
      // 将 <br> 标签替换为换行符（支持各种写法：<br>, <br/>, <br />）
      // 连续多个 <br> 替换为段落分隔
      html = html.replace(/(<br\s*\/?>\s*){2,}/gi, '\n\n');
      html = html.replace(/<br\s*\/?>/gi, '\n');
      // 移除其他 HTML 标签
      html = html.replace(/<[^>]+>/g, '');
      // 处理常见 HTML 实体
      html = html
        .replace(/&nbsp;/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&#\d+;/g, (match) => String.fromCharCode(parseInt(match.slice(2, -1))));
      // 清理多余空白
      content = html.trim();
      content = content
        .replace(/http.*html/g, '')
        .replace(/天才一秒记住.*com/g, '')
        .replace(/请记住本书首发域.*com/g, '')
        .trim();
    }
    if (!content) {
      const altNode = doc.querySelector('.content, #nr, .read-content');
      if (altNode) {
        let html = altNode.innerHtml || '';
        html = html.replace(/(<br\s*\/?>\s*){2,}/gi, '\n\n');
        html = html.replace(/<br\s*\/?>/gi, '\n');
        html = html.replace(/<[^>]+>/g, '');
        html = html
          .replace(/&nbsp;/g, ' ')
          .replace(/&amp;/g, '&')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&quot;/g, '"')
          .replace(/&#39;/g, "'")
          .replace(/&#\d+;/g, (match) => String.fromCharCode(parseInt(match.slice(2, -1))));
        content = html.trim();
      }
    }
    return { title: chapter.title, content: content || '正文内容获取失败' };
  },
};