import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  Dimensions, Animated
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { generateQuizQuestions, generateTrueFalseQuestions } from '../../utils/ai';
import { addXP, addGems, unlockAchievement } from '../../utils/storage';

const { width } = Dimensions.get('window');

type QuizType = 'multiple' | 'truefalse';

export default function QuizScreen({ route, navigation }: any) {
  const insets = useSafeAreaInsets();
  const { subject = 'العلوم', lessonContent = '' } = route.params || {};
  
  const [quizType, setQuizType] = useState<QuizType>('multiple');
  const [questions, setQuestions] = useState<any[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [score, setScore] = useState(0);
  const [isFinished, setIsFinished] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [showResult, setShowResult] = useState(false);

  useEffect(() => {
    loadQuestions();
  }, []);

  const loadQuestions = async () => {
    setIsLoading(true);
    if (quizType === 'multiple') {
      const qs = await generateQuizQuestions(subject, lessonContent, 5);
      setQuestions(qs);
    } else {
      const qs = await generateTrueFalseQuestions(subject, lessonContent, 5);
      setQuestions(qs.map((q: any) => ({ ...q, options: ['صح', 'خطأ'], correct: q.isTrue ? 0 : 1 })));
    }
    setIsLoading(false);
  };

  const currentQ = questions[currentIndex];

  const handleSelect = (idx: number) => {
    if (selectedAnswer !== null || !currentQ) return;
    setSelectedAnswer(idx);
    const isCorrect = idx === currentQ.correct;
    
    if (isCorrect) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setScore(s => s + 1);
    } else {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }

    setShowResult(true);
    setTimeout(() => {
      if (currentIndex < questions.length - 1) {
        setCurrentIndex(i => i + 1);
        setSelectedAnswer(null);
        setShowResult(false);
      } else {
        finishQuiz(score + (isCorrect ? 1 : 0));
      }
    }, 1500);
  };

  const finishQuiz = async (finalScore: number) => {
    setIsFinished(true);
    const xp = finalScore * 20;
    await addXP(xp);
    if (finalScore === questions.length) {
      await addGems(10);
      await unlockAchievement('perfect_quiz', 'نتيجة مثالية');
    }
    if (finalScore >= questions.length / 2) {
      await unlockAchievement('quiz_pass', 'اختبار ناجح');
    }
  };

  const restartQuiz = () => {
    setCurrentIndex(0);
    setSelectedAnswer(null);
    setScore(0);
    setIsFinished(false);
    setShowResult(false);
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
    const percentage = Math.round((score / questions.length) * 100);
    const isPerfect = score === questions.length;
    return (
      <View style={[styles.container, { paddingTop: insets.top + 40 }]}>
        <View style={styles.resultCard}>
          <Text style={styles.resultEmoji}>{isPerfect ? '🏆' : score >= questions.length / 2 ? '🎉' : '💪'}</Text>
          <Text style={styles.resultTitle}>{isPerfect ? 'مبروك!' : 'انتهى الاختبار'}</Text>
          <Text style={styles.resultScore}>{score} / {questions.length}</Text>
          <Text style={styles.resultPercent}>{percentage}%</Text>
          
          <View style={styles.rewardsRow}>
            <View style={styles.rewardBadge}>
              <Text style={styles.rewardIcon}>⭐</Text>
              <Text style={styles.rewardText}>+{score * 20} XP</Text>
            </View>
            {isPerfect && (
              <View style={[styles.rewardBadge, { backgroundColor: '#EDE9FE' }]}>
                <Text style={styles.rewardIcon}>💎</Text>
                <Text style={[styles.rewardText, { color: '#7C3AED' }]}>+10 جواهر</Text>
              </View>
            )}
          </View>

          <TouchableOpacity onPress={restartQuiz} style={styles.restartBtn}>
            <LinearGradient colors={['#FF6B35', '#FF8F65']} style={styles.restartGradient}>
              <Text style={styles.restartText}>إعادة الاختبار</Text>
            </LinearGradient>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
            <Text style={styles.backText}>رجوع للدروس</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="close" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>الاختبار</Text>
        <Text style={styles.progressText}>{currentIndex + 1} / {questions.length}</Text>
      </View>

      {/* Progress bar */}
      <View style={styles.progressBarBg}>
        <View style={[styles.progressBarFill, { width: `${((currentIndex) / questions.length) * 100}%` }]} />
      </View>

      {currentQ && (
        <ScrollView style={styles.body} showsVerticalScrollIndicator={false}>
          <View style={styles.questionCard}>
            <Text style={styles.questionNumber}>السؤال {currentIndex + 1}</Text>
            <Text style={styles.questionText}>{currentQ.question || currentQ.statement}</Text>
          </View>

          <View style={styles.optionsContainer}>
            {currentQ.options.map((opt: string, idx: number) => {
              const isSelected = selectedAnswer === idx;
              const isCorrect = idx === currentQ.correct;
              let cardStyle: any = styles.optionCard;
              let textStyle: any = styles.optionText;

              if (showResult) {
                if (isCorrect) {
                  cardStyle = [styles.optionCard, styles.optionCorrect];
                  textStyle = [styles.optionText, styles.optionTextCorrect];
                } else if (isSelected && !isCorrect) {
                  cardStyle = [styles.optionCard, styles.optionWrong];
                  textStyle = [styles.optionText, styles.optionTextWrong];
                }
              } else if (isSelected) {
                cardStyle = [styles.optionCard, styles.optionSelected];
                textStyle = [styles.optionText, styles.optionTextSelected];
              }

              return (
                <TouchableOpacity
                  key={idx}
                  onPress={() => handleSelect(idx)}
                  disabled={selectedAnswer !== null}
                  style={cardStyle}
                >
                  <Text style={textStyle}>{opt}</Text>
                  {showResult && isCorrect && (
                    <Ionicons name="checkmark-circle" size={24} color="#4ADE80" />
                  )}
                  {showResult && isSelected && !isCorrect && (
                    <Ionicons name="close-circle" size={24} color="#F43F5E" />
                  )}
                </TouchableOpacity>
              );
            })}
          </View>
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  loadingText: { fontSize: 18, fontWeight: '700', color: '#718096' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 20, fontWeight: '900', color: '#2D3748' },
  progressText: { fontSize: 16, fontWeight: '800', color: '#FF6B35' },
  progressBarBg: { height: 6, backgroundColor: '#F0E6D8', marginHorizontal: 20, borderRadius: 3, marginBottom: 16 },
  progressBarFill: { height: 6, backgroundColor: '#FF6B35', borderRadius: 3 },
  body: { flex: 1, paddingHorizontal: 20 },
  questionCard: { backgroundColor: '#FFF', borderRadius: 24, padding: 24, marginBottom: 20, borderWidth: 1, borderColor: '#F0E6D8' },
  questionNumber: { fontSize: 14, fontWeight: '700', color: '#A0AEC0', marginBottom: 12 },
  questionText: { fontSize: 20, fontWeight: '900', color: '#2D3748', lineHeight: 32, textAlign: 'right' },
  optionsContainer: { gap: 12, paddingBottom: 40 },
  optionCard: { backgroundColor: '#FFF', borderRadius: 20, padding: 18, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderWidth: 2, borderColor: '#F0E6D8' },
  optionSelected: { borderColor: '#FF6B35', backgroundColor: '#FFF5EE' },
  optionCorrect: { borderColor: '#4ADE80', backgroundColor: '#F0FDF4' },
  optionWrong: { borderColor: '#F43F5E', backgroundColor: '#FFF1F2' },
  optionText: { fontSize: 17, fontWeight: '700', color: '#2D3748', flex: 1, textAlign: 'right' },
  optionTextSelected: { color: '#FF6B35' },
  optionTextCorrect: { color: '#16A34A' },
  optionTextWrong: { color: '#DC2626' },
  resultCard: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 30 },
  resultEmoji: { fontSize: 72, marginBottom: 20 },
  resultTitle: { fontSize: 32, fontWeight: '900', color: '#2D3748', marginBottom: 8 },
  resultScore: { fontSize: 48, fontWeight: '900', color: '#FF6B35', marginBottom: 4 },
  resultPercent: { fontSize: 24, fontWeight: '700', color: '#718096', marginBottom: 24 },
  rewardsRow: { flexDirection: 'row', gap: 12, marginBottom: 30 },
  rewardBadge: { backgroundColor: '#FFFBEE', paddingHorizontal: 16, paddingVertical: 10, borderRadius: 16, flexDirection: 'row', alignItems: 'center', gap: 6 },
  rewardIcon: { fontSize: 18 },
  rewardText: { fontSize: 15, fontWeight: '800', color: '#F59E0B' },
  restartBtn: { width: '100%', marginBottom: 12, borderRadius: 20, overflow: 'hidden' },
  restartGradient: { paddingVertical: 18, alignItems: 'center', borderRadius: 20 },
  restartText: { fontSize: 18, fontWeight: '900', color: '#FFF' },
  backBtn: { paddingVertical: 14 },
  backText: { fontSize: 16, fontWeight: '700', color: '#718096' },
});
