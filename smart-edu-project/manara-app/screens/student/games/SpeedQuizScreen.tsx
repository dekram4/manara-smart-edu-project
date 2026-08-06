import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, Dimensions
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { generateQuizQuestions } from '../../../utils/ai';
import { addXP, addGems, unlockAchievement } from '../../../utils/storage';

const { width } = Dimensions.get('window');

export default function SpeedQuizScreen({ route, navigation }: any) {
  const insets = useSafeAreaInsets();
  const { subject = 'العلوم', lessonContent = '' } = route.params || {};

  const [questions, setQuestions] = useState<any[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [score, setScore] = useState(0);
  const [timer, setTimer] = useState(15);
  const [isLoading, setIsLoading] = useState(true);
  const [isFinished, setIsFinished] = useState(false);
  const [showResult, setShowResult] = useState(false);
  const [combo, setCombo] = useState(0);
  const [isRunning, setIsRunning] = useState(false);
  const [correctCount, setCorrectCount] = useState(0);

  useEffect(() => {
    loadQuestions();
  }, []);

  useEffect(() => {
    if (isRunning && timer > 0 && !showResult) {
      const t = setTimeout(() => setTimer(timer - 1), 1000);
      return () => clearTimeout(t);
    } else if (timer === 0 && !showResult) {
      handleAnswer(-1);
    }
  }, [timer, isRunning, showResult]);

  const loadQuestions = async () => {
    setIsLoading(true);
    const qs = await generateQuizQuestions(subject, lessonContent, 10);
    setQuestions(qs);
    setIsLoading(false);
    setIsRunning(true);
  };

  const currentQ = questions[currentIndex];

  const handleAnswer = (idx: number) => {
    if (showResult || !currentQ) return;
    setShowResult(true);
    setIsRunning(false);

    const isCorrect = idx === currentQ.correct;
    if (isCorrect) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      const bonus = Math.floor(timer / 3) + combo;
      setScore(s => s + 10 + bonus);
      setCombo(c => c + 1);
      setCorrectCount(c => c + 1);
    } else {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setCombo(0);
    }

    setTimeout(() => {
      if (currentIndex < questions.length - 1) {
        setCurrentIndex(i => i + 1);
        setShowResult(false);
        setTimer(15);
        setIsRunning(true);
      } else {
        finishGame();
      }
    }, 1500);
  };

  const finishGame = async () => {
    setIsFinished(true);
    await addXP(Math.floor(score / 5));
    if (correctCount >= questions.length * 0.8) {
      await addGems(15);
      await unlockAchievement('speed_demon', 'سريع كالبر ناجح');
    }
    if (correctCount >= questions.length * 0.5) {
      await unlockAchievement('quiz_warrior', 'مقاتل الاختبارات');
    }
  };

  const restart = () => {
    setCurrentIndex(0);
    setScore(0);
    setCombo(0);
    setCorrectCount(0);
    setIsFinished(false);
    setShowResult(false);
    setTimer(15);
    loadQuestions();
  };

  if (isLoading) {
    return (
      <View style={[styles.container, { justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={styles.loadingText}>جارٍ تحميل...</Text>
      </View>
    );
  }

  if (isFinished) {
    return (
      <View style={[styles.container, { paddingTop: insets.top + 40, justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={styles.resultEmoji}>{correctCount >= questions.length * 0.8 ? '🌟' : '🎉'}</Text>
        <Text style={styles.resultTitle}>انتهى التحدي!</Text>
        <Text style={styles.resultScore}>{correctCount}/{questions.length} صحيح</Text>
        <Text style={styles.resultTotal}>{score} نقطة</Text>
        <View style={styles.rewardsRow}>
          <Text style={styles.rewardText}>+{Math.floor(score / 5)} XP ⭐</Text>
          {correctCount >= questions.length * 0.8 && <Text style={styles.rewardText}>+15 💎</Text>}
        </View>
        <TouchableOpacity onPress={restart} style={styles.restartBtn}>
          <Text style={styles.restartText}>إعادة اللعب</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Text style={styles.backText}>رجوع</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="close" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>⚡ السرعة</Text>
        <Text style={styles.progress}>{currentIndex + 1}/{questions.length}</Text>
      </View>

      {/* Timer */}
      <View style={styles.timerContainer}>
        <View style={[styles.timerBg, { width: `${(timer / 15) * 100}%`, backgroundColor: timer <= 5 ? '#F43F5E' : timer <= 10 ? '#F59E0B' : '#4ADE80' }]} />
        <Text style={styles.timerText}>⏱ {timer}s</Text>
      </View>

      {combo > 1 && (
        <View style={styles.comboBadge}>
          <Text style={styles.comboText}>🔥 Combo x{combo}! (+{combo} نقاط)</Text>
        </View>
      )}

      {currentQ && (
        <View style={styles.gameArea}>
          <View style={styles.questionCard}>
            <Text style={styles.questionText}>{currentQ.question}</Text>
          </View>

          <View style={styles.optionsGrid}>
            {currentQ.options.map((opt: string, idx: number) => {
              let style: any = styles.optionBtn;
              if (showResult) {
                if (idx === currentQ.correct) style = [styles.optionBtn, styles.correctOption];
                else style = [styles.optionBtn, styles.wrongOption];
              }
              return (
                <TouchableOpacity
                  key={idx}
                  onPress={() => handleAnswer(idx)}
                  disabled={showResult}
                  style={style}
                >
                  <Text style={styles.optionText}>{opt}</Text>
                </TouchableOpacity>
              );
            })}
          </View>

          {showResult && (
            <View style={styles.feedback}>
              <Text style={[styles.feedbackText, { color: '#16A34A' }]}>
                الإجابة الصحيحة: {currentQ.options[currentQ.correct]}
              </Text>
            </View>
          )}
        </View>
      )}

      <Text style={styles.scoreText}>النقاط: {score}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  loadingText: { fontSize: 18, fontWeight: '700', color: '#718096' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 20, fontWeight: '900', color: '#2D3748' },
  progress: { fontSize: 16, fontWeight: '800', color: '#FF6B35' },
  timerContainer: { marginHorizontal: 20, height: 32, backgroundColor: '#F0E6D8', borderRadius: 16, overflow: 'hidden', marginBottom: 12, flexDirection: 'row', alignItems: 'center' },
  timerBg: { height: '100%', borderRadius: 16 },
  timerText: { position: 'absolute', right: 12, fontSize: 14, fontWeight: '800', color: '#2D3748' },
  comboBadge: { backgroundColor: '#FFFBEE', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 16, alignSelf: 'center', marginBottom: 8 },
  comboText: { fontSize: 14, fontWeight: '800', color: '#F59E0B' },
  gameArea: { flex: 1, paddingHorizontal: 20 },
  questionCard: { backgroundColor: '#FFF', borderRadius: 24, padding: 24, marginBottom: 20, borderWidth: 1, borderColor: '#F0E6D8' },
  questionText: { fontSize: 20, fontWeight: '900', color: '#2D3748', lineHeight: 30, textAlign: 'center' },
  optionsGrid: { gap: 10 },
  optionBtn: { backgroundColor: '#FFF', borderRadius: 16, paddingVertical: 16, paddingHorizontal: 20, borderWidth: 2, borderColor: '#F0E6D8', alignItems: 'center' },
  correctOption: { backgroundColor: '#F0FDF4', borderColor: '#4ADE80' },
  wrongOption: { opacity: 0.5, borderColor: '#F0E6D8' },
  optionText: { fontSize: 16, fontWeight: '800', color: '#2D3748', textAlign: 'center' },
  feedback: { alignItems: 'center', marginTop: 16 },
  feedbackText: { fontSize: 18, fontWeight: '900' },
  scoreText: { fontSize: 18, fontWeight: '900', color: '#FF6B35', textAlign: 'center', paddingBottom: 20 },
  resultEmoji: { fontSize: 64, marginBottom: 12 },
  resultTitle: { fontSize: 32, fontWeight: '900', color: '#2D3748', marginBottom: 8 },
  resultScore: { fontSize: 28, fontWeight: '900', color: '#16A34A', marginBottom: 4 },
  resultTotal: { fontSize: 22, fontWeight: '800', color: '#FF6B35', marginBottom: 16 },
  rewardsRow: { flexDirection: 'row', gap: 16, marginBottom: 24 },
  rewardText: { fontSize: 18, fontWeight: '800', color: '#F59E0B' },
  restartBtn: { backgroundColor: '#FF6B35', paddingHorizontal: 40, paddingVertical: 16, borderRadius: 20, marginBottom: 12 },
  restartText: { fontSize: 18, fontWeight: '900', color: '#FFF' },
  backBtn: { paddingVertical: 12 },
  backText: { fontSize: 16, fontWeight: '700', color: '#718096' },
});
