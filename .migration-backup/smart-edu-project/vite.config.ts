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
          // Resolve the app's React copy explicitly. The workspace also has
          // a top-level node_modules folder, and Vite can otherwise bundle a
          // second React instance for lazily loaded dashboard components.
          react: path.resolve(__dirname, 'node_modules/react'),
          'react-dom': path.resolve(__dirname, 'node_modules/react-dom'),
        },
        // The workspace and imported project each have node_modules folders.
        // Keep React/R3F on one module instance or lazy-loaded 3D components
        // can trigger an Invalid Hook Call in the preview browser.
        dedupe: ['react', 'react-dom', 'three'],
      }
    };
});
