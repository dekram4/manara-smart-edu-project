import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import geminiRouter from "./gemini";
import mediaRouter from "./media";
import gameEmbedRouter from "./gameEmbed";
import supabaseBridgeRouter from "./supabaseBridge";
import studentChatRouter from "./studentChat";
import didAgentRouter from "./didAgent";

const router: IRouter = Router();

router.use(healthRouter);
router.use(authRouter);
router.use(geminiRouter);
router.use(studentChatRouter);
router.use(didAgentRouter);
router.use(mediaRouter);
router.use(gameEmbedRouter);
router.use(supabaseBridgeRouter);

export default router;
