import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, Dimensions, Animated
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { addXP, addGems, unlockAchievement } from '../../../utils/storage';

const { width } = Dimensions.get('window');
const CARD_SIZE = (width - 80) / 3;

const EMOJIS = ['☀️', '❄️', '⚡', '🌊', '🌙', '🔬', '🧪', '🌴'];

export default function MemoryGameScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [cards, setCards] = useState<{ id: number; emoji: string; flipped: boolean; matched: boolean }[]>([]);
  const [flippedIndices, setFlippedIndices] = useState<number[]>([]);
  const [moves, setMoves] = useState(0);
  const [time, setTime] = useState(0);
  const [isGameOver, setIsGameOver] = useState(false);
  const [isRunning, setIsRunning] = useState(false);
  const [score, setScore] = useState(0);

  useEffect(() => {
    initGame();
  }, []);

  useEffect(() => {
    if (isRunning && !isGameOver) {
      const timer = setInterval(() => setTime(t => t + 1), 1000);
      return () => clearInterval(timer);
    }
  }, [isRunning, isGameOver]);

  useEffect(() => {
    if (flippedIndices.length === 2) {
      const [a, b] = flippedIndices;
      if (cards[a].emoji === cards[b].emoji) {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        setTimeout(() => {
          setCards(prev => prev.map((c, i) => (i === a || i === b) ? { ...c, matched: true } : c));
          setFlippedIndices([]);
          setScore(s => s + 100);
        }, 500);
      } else {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
        setTimeout(() => {
          setCards(prev => prev.map((c, i) => (i === a || i === b) ? { ...c, flipped: false } : c));
          setFlippedIndices([]);
        }, 1000);
      }
    }
  }, [flippedIndices, cards]);

  useEffect(() => {
    if (cards.length > 0 && cards.every(c => c.matched)) {
      finishGame();
    }
  }, [cards]);

  const initGame = () => {
    const pairs = EMOJIS.slice(0, 6);
    const deck = [...pairs, ...pairs]
      .map((emoji, i) => ({ id: i, emoji, flipped: false, matched: false }))
      .sort(() => Math.random() - 0.5);
    setCards(deck);
    setFlippedIndices([]);
    setMoves(0);
    setTime(0);
    setIsGameOver(false);
    setIsRunning(true);
    setScore(0);
  };

  const finishGame = async () => {
    setIsRunning(false);
    setIsGameOver(true);
    const bonus = Math.max(0, 200 - time);
    const totalScore = score + bonus;
    await addXP(Math.floor(totalScore / 10));
    await addGems(5);
    await unlockAchievement('memory_master', 'سيد الذاكرة');
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  };

  const handleCardPress = (index: number) => {
    if (flippedIndices.length === 2 || cards[index].flipped || cards[index].matched) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setCards(prev => prev.map((c, i) => i === index ? { ...c, flipped: true } : c));
    setFlippedIndices(prev => [...prev, index]);
    if (flippedIndices.length === 0) setMoves(m => m + 1);
  };

  const formatTime = (s: number) => `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, '0')}`;

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="close" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>🧩 لعبة الذاكرة</Text>
        <TouchableOpacity onPress={initGame}>
          <Ionicons name="refresh" size={24} color="#FF6B35" />
        </TouchableOpacity>
      </View>

      {/* Stats */}
      <View style={styles.statsBar}>
        <View style={styles.stat}>
          <Text style={styles.statLabel}>الوقت</Text>
          <Text style={styles.statValue}>{formatTime(time)}</Text>
        </View>
        <View style={styles.stat}>
          <Text style={styles.statLabel}>الحركات</Text>
          <Text style={styles.statValue}>{moves}</Text>
        </View>
        <View style={styles.stat}>
          <Text style={styles.statLabel}>النقاط</Text>
          <Text style={styles.statValue}>{score}</Text>
        </View>
      </View>

      {/* Game Over Overlay */}
      {isGameOver && (
        <View style={styles.overlay}>
          <View style={styles.resultCard}>
            <Text style={styles.resultEmoji}>🎉</Text>
            <Text style={styles.resultTitle}>أحسنت!</Text>
            <Text style={styles.resultScore}>{score} نقطة</Text>
            <Text style={styles.resultTime}>⏱ {formatTime(time)} • {moves} حركة</Text>
            <View style={styles.rewardsRow}>
              <Text style={styles.rewardText}>+{Math.floor(score / 10)} XP ⭐</Text>
              <Text style={styles.rewardText}>+5 💎</Text>
            </View>
            <TouchableOpacity onPress={initGame} style={styles.playAgainBtn}>
              <Text style={styles.playAgainText}>إعادة اللعب</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}

      {/* Grid */}
      <View style={styles.grid}>
        {cards.map((card, idx) => (
          <TouchableOpacity
            key={card.id}
            onPress={() => handleCardPress(idx)}
            disabled={card.flipped || card.matched || isGameOver}
            style={[
              styles.card,
              (card.flipped || card.matched) && styles.cardFlipped,
              card.matched && styles.cardMatched
            ]}
          >
            <Text style={styles.cardEmoji}>
              {card.flipped || card.matched ? card.emoji : '?'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 22, fontWeight: '900', color: '#2D3748' },
  statsBar: { flexDirection: 'row', justifyContent: 'space-around', paddingVertical: 16, backgroundColor: '#FFF', marginHorizontal: 20, borderRadius: 20, marginBottom: 16 },
  stat: { alignItems: 'center' },
  statLabel: { fontSize: 12, color: '#A0AEC0', fontWeight: '700', marginBottom: 4 },
  statValue: { fontSize: 20, fontWeight: '900', color: '#FF6B35' },
  grid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', gap: 12, paddingHorizontal: 20, paddingTop: 10 },
  card: { width: CARD_SIZE, height: CARD_SIZE, backgroundColor: '#FF6B35', borderRadius: 20, justifyContent: 'center', alignItems: 'center', borderWidth: 2, borderColor: '#FF8F65' },
  cardFlipped: { backgroundColor: '#FFF', borderColor: '#F0E6D8' },
  cardMatched: { backgroundColor: '#F0FDF4', borderColor: '#4ADE80', opacity: 0.8 },
  cardEmoji: { fontSize: 36 },
  overlay: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'center', alignItems: 'center', zIndex: 100 },
  resultCard: { backgroundColor: '#FFF', borderRadius: 30, padding: 30, alignItems: 'center', width: width * 0.8 },
  resultEmoji: { fontSize: 56, marginBottom: 12 },
  resultTitle: { fontSize: 28, fontWeight: '900', color: '#2D3748', marginBottom: 8 },
  resultScore: { fontSize: 24, fontWeight: '800', color: '#FF6B35', marginBottom: 4 },
  resultTime: { fontSize: 16, color: '#A0AEC0', marginBottom: 16 },
  rewardsRow: { flexDirection: 'row', gap: 16, marginBottom: 20 },
  rewardText: { fontSize: 16, fontWeight: '800', color: '#F59E0B' },
  playAgainBtn: { backgroundColor: '#FF6B35', paddingHorizontal: 32, paddingVertical: 14, borderRadius: 20 },
  playAgainText: { fontSize: 18, fontWeight: '900', color: '#FFF' },
});
