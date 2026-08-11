import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

function previewStabilizer() {
  return {
    name: 'preview-stabilizer',
    transformIndexHtml(html: string) {
      return html.replace(
        /\s*<script type="module" src="\/@vite\/client"><\/script>\s*/g,
        '\n',
      );
    },
    configureServer(server: any) {
      server.middlewares.use('/favicon.ico', (_req: any, res: any) => {
        res.statusCode = 302;
        res.setHeader('Location', '/favicon.svg');
        res.end();
      });
    },
  };
}

export default defineConfig(({ mode, command }) => {
    const env = loadEnv(mode, '.', '');
    return {
      base: './',
      server: {
        port: 5000,
        host: '0.0.0.0',
        allowedHosts: true,
        // Replit's preview proxy does not forward Vite's HMR socket reliably.
        // Disable it so the proxied preview stays clean; workflow restarts
        // remain the reliable refresh path for this app.
        hmr: false,
        watch: {
          ignored: ['**/sdk/**', '**/node_modules/**', '**/artifacts/**']
        }
      },
      plugins: [
        react(),
        ...(command === 'serve' ? [previewStabilizer()] : []),
      ],
      resolve: {
        alias: {
          '@': path.resolve(__dirname, '.'),
        }
      }
    };
});
