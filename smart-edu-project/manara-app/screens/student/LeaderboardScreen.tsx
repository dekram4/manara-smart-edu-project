import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { getLeaderboard } from '../../utils/gameEngine';
import { getData, STORAGE_KEYS } from '../../utils/storage';

export default function LeaderboardScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [leaderboard, setLeaderboard] = useState<any[]>([]);
  const [myXP, setMyXP] = useState(0);
  const [myLevel, setMyLevel] = useState(1);

  useEffect(() => {
    const board = getLeaderboard();
    // Insert "me" with current stats
    loadMyStats(board);
  }, []);

  const loadMyStats = async (board: any[]) => {
    const xp = await getData(STORAGE_KEYS.XP, 0);
    setMyXP(xp);
    const level = Math.floor(xp / 500) + 1;
    setMyLevel(level);

    // Insert me at correct position
    const me = { rank: 0, name: 'أنت', avatar: '🤖', xp, level, streak: 0, isMe: true };
    const updated = [...board.filter(b => !b.isMe), me].sort((a, b) => b.xp - a.xp);
    updated.forEach((u, i) => u.rank = i + 1);
    setLeaderboard(updated.slice(0, 10));
  };

  const getRankColor = (rank: number) => {
    if (rank === 1) return '#FFD700';
    if (rank === 2) return '#C0C0C0';
    if (rank === 3) return '#CD7F32';
    return '#E2E8F0';
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>🏆 المتصدرين</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* Top 3 Podium */}
      {leaderboard.length >= 3 && (
        <View style={styles.podium}>
          {/* 2nd place */}
          <View style={styles.podiumItem}>
            <View style={[styles.podiumAvatar, { backgroundColor: '#C0C0C0' }]}>
              <Text style={styles.podiumEmoji}>{leaderboard[1].avatar}</Text>
            </View>
            <Text style={styles.podiumName} numberOfLines={1}>{leaderboard[1].name}</Text>
            <Text style={styles.podiumXP}>{leaderboard[1].xp} XP</Text>
            <View style={[styles.podiumBar, { height: 70, backgroundColor: '#C0C0C0' }]}>
              <Text style={styles.podiumRank}>2</Text>
            </View>
          </View>

          {/* 1st place */}
          <View style={[styles.podiumItem, { marginTop: -20 }]}>
            <View style={[styles.podiumAvatar, { backgroundColor: '#FFD700', borderWidth: 3, borderColor: '#F59E0B' }]}>
              <Text style={styles.podiumEmoji}>{leaderboard[0].avatar}</Text>
              <Text style={styles.crown}>👑</Text>
            </View>
            <Text style={styles.podiumName} numberOfLines={1}>{leaderboard[0].name}</Text>
            <Text style={styles.podiumXP}>{leaderboard[0].xp} XP</Text>
            <View style={[styles.podiumBar, { height: 100, backgroundColor: '#FFD700' }]}>
              <Text style={styles.podiumRank}>1</Text>
            </View>
          </View>

          {/* 3rd place */}
          <View style={styles.podiumItem}>
            <View style={[styles.podiumAvatar, { backgroundColor: '#CD7F32' }]}>
              <Text style={styles.podiumEmoji}>{leaderboard[2].avatar}</Text>
            </View>
            <Text style={styles.podiumName} numberOfLines={1}>{leaderboard[2].name}</Text>
            <Text style={styles.podiumXP}>{leaderboard[2].xp} XP</Text>
            <View style={[styles.podiumBar, { height: 50, backgroundColor: '#CD7F32' }]}>
              <Text style={styles.podiumRank}>3</Text>
            </View>
          </View>
        </View>
      )}

      {/* List */}
      <ScrollView style={styles.list} showsVerticalScrollIndicator={false}>
        {leaderboard.map((item) => (
          <View key={item.rank} style={[styles.listItem, item.isMe && styles.listItemMe]}>
            <View style={[styles.rankBadge, { backgroundColor: getRankColor(item.rank) }]}>
              <Text style={[styles.rankText, item.rank <= 3 && { color: '#FFF' }]}>{item.rank}</Text>
            </View>
            <Text style={styles.listAvatar}>{item.avatar}</Text>
            <View style={styles.listInfo}>
              <Text style={[styles.listName, item.isMe && styles.listNameMe]}>{item.name}</Text>
              <Text style={styles.listMeta}>المستوى {item.level} • 🔥 {item.streak} يوم</Text>
            </View>
            <Text style={styles.listXP}>{item.xp} XP</Text>
          </View>
        ))}
      </ScrollView>

      {/* My stats footer */}
      <View style={[styles.myStats, { paddingBottom: insets.bottom + 10 }]}>
        <LinearGradient colors={['#FF6B35', '#FF8F65']} style={styles.myStatsGradient}>
          <Text style={styles.myStatsText}>
            نقاطك: {myXP} XP • المستوى {myLevel}
          </Text>
          <Text style={styles.myStatsSub}>
            واصل التعلم للتصعد في المتصدرين!
          </Text>
        </LinearGradient>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 24, fontWeight: '900', color: '#2D3748' },
  podium: { flexDirection: 'row', justifyContent: 'center', alignItems: 'flex-end', paddingHorizontal: 20, paddingTop: 20, marginBottom: 20 },
  podiumItem: { alignItems: 'center', flex: 1 },
  podiumAvatar: { width: 60, height: 60, borderRadius: 30, justifyContent: 'center', alignItems: 'center', marginBottom: 8 },
  podiumEmoji: { fontSize: 32 },
  crown: { fontSize: 20, position: 'absolute', top: -12 },
  podiumName: { fontSize: 13, fontWeight: '800', color: '#2D3748', maxWidth: 80, textAlign: 'center' },
  podiumXP: { fontSize: 12, fontWeight: '700', color: '#718096', marginTop: 2 },
  podiumBar: { width: 60, borderTopLeftRadius: 12, borderTopRightRadius: 12, justifyContent: 'center', alignItems: 'center', marginTop: 8 },
  podiumRank: { fontSize: 24, fontWeight: '900', color: '#FFF' },
  list: { flex: 1, paddingHorizontal: 20 },
  listItem: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#FFF', borderRadius: 16, padding: 14, marginBottom: 8, borderWidth: 1, borderColor: '#F0E6D8' },
  listItemMe: { borderColor: '#FF6B35', borderWidth: 2, backgroundColor: '#FFF5EE' },
  rankBadge: { width: 32, height: 32, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  rankText: { fontSize: 14, fontWeight: '900', color: '#5C4A00' },
  listAvatar: { fontSize: 28, marginHorizontal: 12 },
  listInfo: { flex: 1 },
  listName: { fontSize: 15, fontWeight: '800', color: '#2D3748' },
  listNameMe: { color: '#FF6B35' },
  listMeta: { fontSize: 12, color: '#A0AEC0', marginTop: 2 },
  listXP: { fontSize: 14, fontWeight: '900', color: '#FF6B35' },
  myStats: { paddingHorizontal: 20, paddingTop: 10 },
  myStatsGradient: { borderRadius: 20, padding: 16, alignItems: 'center' },
  myStatsText: { fontSize: 16, fontWeight: '900', color: '#FFF' },
  myStatsSub: { fontSize: 13, color: 'rgba(255,255,255,0.85)', marginTop: 4 },
});
