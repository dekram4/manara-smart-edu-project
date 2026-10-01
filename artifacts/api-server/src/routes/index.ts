import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import geminiRouter from "./gemini";
import mediaRouter from "./media";
import gameEmbedRouter from "./gameEmbed";
import supabaseBridgeRouter from "./supabaseBridge";
import studentChatRouter from "./studentChat";
import studentProgressRouter from "./studentProgress";
import duelRouter from "./duel";
import duelQuestionsRouter from "./duelQuestions";
import didAgentRouter from "./didAgent";

const router: IRouter = Router();

router.use(healthRouter);
router.use(authRouter);
router.use(geminiRouter);
router.use(studentChatRouter);
router.use(studentProgressRouter);
router.use(duelRouter);
router.use(duelQuestionsRouter);
router.use(didAgentRouter);
router.use(mediaRouter);
router.use(gameEmbedRouter);
router.use(supabaseBridgeRouter);

export default router;
