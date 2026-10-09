# صورةُ النشر على Railway: واجهةُ منارة (artifacts/manara) والخادمُ (artifacts/api-server)
# في حاويةٍ واحدة، والخادمُ يقدّم الواجهةَ على عنوانه.
#
# ── لماذا Dockerfile لا Railpack ──
# Railpack يسحب صورةَ alpine من Docker Hub في أوّل كلِّ بناء، وبانيه المشترك
# يُرَدّ بـ 429 Too Many Requests — فيفشل البناءُ قبل أن يبلغ سطراً منّا. والصورةُ
# هنا من سجلّ Amazon العام (ECR Public)، فلا يمرّ البناءُ بـ Docker Hub أصلاً.
#
# bookworm (glibc) لا alpine (musl): تجاوزاتُ pnpm-workspace.yaml تُبقي من الحزم
# الأصلية linux-x64-gnu وحدها.
FROM public.ecr.aws/docker/library/node:20-bookworm-slim

WORKDIR /app

# pnpm بالإصدار الذي كُتب به ملفُّ القفل: pnpm 9 لا يقرأ overrides من
# pnpm-workspace.yaml فيرفض التثبيتَ المجمَّد (ERR_PNPM_LOCKFILE_CONFIG_MISMATCH).
RUN npm install --global pnpm@10.34.5

COPY . .

RUN pnpm install --frozen-lockfile
RUN pnpm run build

ENV NODE_ENV=production
CMD ["node", "--enable-source-maps", "artifacts/api-server/dist/index.mjs"]
