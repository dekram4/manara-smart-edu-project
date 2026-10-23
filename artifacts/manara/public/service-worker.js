// 🚀 Service Worker لتطبيق MANARA PWA (استخدام بدون إنترنت)
//
// ‏v3: طلباتُ /api/ لا تمرّ بالذاكرة أبداً. كانت v2 تحفظ كلَّ GET وتردّ منها
// ‏أوّلاً — ومنها `/api/auth/admin/session` وجداولُ الطلاب والمعلمين والرسائل.
// ‏فبعد الخروج تفتح لوحةُ المشرف من ردٍّ محفوظ بلا كلمة مرور، ويرى المعلمُ
// ‏الداخلُ بعده جداولَ المشرف. وتغييرُ الاسم يطرد ذاكرةَ v2 كلَّها عند التفعيل.
const CACHE_NAME = 'manara-v4';
const IS_DEV_HOST = /^(localhost|127\.0\.0\.1)$/.test(self.location.hostname);
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/index.css',
  '/manara-icon-192.png',
  '/audio/welcome-student.mp3',
  '/audio/welcome-adult.mp3',
  '/audio/welcome-all.mp3',
];

// تثبيت: قم بتخزين الملفات
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    }).catch(() => {
      // إذا فشل تحميل ملف ما، نمر بطلاً
    })
  );
  self.skipWaiting();
});

// تنشيط: طرد النسخة القديمة
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
    })
  );
  self.clients.claim();
});

// جدار: محاولة الاستجابة من الذاكرة أو الشبكة
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const requestUrl = new URL(event.request.url);
  // ‏بياناتُ الحساب وجلستُه، وما ليس من هذا الموقع: إلى الشبكة كما هي، بلا ذاكرة.
  if (requestUrl.origin !== self.location.origin || requestUrl.pathname.startsWith('/api/')) return;
  const isViteRequest = requestUrl.pathname.startsWith('/@vite/');
  const isHtmlRequest = event.request.mode === 'navigate' ||
    event.request.headers.get('accept')?.includes('text/html');

  // لا يسمح كاش PWA بحجب Vite أو صفحة HTML الحديثة في التطوير.
  if (IS_DEV_HOST || isViteRequest) {
    event.respondWith(fetch(event.request));
    return;
  }

  // صفحات التنقل تُحدّث من الشبكة أولاً حتى لا تعرض نسخة قديمة.
  if (isHtmlRequest) {
    event.respondWith(
      fetch(event.request)
        .then((networkResponse) => {
          if (networkResponse.ok) {
            caches.open(CACHE_NAME).then((cache) =>
              cache.put(event.request, networkResponse.clone())
            );
          }
          return networkResponse;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        // عرد الشبكة بعد ذلك للتحديث
        fetch(event.request).then((networkResponse) => {
          if (networkResponse && networkResponse.ok) {
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, networkResponse.clone());
            });
          }
        }).catch(() => {});
        return cachedResponse;
      }

      return fetch(event.request).then((networkResponse) => {
        if (!networkResponse || networkResponse.status !== 200 || networkResponse.type !== 'basic') {
          return networkResponse;
        }
        const responseToCache = networkResponse.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseToCache);
        });
        return networkResponse;
      });
    }).catch(() => {
      // فشل كلي: عدم الاتصال بالشبكة ولا يوجد في الذاكرة
    })
  );
});
