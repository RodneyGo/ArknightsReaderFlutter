// Story-content languages. Ported from BetterPhoneReader/src/stores/settings.ts
// (just the server constants — the full settings store lands with the state
// layer). "ru" has no game server: it loads EN and overlays bundled Russian
// translations where available.

const servers = <String>['en_US', 'zh_CN', 'ja_JP', 'ko_KR', 'zh_TW', 'ru'];

/// Real game server backing a content language (ru is overlaid onto en_US).
String baseServer(String s) => s == 'ru' ? 'en_US' : s;
