import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import geminiRouter from "./gemini";
import mediaRouter from "./media";
import gameEmbedRouter from "./gameEmbed";

const router: IRouter = Router();

router.use(healthRouter);
router.use(authRouter);
router.use(geminiRouter);
router.use(mediaRouter);
router.use(gameEmbedRouter);

export default router;
