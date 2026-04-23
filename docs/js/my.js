const ajax = async (url, method = 'GET', params = null, headers = {}) => {
    const options = {
        url: url,
        method: method,
        headers: headers,
        timeoutMs: 10000,
    };
    
    if (method === 'GET' && params) {
        options.query = params;
    } else if (method === 'POST' && params) {
        options.body = params;
        options.bodyType = 'json';
    }
    
    return await ctx.http.request(options);
};

export default {
    meta: {
        name: "小茄阅读",
        group: "正版",
        author: "明月照大江",
        description: "免费书源",
        checkKeyword: "我不是戏神",
        domains: ["novel.snssdk.com", "fanqienovel.com"],
        homepage: "https://debug.local",
        capabilities: ["search", "detail", "chapters", "content"],
        rateLimits: {
            "novel.snssdk.com": { minIntervalMs: 500 },
            "fanqienovel.com": { minIntervalMs: 500 },
        },
    },

    async search(ctx, keyword) {
        const resp = await ajax(
            `https://novel.snssdk.com/api/novel/channel/homepage/search/search/v2/?device_platform=android&parent_enterfrom=novel_channel_search.tab.&offset=0&aid=1967&q=${encodeURIComponent(keyword)}`
        );
        
        // 防御性检查
        const retData = resp.json?.data?.ret_data;
        if (!retData || !Array.isArray(retData)) {
            ctx.log(`search 返回数据异常: ${typeof retData}`);
            return [];
        }
        
        return retData.map(x => ({
            title: x.title || '未知书名',
            author: x.author || '未知作者',
            type: 'novel',
            cover: x.thumb_url,
            intro: x.abstract,
            detailUrl: x.book_id,  // 存 ID，后续 chapters 会用
            extra: {
                score: x.score,
                tags: x.category,
            }
        }));
    },

    async detail(ctx, book) {
        return book;
    },

    async chapters(ctx, book) {
        const resp = await ajax(`https://fanqienovel.com/api/reader/directory/detail?bookId=${book.detailUrl}`);
        
        const chapterData = resp.json?.data?.chapterListWithVolume;
        if (!chapterData || !Array.isArray(chapterData)) {
            ctx.log(`chapters 返回数据异常`);
            return [];
        }
        
        const chapterList = [];
        chapterData.forEach(volume => {
            if (Array.isArray(volume)) {
                volume.forEach(ch => {
                    chapterList.push({
                        title: ch.title || '未知章节',
                        url: ch.itemId,
                        updateTime: ch.firstPassTime,
                    });
                });
            }
        });
        
        return chapterList;
    },

    async content(ctx, book, chapter) {
        // TODO: 实现真正的正文获取
        return {
            title: chapter.title,
            content: `${book.title}\n\n${chapter.title}\n\n需要实现正文接口...`,
        };
    },
};