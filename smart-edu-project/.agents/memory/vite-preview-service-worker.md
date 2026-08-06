---
name: Vite preview and service worker
description: Development preview rules for avoiding stale PWA caches and unsupported HMR sockets.
---

القاعدة: يجب ألا يسجل التطبيق Service Worker أثناء التطوير، ويجب أن يمرر Service Worker طلبات Vite وصفحات HTML من الشبكة. تعطيل HMR وحده لا يكفي إذا كانت صفحة قديمة مخزنة قد حقنت عميل Vite.

**Why:** بروكسي معاينة Replit لا يمرر WebSocket الخاص بـ Vite بشكل موثوق، وكاش PWA القديم كان يعيد HTML يحتوي `/@vite/client` ويسبب أخطاء WebSocket وطلبات أصول قديمة.

**How to apply:** عند تعديل إعدادات التطوير أو PWA، اختبر HTML الخام والسجل بعد إعادة تشغيل workflow، وتأكد من عدم وجود `/@vite/client` غير المقصود أو طلبات 404 للأيقونات.