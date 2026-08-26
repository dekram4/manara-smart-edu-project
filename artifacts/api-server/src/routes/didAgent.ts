import { Router } from "express";

const router = Router();

/**
 * D-ID's browser embed requires a client key by design. Keep the configured
 * value in Replit Secrets rather than source control and only return it at
 * runtime to the embedded student client.
 */
router.get("/did-agent/config", (_req, res) => {
  const clientKey = process.env.DID_CLIENT_KEY?.trim();
  const agentId = process.env.DID_AGENT_ID?.trim();
  if (!clientKey || !agentId) {
    return res.status(503).json({
      error: "إعداد المعلم الافتراضي غير مكتمل حاليًا.",
    });
  }

  res.setHeader("Cache-Control", "no-store");
  return res.json({ clientKey, agentId });
});

export default router;