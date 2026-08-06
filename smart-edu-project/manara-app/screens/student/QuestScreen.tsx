import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Animated
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { getData, setData, addXP, addGems, STORAGE_KEYS } from '../../utils/storage';
import { Quest, DEFAULT_QUESTS, playSound, hapticSuccess } from '../../utils/gameEngine';

export default function QuestScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [quests, setQuests] = useState<Quest[]>(DEFAULT_QUESTS);
  const [claimedAnim, setClaimedAnim] = useState<string | null>(null);

  useEffect(() => {
    loadQuests();
  }, []);

  const loadQuests = async () => {
    const saved = await getData('manara_quests', null);
    if (saved) {
      setQuests(saved);
    } else {
      await setData('manara_quests', DEFAULT_QUESTS);
    }
  };

  const handleClaim = async (quest: Quest) => {
    if (quest.claimed || !quest.completed) return;
    playSound('win');
    hapticSuccess();
    setClaimedAnim(quest.id);
    setTimeout(() => setClaimedAnim(null), 1500);

    await addXP(quest.rewardXP);
    await addGems(quest.rewardGems);

    const updated = quests.map(q => q.id === quest.id ? { ...q, claimed: true } : q);
    setQuests(updated);
    await setData('manara_quests', updated);
  };

  const completedCount = quests.filter(q => q.completed).length;
  const claimedCount = quests.filter(q => q.claimed).length;
  const progress = (claimedCount / quests.length) * 100;

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>🏆 مهماتي</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* Progress */}
      <View style={styles.progressCard}>
        <Text style={styles.progressTitle}>تقدمك اليومي</Text>
        <View style={styles.progressBarBg}>
          <View style={[styles.progressBarFill, { width: `${progress}%` }]} />
        </View>
        <Text style={styles.progressText}>{claimedCount} / {quests.length} مهمات مكتملة</Text>
      </View>

      {/* Quests list */}
      <ScrollView style={styles.body} showsVerticalScrollIndicator={false}>
        {quests.map((quest) => {
          const isClaimed = quest.claimed;
          const isCompleted = quest.completed;
          const progressPct = Math.min(100, (quest.current / quest.target) * 100);

          return (
            <TouchableOpacity
              key={quest.id}
              onPress={() => handleClaim(quest)}
              disabled={isClaimed || !isCompleted}
              style={[
                styles.questCard,
                isClaimed && styles.questClaimed,
                isCompleted && !isClaimed && styles.questReady,
                claimedAnim === quest.id && styles.questAnimating,
              ]}
            >
              <View style={styles.questRow}>
                <View style={[styles.questIconBox, isClaimed ? { backgroundColor: '#F0FDF4' } : { backgroundColor: '#FFF5EE' }]}>
                  <Text style={{ fontSize: 28 }}>{isClaimed ? '✅' : quest.icon}</Text>
                </View>
                <View style={styles.questInfo}>
                  <Text style={[styles.questTitle, isClaimed && styles.questTitleDone]}>{quest.title}</Text>
                  <Text style={styles.questDesc}>{quest.description}</Text>
                  {!isCompleted && (
                    <View style={styles.miniBarBg}>
                      <View style={[styles.miniBarFill, { width: `${progressPct}%` }]} />
                    </View>
                  )}
                  <Text style={styles.questProgress}>{quest.current} / {quest.target}</Text>
                </View>
                <View style={styles.rewardsBox}>
                  {isClaimed ? (
                    <Text style={styles.doneBadge}>محصل</Text>
                  ) : (
                    <>
                      <Text style={styles.rewardLine}>+{quest.rewardXP} ⭐</Text>
                      <Text style={styles.rewardLine}>+{quest.rewardGems} 💎</Text>
                      {isCompleted && <Text style={styles.claimBadge}>🎉 اضغط للجبز</Text>}
                    </>
                  )}
                </View>
              </View>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 24, fontWeight: '900', color: '#2D3748' },
  progressCard: { backgroundColor: '#FFF', marginHorizontal: 20, borderRadius: 24, padding: 20, marginBottom: 16, borderWidth: 1, borderColor: '#F0E6D8' },
  progressTitle: { fontSize: 16, fontWeight: '900', color: '#2D3748', marginBottom: 12 },
  progressBarBg: { height: 12, backgroundColor: '#F0E6D8', borderRadius: 8, overflow: 'hidden', marginBottom: 10 },
  progressBarFill: { height: '100%', backgroundColor: '#FF6B35', borderRadius: 8 },
  progressText: { fontSize: 14, fontWeight: '700', color: '#A0AEC0', textAlign: 'center' },
  body: { flex: 1, paddingHorizontal: 20 },
  questCard: { backgroundColor: '#FFF', borderRadius: 20, padding: 16, marginBottom: 12, borderWidth: 1, borderColor: '#F0E6D8' },
  questClaimed: { opacity: 0.6, borderColor: '#4ADE80', backgroundColor: '#F0FDF4' },
  questReady: { borderColor: '#FF6B35', borderWidth: 2, backgroundColor: '#FFF5EE' },
  questAnimating: { transform: [{ scale: 1.05 }] },
  questRow: { flexDirection: 'row', alignItems: 'center' },
  questIconBox: { width: 56, height: 56, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  questInfo: { flex: 1, marginHorizontal: 12 },
  questTitle: { fontSize: 16, fontWeight: '900', color: '#2D3748', marginBottom: 4 },
  questTitleDone: { color: '#16A34A' },
  questDesc: { fontSize: 13, color: '#718096', marginBottom: 6 },
  miniBarBg: { height: 6, backgroundColor: '#F0E6D8', borderRadius: 4, overflow: 'hidden', marginBottom: 4 },
  miniBarFill: { height: '100%', backgroundColor: '#60A5FA', borderRadius: 4 },
  questProgress: { fontSize: 12, color: '#A0AEC0', fontWeight: '700' },
  rewardsBox: { alignItems: 'center' },
  rewardLine: { fontSize: 13, fontWeight: '800', color: '#F59E0B' },
  doneBadge: { fontSize: 12, fontWeight: '900', color: '#16A34A', backgroundColor: '#DCFCE7', paddingHorizontal: 10, paddingVertical: 4, borderRadius: 8 },
  claimBadge: { fontSize: 11, fontWeight: '900', color: '#FF6B35', marginTop: 4 },
});
