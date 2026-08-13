const GAME_IDS = new Set([
  'd4a3629101574bc39bd8f9d1888ca58e',
  '172e0bd0c40442dbae3d4adb42a98433',
  '659090e00bfc4650899550d63f8a130d',
  'be797a3996324c03b20bad496a82819f',
  '19c63777ed1e4653b64b2200560907fd',
  '72d861a52f3c4e788ae0421649633be3',
]);

const GAME_HOST = 'https://html5.gamedistribution.com/rvvASMiM';
const AD_SDK_PATH = '/ad-sdk.js';

const disabledAdSdk = `
  (() => {
    const emit = (name) => {
      try {
        window.GD_OPTIONS?.onEvent?.({ name, data: {} });
      } catch {
        // The game can continue even if its optional SDK listener is gone.
      }
    };

    window.gdsdk = window.gdsdk || {
      showAd: () => {
        window.setTimeout(() => emit('SDK_GAME_START'), 0);
        return Promise.resolve({ args: { success: true } });
      },
      preloadAd: () => Promise.resolve(),
    };

    // SCG-gd-pixim waits for this event before resolving its game bootstrap.
    window.setTimeout(() => emit('SDK_READY'), 0);
  })();
`;

const bypassPrerollScript = `
<script>
  (() => {
    const patch = () => {
      const sdk = window.gdsdk;
      if (!sdk || typeof sdk.showAd !== 'function' || sdk.__manaraAdBypass) {
        return Boolean(sdk?.__manaraAdBypass);
      }

      sdk.showAd = () => {
        window.setTimeout(() => {
          try {
            window.GD_OPTIONS?.onEvent?.({ name: 'SDK_GAME_START', data: {} });
          } catch {
            // The game can continue if the provider listener is unavailable.
          }
        }, 0);
        return Promise.resolve({ args: { success: true } });
      };
      sdk.__manaraAdBypass = true;
      return true;
    };

    if (!patch()) {
      const timer = window.setInterval(() => {
        if (patch()) window.clearInterval(timer);
      }, 50);
      window.setTimeout(() => window.clearInterval(timer), 30000);
    }
  })();
</script>
`;

function rewriteGameScript(gameId, source) {
  let rewritten = source.replaceAll(
    'https://html5.api.gamedistribution.com/main.min.js',
    `/api/game-embed/${gameId}${AD_SDK_PATH}`,
  );

  const replaceMethod = (methodStart, methodEnd, replacement) => {
    const start = rewritten.indexOf(methodStart);
    const end = start === -1 ? -1 : rewritten.indexOf(methodEnd, start);
    if (start === -1 || end === -1) return;
    rewritten = rewritten.slice(0, start) + replacement + rewritten.slice(end + 1);
  };

  // Disable the provider-level ad call as well as the manager-level call.
  // This covers games that invoke their provider directly.
  replaceMethod(
    'd.prototype.showAd=function(){return gdsdk.showAd()',
    '},d.prototype.showRewardedAd=',
    'd.prototype.showAd=function(){return Promise.resolve(!1)}',
  );

  // The Fireboy & Watergirl build calls its provider from this minified
  // AdManager method. Resolve it immediately so the level transition resumes
  // without replacing the game with GameDistribution's Play Now page.
  replaceMethod(
    'e.prototype.showAd=function(){var a,b,c;',
    '},e.prototype.updateSkipAds=',
    'e.prototype.showAd=function(){return Promise.resolve(!0)}',
  );

  return rewritten;
}

function rewriteGameHtml(gameId, source) {
  const withPrerollBypass = source.replace(
    /\busePrerollAd\s*:\s*true\b/g,
    'usePrerollAd: true',
  );
  return withPrerollBypass.includes('</body>')
    ? withPrerollBypass.replace('</body>', `${bypassPrerollScript}</body>`)
    : `${withPrerollBypass}${bypassPrerollScript}`;
}

function getContentType(pathname, upstreamType) {
  if (upstreamType) return upstreamType;
  if (pathname.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (pathname.endsWith('.json') || pathname.endsWith('.webmanifest')) {
    return 'application/json; charset=utf-8';
  }
  if (pathname.endsWith('.css')) return 'text/css; charset=utf-8';
  if (pathname.endsWith('.html')) return 'text/html; charset=utf-8';
  return 'application/octet-stream';
}

function registerGameEmbedProxy(app) {
  app.get('/api/game-embed/:gameId/*', async (req, res) => {
    const { gameId } = req.params;
    const requestedPath = req.params[0] || 'index.html';

    if (!GAME_IDS.has(gameId) || requestedPath.includes('..') || requestedPath.startsWith('/')) {
      res.status(404).send('Game asset not found');
      return;
    }

    if (requestedPath === AD_SDK_PATH.slice(1)) {
      res.type('application/javascript').send(disabledAdSdk);
      return;
    }

    const upstreamUrl = `${GAME_HOST}/${gameId}/${requestedPath}`;
    try {
      const upstream = await fetch(upstreamUrl);
      if (!upstream.ok) {
        res.status(upstream.status).send(`Game asset request failed (${upstream.status})`);
        return;
      }

      const upstreamType = upstream.headers.get('content-type') || '';
      const isHtml =
        requestedPath.endsWith('.html') || upstreamType.includes('text/html');
      const isJavaScript =
        requestedPath.endsWith('.js') || upstreamType.includes('javascript');

      if (isHtml) {
        const source = await upstream.text();
        res
          .type('html')
          .set('Cache-Control', 'no-store')
          .send(rewriteGameHtml(gameId, source));
        return;
      }

      if (isJavaScript) {
        const source = await upstream.text();
        res
          .type('application/javascript')
          .set('Cache-Control', 'no-store')
          .send(rewriteGameScript(gameId, source));
        return;
      }

      const body = Buffer.from(await upstream.arrayBuffer());
      res
        .set('Content-Type', getContentType(requestedPath, upstreamType))
        .set('Cache-Control', 'no-store')
        .send(body);
    } catch (error) {
      console.error('Game asset proxy error:', error);
      res.status(502).send('Game asset proxy failed');
    }
  });
}

export { registerGameEmbedProxy };