import 'dart:convert';

const dumpWebViewLocalStorageScript = '''
(() => {
  const data = {};
  for (let index = 0; index < localStorage.length; index += 1) {
    const key = localStorage.key(index);
    if (key) {
      data[key] = localStorage.getItem(key) || '';
    }
  }
  return JSON.stringify(data);
})()
''';

const dumpWebViewDocumentHtmlScript = '''
(() => {
  if (document.documentElement) {
    return document.documentElement.outerHTML;
  }
  return document.body ? document.body.innerHTML : '';
})()
''';

const webViewResourceSnifferChannelName = 'ReaderRustResourceSniffer';

const installWebViewResourceSnifferScript = r'''
(() => {
  const channelName = 'ReaderRustResourceSniffer';
  const store = window.__readerRustSniffedResources =
      window.__readerRustSniffedResources || [];
  const seen = window.__readerRustSniffedResourceSet =
      window.__readerRustSniffedResourceSet || {};
  const push = (value) => {
    const url = String(value || '').trim();
    if (!url || seen[url]) {
      return;
    }
    seen[url] = true;
    store.push(url);
    try {
      const channel = window[channelName];
      if (channel && typeof channel.postMessage === 'function') {
        channel.postMessage(url);
      }
    } catch (_) {}
  };

  try {
    const entries = performance.getEntriesByType('resource') || [];
    entries.forEach((entry) => push(entry.name));
  } catch (_) {}

  if (window.__readerRustResourceSnifferInstalled) {
    return JSON.stringify(store);
  }
  window.__readerRustResourceSnifferInstalled = true;

  try {
    const rawFetch = window.fetch;
    if (typeof rawFetch === 'function') {
      window.fetch = function(input, init) {
        try {
          push(typeof input === 'string' ? input : input && input.url);
        } catch (_) {}
        return rawFetch.apply(this, arguments).then((response) => {
          try {
            push(response && response.url);
          } catch (_) {}
          return response;
        });
      };
    }
  } catch (_) {}

  try {
    const rawOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
      try {
        this.__readerRustRequestUrl = url;
        push(url);
      } catch (_) {}
      return rawOpen.apply(this, arguments);
    };
    const rawSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function() {
      try {
        this.addEventListener('readystatechange', function() {
          if (this.readyState >= 2) {
            push(this.responseURL || this.__readerRustRequestUrl);
          }
        });
      } catch (_) {}
      return rawSend.apply(this, arguments);
    };
  } catch (_) {}

  try {
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => push(entry.name));
    });
    observer.observe({entryTypes: ['resource']});
  } catch (_) {}

  return JSON.stringify(store);
})()
''';

const dumpWebViewResourceUrlsScript = r'''
(() => {
  const urls = [];
  const seen = {};
  const push = (value) => {
    const url = String(value || '').trim();
    if (!url || seen[url]) {
      return;
    }
    seen[url] = true;
    urls.push(url);
  };
  try {
    (window.__readerRustSniffedResources || []).forEach(push);
  } catch (_) {}
  try {
    const entries = performance.getEntriesByType('resource') || [];
    entries.forEach((entry) => push(entry.name));
  } catch (_) {}
  return JSON.stringify(urls);
})()
''';

String normalizeWebViewCookieResult(Object? value) {
  var text = normalizeWebViewStringResult(value);
  if (text.isEmpty || text == 'null' || text == 'undefined') {
    return '';
  }

  return text
      .split(';')
      .map((part) => part.trim())
      .where(_isCookiePair)
      .join('; ');
}

bool hasUsableCookieHeader(String value) {
  return value.split(';').map((part) => part.trim()).any(_isCookiePair);
}

String normalizeWebViewStringResult(Object? value) {
  var text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null' || text == 'undefined') {
    return '';
  }

  if (_looksLikeQuotedJson(text)) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is String) {
        return decoded.trim();
      }
    } catch (_) {
      text = _stripMatchingQuotes(text);
    }
  }

  return text;
}

Map<String, String> normalizeWebViewStringMapResult(Object? value) {
  Object? decoded = value?.toString().trim() ?? '';
  for (var index = 0; index < 2; index += 1) {
    if (decoded is! String) {
      break;
    }
    final text = decoded.trim();
    if (text.isEmpty || text == 'null' || text == 'undefined') {
      return const <String, String>{};
    }
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      decoded = _stripMatchingQuotes(text);
      break;
    }
  }
  if (decoded is! Map) {
    return const <String, String>{};
  }
  final normalized = <String, String>{};
  for (final entry in decoded.entries) {
    final key = entry.key?.toString().trim() ?? '';
    final itemValue = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && itemValue.isNotEmpty) {
      normalized[key] = itemValue;
    }
  }
  return Map.unmodifiable(normalized);
}

bool _looksLikeQuotedJson(String value) {
  if (value.length < 2) {
    return false;
  }
  return (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"));
}

String _stripMatchingQuotes(String value) {
  if (!_looksLikeQuotedJson(value)) {
    return value;
  }
  return value.substring(1, value.length - 1).trim();
}

bool _isCookiePair(String part) {
  final separator = part.indexOf('=');
  if (separator <= 0) {
    return false;
  }
  final name = part.substring(0, separator).trim();
  return name.isNotEmpty && !name.contains('\n') && !name.contains('\r');
}
