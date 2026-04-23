const ajax = async (url, options = {}) => {
  const {
    method = "GET",
    query,
    body,
    headers,
    responseType = "json",
  } = options;

  return await ctx.http.request({
    url,
    method,
    query,
    body,
    headers,
    responseType,
  });
};

function hexToBytes(hex) {
  const raw = (hex || "").trim();
  if (!raw) return new Uint8Array();
  if (raw.length % 2 !== 0) {
    throw new Error("hex 字符串长度必须为偶数");
  }

  const out = new Uint8Array(raw.length / 2);
  for (let i = 0; i < raw.length; i += 2) {
    out[i / 2] = parseInt(raw.slice(i, i + 2), 16);
  }
  return out;
}

function xorBytes(bytes, keyBytes) {
  const out = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
  }
  return out;
}

function generateXorKey(secretKey, ts, search) {
  const state = new Uint8Array(32);
  const km = secretKey + ts + search;

  for (let i = 0; i < 32; i++) {
    state[i] = km.charCodeAt(i % km.length);
  }

  for (let round = 0; round < 3; round++) {
    for (let i = 0; i < 32; i++) {
      state[i] ^= state[(i + 1) % 32];
      state[i] = ((state[i] << 3) | (state[i] >> 5)) & 0xff;
    }
  }

  return state;
}

function uint8ArrayToBase64(bytes) {
  const base64abc =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  let res = "";
  let i;
  const l = bytes.length;

  for (i = 2; i < l; i += 3) {
    res += base64abc[bytes[i - 2] >> 2];
    res += base64abc[((bytes[i - 2] & 3) << 4) | (bytes[i - 1] >> 4)];
    res += base64abc[((bytes[i - 1] & 15) << 2) | (bytes[i] >> 6)];
    res += base64abc[bytes[i] & 63];
  }

  if (i === l + 1) {
    res +=
      base64abc[bytes[i - 2] >> 2] +
      base64abc[(bytes[i - 2] & 3) << 4] +
      "==";
  }

  if (i === l) {
    res +=
      base64abc[bytes[i - 2] >> 2] +
      base64abc[((bytes[i - 2] & 3) << 4) | (bytes[i - 1] >> 4)] +
      base64abc[(bytes[i - 1] & 15) << 2] +
      "=";
  }

  return res;
}

function buildHeaders(url) {
  const timestamp = Math.floor(Date.now() / 1e3);
  const uid = "test1001";
  const secret = "skybbk-9527260127";
  const match = url.match(/^[^/]+:\/\/[^/]+([^#]*)/);
  const search = match && match[1] ? match[1] : "/";
  const xorKey = generateXorKey(secret, timestamp, search);

  const hmacHex = ctx.crypto.hmacSha256(uid + timestamp, secret);
  const hmacRaw = hexToBytes(hmacHex);
  const xorRaw = xorBytes(hmacRaw, xorKey);
  const finalB64 = uint8ArrayToBase64(xorRaw);

  ctx.log(`hmacHex=${hmacHex}`);
  ctx.log(`hmacRaw=${JSON.stringify(Array.from(hmacRaw))}`);
  ctx.log(`xorKey=${JSON.stringify(Array.from(xorKey))}`);
  ctx.log(`requestPath=${search}`);

  return {
    UUID: uid,
    Authorization: finalB64,
    timestamp: String(timestamp),
    UFRAY:
      "0b15e5095fc2fc17aa7b87287509d21aded6e728c6df82ccc29d3d33b1a77d6b",
    dnsIp: "104.21.46.21",
  };
}

function normalizeTextContent(value) {
  if (typeof value === "string") {
    return value.trim();
  }

  if (Array.isArray(value)) {
    return value
      .map((item) => normalizeTextContent(item))
      .filter(Boolean)
      .join("\n\n")
      .trim();
  }

  if (value && typeof value === "object") {
    if (typeof value.content === "string") return value.content.trim();
    if (typeof value.text === "string") return value.text.trim();
    if (typeof value.body === "string") return value.body.trim();
    if (typeof value.txt === "string") return value.txt.trim();
  }

  return "";
}

function extractContent(payload) {
  const candidates = [
    payload,
    payload && payload.data,
    payload && payload.result,
    payload && payload.data && payload.data.content,
    payload && payload.data && payload.data.chapter_content,
    payload && payload.data && payload.data.body,
    payload && payload.content,
    payload && payload.chapter_content,
    payload && payload.body,
    payload && payload.txt,
  ];

  for (const candidate of candidates) {
    const text = normalizeTextContent(candidate);
    if (text) return text;
  }

  return "";
}

export default {
  meta: {
    name: "小茄阅读 3",
    group: "正版",
    author: "明月照大江",
    description: "免费书源",
    checkKeyword: "我不是戏神",
    domains: ["115.190.42.251", "novel.snssdk.com", "fanqienovel.com"],
    homepage: "https://debug.local",
    capabilities: ["search", "detail", "chapters", "content"],
    rateLimits: {
      "115.190.42.251": {
        minIntervalMs: 500,
      },
    },
  },

  async search(ctx, keyword) {
    const resp = await ajax(
      `https://novel.snssdk.com/api/novel/channel/homepage/search/search/v2/?device_platform=android&parent_enterfrom=novel_channel_search.tab.&offset=0&aid=1967&q=${encodeURIComponent(
        keyword
      )}`
    );

    const rawList =
      (resp.json &&
        resp.json.data &&
        Array.isArray(resp.json.data.ret_data) &&
        resp.json.data.ret_data) ||
      [];

    return rawList.reduce((arr, item) => {
      arr.push({
        title: item.title || "",
        author: item.author || "",
        score: item.score,
        tags: item.category ? [item.category] : [],
        intro: item.abstract || "",
        cover: item.thumb_url || "",
        detailUrl: String(item.book_id || ""),
      });
      return arr;
    }, []);
  },

  async detail(ctx, book) {
    return book;
  },

  async chapters(ctx, book) {
    const resp = await ajax(
      `https://fanqienovel.com/api/reader/directory/detail?bookId=${encodeURIComponent(
        book.detailUrl
      )}`
    );

    const volumes =
      (resp.json &&
        resp.json.data &&
        Array.isArray(resp.json.data.chapterListWithVolume) &&
        resp.json.data.chapterListWithVolume) ||
      [];

    const chapterList = [];

    volumes.forEach((group) => {
      if (!Array.isArray(group)) return;
      group.forEach((item) => {
        chapterList.push({
          title: item.title || "",
          url: String(item.itemId || ""),
          updateTime: item.firstPassTime,
        });
      });
    });

    return chapterList;
  },

  async content(ctx, book, chapter) {
    const url = `http://115.190.42.251/fq/content?item_id=${encodeURIComponent(
      chapter.url
    )}`;
    const headers = buildHeaders(url);

    ctx.log(`contentUrl=${url}`);
    ctx.log(`headerKeys=${Object.keys(headers).join(",")}`);
    ctx.log(`authorizationLength=${headers.Authorization.length}`);

    const resp = await ajax(url, {
      method: "GET",
      headers,
      responseType: "json",
    });

    ctx.log(`status=${resp.status}`);
    ctx.log(`responseJson=${JSON.stringify(resp.json || {})}`);

    const text = extractContent(resp.json);

    return {
      title: chapter.title,
      content:
        text ||
        `${book.title}\n\n${chapter.title}\n\n${JSON.stringify(
          resp.json || {},
          null,
          2
        )}`,
    };
  },
};
