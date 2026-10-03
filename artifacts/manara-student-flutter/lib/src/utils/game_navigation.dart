/// قواعدُ التنقّل داخل لعبة: تبقى اللعبةُ في التطبيق، ولا إعلانَ ولا رابطَ خارجي.
///
/// ── لماذا ──
/// ألعابُ HTML5 فيها «ألعابٌ أخرى» و«قيّمنا» وإعلاناتٌ تفتح نوافذَ أو تنقل الصفحةَ
/// كلَّها إلى موقعٍ آخر — وعلى أندرويد تنتقل `window.open` في الـWebView نفسه حين
/// تُمنع النوافذ. فطفلٌ يضغط شعاراً يخرج من اللعبة إلى متجرٍ أو موقع إعلانات.
/// فالتنقّلُ يُسمح به إلى مضيف اللعبة وحده، وكلُّ ما سواه يُلغى.
library;

/// مضيفو الإعلانات والتتبّع: يُحجب كلُّ ما يُطلب منهم، صفحةً كان أو ملفّاً.
const gameAdHosts = <String>[
  'html5.api.gamedistribution.com',
  'game.api.gamedistribution.com',
  'pm.gamedistribution.com',
  'ana.tunnl.com',
  'imasdk.googleapis.com',
  'pagead2.googlesyndication.com',
  'googleads.g.doubleclick.net',
  'securepubads.g.doubleclick.net',
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'adservice.google.com',
  'adnxs.com',
  'criteo.com',
  'taboola.com',
  'outbrain.com',
];

/// مضيفٌ أو نطاقٌ فرعيٌّ منه.
bool _under(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

bool isAdHost(String host) {
  final h = host.toLowerCase();
  return gameAdHosts.any((domain) => _under(h, domain));
}

/// هل يُسمح للعبة بالانتقال إلى [uri]؟
///
/// [mainFrame]: الصفحةُ كلُّها. ولا تنتقل إلا إلى مضيفٍ من [allowedHosts].
/// وإطارٌ داخليٌّ يُسمح به ما لم يكن إعلاناً: بعضُ الألعاب تفتح شاشاتِها في
/// إطاراتٍ من مضيفٍ آخر لملفّاتها.
///
/// وما ليس http(s) يُلغى دائماً: `intent:` و`market:` تفتح المتجر، و`mailto:`
/// و`tel:` تفتح تطبيقاتٍ أخرى.
bool allowGameNavigation(
  Uri uri, {
  required Set<String> allowedHosts,
  bool mainFrame = true,
}) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'about' || scheme == 'data' || scheme == 'blob') {
    return !mainFrame || scheme == 'about';
  }
  if (scheme != 'http' && scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  if (host.isEmpty || isAdHost(host)) return false;
  if (!mainFrame) return true;
  return allowedHosts.any((allowed) => _under(host, allowed.toLowerCase()));
}

/// المضيفون المسموحُ للعبةٍ برابطها [gameUrl] أن تنتقل إليهم: مضيفُها، ومضيفُ
/// ملفّات GameDistribution إن فُتحت منه مباشرةً.
Set<String> gameHostsFor(String gameUrl) {
  final host = Uri.tryParse(gameUrl)?.host.toLowerCase() ?? '';
  return {
    if (host.isNotEmpty) host,
    'html5.gamedistribution.com',
  };
}
