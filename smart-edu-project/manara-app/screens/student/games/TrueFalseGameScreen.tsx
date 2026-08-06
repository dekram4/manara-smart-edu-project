import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, Dimensions
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { generateTrueFalseQuestions } from '../../../utils/ai';
import { addXP, addGems, unlockAchievement } from '../../../utils/storage';

const { width } = Dimensions.get('window');

export default function TrueFalseGameScreen({ route, navigation }: any) {
  const insets = useSafeAreaInsets();
  const { subject = 'العلوم', lessonContent = '' } = route.params || {};

  const [questions, setQuestions] = useState<any[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [score, setScore] = useState(0);
  const [selected, setSelected] = useState<boolean | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isFinished, setIsFinished] = useState(false);
  const [showResult, setShowResult] = useState(false);
  const [streak, setStreak] = useState(0);
  const [timer, setTimer] = useState(10);
  const [isRunning, setIsRunning] = useState(false);

  useEffect(() => {
    loadQuestions();
  }, []);

  useEffect(() => {
    if (isRunning && timer > 0 && !showResult) {
      const t = setTimeout(() => setTimer(timer - 1), 1000);
      return () => clearTimeout(t);
    } else if (timer === 0 && !showResult) {
      handleAnswer(null);
    }
  }, [timer, isRunning, showResult]);

  const loadQuestions = async () => {
    setIsLoading(true);
    const qs = await generateTrueFalseQuestions(subject, lessonContent, 8);
    setQuestions(qs);
    setIsLoading(false);
    setIsRunning(true);
  };

  const currentQ = questions[currentIndex];

  const handleAnswer = (answer: boolean | null) => {
    if (showResult) return;
    setSelected(answer);
    setShowResult(true);
    setIsRunning(false);

    const isCorrect = answer === currentQ?.isTrue;
    if (isCorrect) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setScore(s => s + 10 + streak * 2);
      setStreak(s => s + 1);
    } else {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      setStreak(0);
    }

    setTimeout(() => {
      if (currentIndex < questions.length - 1) {
        setCurrentIndex(i => i + 1);
        setSelected(null);
        setShowResult(false);
        setTimer(10);
        setIsRunning(true);
      } else {
        finishGame(score + (isCorrect ? 10 + streak * 2 : 0));
      }
    }, 1500);
  };

  const finishGame = async (finalScore: number) => {
    setIsFinished(true);
    await addXP(finalScore);
    if (finalScore >= questions.length * 8) {
      await addGems(10);
      await unlockAchievement('tf_expert', 'خبير صح/خطأ');
    }
  };

  const restart = () => {
    setCurrentIndex(0);
    setScore(0);
    setStreak(0);
    setSelected(null);
    setIsFinished(false);
    setShowResult(false);
    setTimer(10);
    loadQuestions();
  };

  if (isLoading) {
    return (
      <View style={[styles.container, { justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={styles.loadingText}>جارٍ تحميل الأسئلة...</Text>
      </View>
    );
  }

  if (isFinished) {
    const percentage = Math.round((score / (questions.length * 10)) * 100);
    return (
      <View style={[styles.container, { paddingTop: insets.top + 40, justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={styles.resultEmoji}>{percentage >= 80 ? '🏆' : percentage >= 50 ? '🎉' : '💪'}</Text>
        <Text style={styles.resultTitle}>{percentage >= 80 ? 'مبروك!' : 'انتهى!'}</Text>
        <Text style={styles.resultScore}>{score} نقطة</Text>
        <View style={styles.rewardsRow}>
          <Text style={styles.rewardText}>+{score} XP ⭐</Text>
          {percentage >= 80 && <Text style={styles.rewardText}>+10 💎</Text>}
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
        <Text style={styles.headerTitle}>✅❌ صح أم خطأ</Text>
        <Text style={styles.progress}>{currentIndex + 1}/{questions.length}</Text>
      </View>

      {/* Timer */}
      <View style={[styles.timerBar, { width: `${(timer / 10) * 100}%`, backgroundColor: timer <= 3 ? '#F43F5E' : '#4ADE80' }]} />

      {/* Streak */}
      {streak > 1 && (
        <View style={styles.streakBadge}>
          <Text style={styles.streakText}>🔥 {streak} متتالية! (+{streak * 2} نقط إضافية)</Text>
        </View>
      )}

      {currentQ && (
        <View style={styles.gameArea}>
          <View style={styles.questionCard}>
            <Text style={styles.questionText}>{currentQ.statement}</Text>
          </View>

          <View style={styles.buttonsRow}>
            <TouchableOpacity
              onPress={() => handleAnswer(true)}
              disabled={showResult}
              style={[
                styles.answerBtn,
                styles.trueBtn,
                showResult && currentQ.isTrue && styles.correctBtn,
                showResult && selected === true && !currentQ.isTrue && styles.wrongBtn,
              ]}
            >
              <Ionicons name="checkmark" size={40} color="#FFF" />
              <Text style={styles.btnLabel}>صح</Text>
            </TouchableOpacity>

            <TouchableOpacity
              onPress={() => handleAnswer(false)}
              disabled={showResult}
              style={[
                styles.answerBtn,
                styles.falseBtn,
                showResult && !currentQ.isTrue && styles.correctBtn,
                showResult && selected === false && currentQ.isTrue && styles.wrongBtn,
              ]}
            >
              <Ionicons name="close" size={40} color="#FFF" />
              <Text style={styles.btnLabel}>خطأ</Text>
            </TouchableOpacity>
          </View>

          {showResult && (
            <View style={styles.feedback}>
              <Text style={[styles.feedbackText, selected === currentQ.isTrue ? styles.feedbackCorrect : styles.feedbackWrong]}>
                {selected === currentQ.isTrue ? '✅ إجابة صحيحة!' : '❌ إجابة خاطئة!'}
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
  timerBar: { height: 6, marginHorizontal: 20, borderRadius: 3, marginBottom: 8 },
  streakBadge: { backgroundColor: '#FFFBEE', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 16, alignSelf: 'center', marginBottom: 12 },
  streakText: { fontSize: 14, fontWeight: '800', color: '#F59E0B' },
  gameArea: { flex: 1, justifyContent: 'center', paddingHorizontal: 20 },
  questionCard: { backgroundColor: '#FFF', borderRadius: 24, padding: 28, marginBottom: 24, borderWidth: 1, borderColor: '#F0E6D8' },
  questionText: { fontSize: 22, fontWeight: '900', color: '#2D3748', lineHeight: 34, textAlign: 'center' },
  buttonsRow: { flexDirection: 'row', gap: 16 },
  answerBtn: { flex: 1, borderRadius: 24, paddingVertical: 28, alignItems: 'center', justifyContent: 'center', gap: 8 },
  trueBtn: { backgroundColor: '#4ADE80' },
  falseBtn: { backgroundColor: '#F43F5E' },
  correctBtn: { backgroundColor: '#16A34A', borderWidth: 4, borderColor: '#86EFAC' },
  wrongBtn: { backgroundColor: '#DC2626', borderWidth: 4, borderColor: '#FDA4AF' },
  btnLabel: { fontSize: 20, fontWeight: '900', color: '#FFF' },
  feedback: { alignItems: 'center', marginTop: 24 },
  feedbackText: { fontSize: 20, fontWeight: '900' },
  feedbackCorrect: { color: '#16A34A' },
  feedbackWrong: { color: '#DC2626' },
  scoreText: { fontSize: 18, fontWeight: '900', color: '#FF6B35', textAlign: 'center', paddingBottom: 20 },
  resultEmoji: { fontSize: 64, marginBottom: 12 },
  resultTitle: { fontSize: 32, fontWeight: '900', color: '#2D3748', marginBottom: 8 },
  resultScore: { fontSize: 40, fontWeight: '900', color: '#FF6B35', marginBottom: 16 },
  rewardsRow: { flexDirection: 'row', gap: 16, marginBottom: 24 },
  rewardText: { fontSize: 18, fontWeight: '800', color: '#F59E0B' },
  restartBtn: { backgroundColor: '#FF6B35', paddingHorizontal: 40, paddingVertical: 16, borderRadius: 20, marginBottom: 12 },
  restartText: { fontSize: 18, fontWeight: '900', color: '#FFF' },
  backBtn: { paddingVertical: 12 },
  backText: { fontSize: 16, fontWeight: '700', color: '#718096' },
});
