import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  Dimensions, Animated, Alert, FlatList
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';
import { useAuth } from '../../App';
import { getData, addXP, addGems, checkStreak, STORAGE_KEYS } from '../../utils/storage';

const { width } = Dimensions.get('window');

// قائمة الألعاب (مع navigation)
const GAMES = [
  { id: 'memory', title: 'لعبة الذاكرة', icon: '🎮', color: '#FF6B35', bg: '#FFF5EE', screen: 'MemoryGame' },
  { id: 'truefalse', title: 'صح أو خطأ', icon: '✅', color: '#4ECDC4', bg: '#F0FFFB', screen: 'TrueFalseGame' },
  { id: 'speed', title: 'السرعة', icon: '⚡', color: '#A78BFA', bg: '#F9F5FF', screen: 'SpeedQuiz' },
  { id: 'math', title: 'حل المسائل', icon: '🔢', color: '#FFE66D', bg: '#FFFBEE', textColor: '#5C4A00', screen: 'MathSolver' },
];

// المواد
const SUBJECTS = [
  { id: '1', name: 'العلوم', icon: '🔬', color: '#60A5FA', progress: 85 },
  { id: '2', name: 'العربية', icon: '✍️', color: '#F59E0B', progress: 70 },
  { id: '3', name: 'التاريخ', icon: '📚', color: '#A78BFA', progress: 90 },
  { id: '4', name: 'الإسلام', icon: '🤲', color: '#FB7185', progress: 75 },
  { id: '5', name: 'الجغرافيا', icon: '🌎', color: '#4ADE80', progress: 60 },
  { id: '6', name: 'الحاسب', icon: '💻', color: '#FB923C', progress: 50 },
];

// الإنجازات
const ACHIEVEMENTS = [
  { id: '1', title: 'بطل اليوم', icon: '🏅', unlocked: true },
  { id: '2', title: '7 أيام متواصل', icon: '🔥', unlocked: true },
  { id: '3', title: '100 نقطة', icon: '⭐', unlocked: true },
  { id: '4', title: '50 جوهرة', icon: '💎', unlocked: false },
];

// Bottom tabs
const TABS = [
  { id: 'home', label: 'الرئيسية', icon: 'home' },
  { id: 'games', label: 'الألعاب', icon: 'game-controller' },
  { id: 'subjects', label: 'الدروس', icon: 'book' },
  { id: 'profile', label: 'حسابي', icon: 'person' },
];

export default function StudentDashboardScreen() {
  const insets = useSafeAreaInsets();
  const { user, logout } = useAuth();
  const navigation = useNavigation();
  const [activeTab, setActiveTab] = useState('home');
  const [gems, setGems] = useState(0);
  const [xp, setXp] = useState(0);
  const [level, setLevel] = useState(1);
  const [streak, setStreak] = useState(0);
  const [achievements, setAchievements] = useState<any[]>([]);
  const [completedLessons, setCompletedLessons] = useState(0);
  const [completedQuizzes, setCompletedQuizzes] = useState(0);
  const [showCelebration, setShowCelebration] = useState(false);

  // Load real stats from storage
  useEffect(() => {
    const loadStats = async () => {
      await checkStreak();
      const savedXP = await getData(STORAGE_KEYS.XP, 0);
      const savedGems = await getData(STORAGE_KEYS.GEMS, 0);
      const savedStreak = await getData(STORAGE_KEYS.STREAK, 0);
      const savedAchievements = await getData(STORAGE_KEYS.ACHIEVEMENTS, []);
      const savedLessons = await getData('manara_lesson_progress', []);
      const savedQuizzes = await getData('manara_quiz_results', []);

      setXp(savedXP);
      setGems(savedGems);
      setStreak(savedStreak);
      setAchievements(savedAchievements);
      setCompletedLessons(savedLessons.length);
      setCompletedQuizzes(savedQuizzes.length);

      // Calculate level from XP
      const lvl = Math.floor(savedXP / 500) + 1;
      setLevel(lvl);
    };
    loadStats();

    // Poll for updates every 2 seconds
    const interval = setInterval(loadStats, 2000);
    return () => clearInterval(interval);
  }, []);

  // XP bar animation
  const [xpAnim] = useState(new Animated.Value(0));
  useEffect(() => {
    const nextLevelXP = level * 500;
    const currentLevelBase = (level - 1) * 500;
    const progress = ((xp - currentLevelBase) / nextLevelXP) * 100;
    Animated.timing(xpAnim, {
      toValue: Math.max(0, Math.min(100, progress)),
      duration: 1200,
      useNativeDriver: false,
    }).start();
  }, [xp, level]);

  const handleCollectGems = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    setGems(g => g + 5);
    setXp(x => x + 20);
    setShowCelebration(true);
    setTimeout(() => setShowCelebration(false), 2000);
  };

  const renderHome = () => (
    <View style={styles.tabContent}>
      {/* Quick stats - REAL DATA */}
      <View style={styles.statsRow}>
        {[
          { icon: '📚', label: 'الدروس', value: completedLessons.toString(), color: '#60A5FA' },
          { icon: '🎯', label: 'الاختبارات', value: completedQuizzes.toString(), color: '#4ADE80' },
          { icon: '🏆', label: 'الإنجازات', value: achievements.length.toString(), color: '#F59E0B' },
        ].map((stat, i) => (
          <View key={i} style={styles.statCard}>
            <Text style={{ fontSize: 24 }}>{stat.icon}</Text>
            <Text style={[styles.statValue, { color: stat.color }]}>{stat.value}</Text>
            <Text style={styles.statLabel}>{stat.label}</Text>
          </View>
        ))}
      </View>

      {/* XP Progress - REAL DATA */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>تقدمي</Text>
          <Text style={styles.sectionSubtitle}>المستوى {level}</Text>
        </View>
        <View style={styles.xpBar}>
          <Animated.View style={[styles.xpFill, { width: xpAnim.interpolate({
            inputRange: [0, 100], outputRange: ['0%', '100%']
          })}]} />
        </View>
        <Text style={styles.xpText}>{xp} / {level * 500} نقطة (المستوى التالي)</Text>
      </View>

      {/* Games Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>ألعابي التعليمية</Text>
        <View style={styles.gamesGrid}>
          {GAMES.map((game) => (
            <TouchableOpacity
              key={game.id}
              activeOpacity={0.7}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
                if (game.screen) {
                  navigation.navigate(game.screen as any);
                } else {
                  Alert.alert(`🎮 ${game.title}`, 'قريباً يا بطل!');
                }
              }}
            >
              <LinearGradient
                colors={[game.color, game.color + 'dd']}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.gameCard}
              >
                <Text style={{ fontSize: 36, marginBottom: 8 }}>{game.icon}</Text>
                <Text style={[styles.gameTitle, game.textColor ? { color: game.textColor } : {}]}>{game.title}</Text>
              </LinearGradient>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    </View>
  );

  const renderSubjectsTab = () => (
    <View style={styles.tabContent}>
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>موادي الدراسية</Text>
        {SUBJECTS.map((subject) => (
          <TouchableOpacity
            key={subject.id}
            activeOpacity={0.7}
            style={styles.subjectCard}
            onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              navigation.navigate('Lessons', { subject: subject.name });
            }}
          >
            <View style={[styles.subjectIcon, { backgroundColor: subject.color + '20' }]}>
              <Text style={{ fontSize: 28 }}>{subject.icon}</Text>
            </View>
            <View style={styles.subjectInfo}>
              <Text style={styles.subjectName}>{subject.name}</Text>
              <View style={styles.subjectProgress}>
                <View style={[styles.subjectProgressBar, { width: `${subject.progress}%`, backgroundColor: subject.color }]} />
              </View>
              <Text style={[styles.subjectPercent, { color: subject.color }]}>{subject.progress}%</Text>
            </View>
            <Ionicons name="chevron-back" size={22} color="#A0AEC0" />
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );

  const renderGamesTab = () => (
    <View style={styles.tabContent}>
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>🎮 ألعابي التعليمية</Text>
        <View style={styles.gamesGrid}>
          {GAMES.map((game) => (
            <TouchableOpacity
              key={game.id}
              activeOpacity={0.7}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
                if (game.screen) navigation.navigate(game.screen as any);
              }}
            >
              <LinearGradient
                colors={[game.color, game.color + 'dd']}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.gameCard}
              >
                <Text style={{ fontSize: 40, marginBottom: 8 }}>{game.icon}</Text>
                <Text style={[styles.gameTitle, game.textColor ? { color: game.textColor } : {}]}>{game.title}</Text>
              </LinearGradient>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Quick Actions */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>⚡ أدوات سريعة</Text>
        {[
          { label: 'دروسي', icon: '📖', screen: 'Lessons', color: '#60A5FA' },
          { label: 'فيديوهات', icon: '🎬', screen: 'Videos', color: '#F43F5E' },
          { label: 'الدردشة', icon: '💬', screen: 'Chat', color: '#4ADE80' },
          { label: 'الذكاء الاصطناعي', icon: '🧠', screen: 'MathSolver', color: '#A78BFA' },
          { label: 'صديقي الذكي', icon: '🤖', screen: 'Avatar', color: '#EC4899' },
          { label: 'الاجتماع المباشر', icon: '📹', screen: 'LiveMeeting', color: '#EF4444' },
          { label: 'مهماتي', icon: '🏆', screen: 'Quests', color: '#F59E0B' },
          { label: 'المتصدرين', icon: '📊', screen: 'Leaderboard', color: '#22D3EE' },
        ].map((action) => (
          <TouchableOpacity
            key={action.screen}
            activeOpacity={0.7}
            onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              navigation.navigate(action.screen as any);
            }}
            style={styles.actionRow}
          >
            <View style={[styles.actionIcon, { backgroundColor: action.color + '20' }]}>
              <Text style={{ fontSize: 22 }}>{action.icon}</Text>
            </View>
            <Text style={styles.actionText}>{action.label}</Text>
            <Ionicons name="chevron-back" size={20} color="#A0AEC0" />
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );

  const renderProfile = () => (
    <View style={styles.tabContent}>
      {/* Achievements */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>إنجازاتي</Text>
        <View style={styles.achievementsGrid}>
          {ACHIEVEMENTS.map((ach) => (
            <View key={ach.id} style={[styles.achievementCard, !ach.unlocked && styles.achievementLocked]}>
              <Text style={{ fontSize: 32, marginBottom: 6, opacity: ach.unlocked ? 1 : 0.4 }}>{ach.icon}</Text>
              <Text style={[styles.achievementTitle, !ach.unlocked && { color: '#A0AEC0' }]}>{ach.title}</Text>
              {ach.unlocked && <View style={styles.achievementBadge}><Text style={{ fontSize: 10, color: 'white', fontWeight: '700' }}>مكتسب</Text></View>}
            </View>
          ))}
        </View>
      </View>

      {/* Logout */}
      <TouchableOpacity
        activeOpacity={0.7}
        onPress={() => {
          Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
          logout();
        }}
        style={styles.logoutButton}
      >
        <Ionicons name="log-out-outline" size={22} color="#EF4444" />
        <Text style={styles.logoutText}>تسجيل الخروج</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      {/* Celebration overlay */}
      {showCelebration && (
        <View style={styles.celebration}>
          <Text style={styles.celebrationEmoji}>🎉</Text>
          <Text style={styles.celebrationText}>+5 جواهر!</Text>
          {['🎊', '⭐', '🎈', '🎁', '💎'].map((e, i) => (
            <Text key={i} style={[styles.confetti, {
              left: `${15 + i * 18}%`, top: `${5 + (i % 3) * 15}%`,
            }]}>{e}</Text>
          ))}
        </View>
      )}

      {/* Header */}
      <LinearGradient
        colors={['#FF6B35', '#FF6B9D', '#A78BFA']}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={[styles.header, { paddingTop: insets.top + 16 }]}
      >
        <View style={styles.headerTop}>
          <View style={styles.avatar}>
            <Text style={{ fontSize: 30 }}>👨‍🧐</Text>
          </View>
          <View style={styles.headerInfo}>
            <Text style={styles.headerName}>أهلاً يا بطل! ⭐</Text>
            <Text style={styles.headerLevel}>المستوى {level} | {xp} نقطة</Text>
          </View>
          <TouchableOpacity activeOpacity={0.7} onPress={handleCollectGems} style={styles.gemsBadge}>
            <Text style={{ fontSize: 20 }}>💎</Text>
            <Text style={styles.gemsCount}>{gems}</Text>
          </TouchableOpacity>
        </View>

        {/* Streak badge */}
        <View style={styles.streakBadge}>
          <Text style={{ fontSize: 16 }}>🔥</Text>
          <Text style={styles.streakText}>{streak > 0 ? `${streak} أيام متواصل!` : 'بدء اليوم!'}</Text>
        </View>
      </LinearGradient>

      {/* Content */}
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {activeTab === 'home' && renderHome()}
        {activeTab === 'games' && renderGamesTab()}
        {activeTab === 'subjects' && renderSubjectsTab()}
        {activeTab === 'profile' && renderProfile()}
      </ScrollView>

      {/* Bottom Navigation */}
      <View style={[styles.bottomNav, { paddingBottom: insets.bottom + 8 }]}>
        {TABS.map((tab) => (
          <TouchableOpacity
            key={tab.id}
            activeOpacity={0.7}
            onPress={() => {
              Haptics.selectionAsync();
              setActiveTab(tab.id);
            }}
            style={[styles.navItem, activeTab === tab.id && styles.navItemActive]}
          >
            <Ionicons
              name={tab.icon as any}
              size={24}
              color={activeTab === tab.id ? '#FF6B35' : '#A0AEC0'}
            />
            <Text style={[styles.navLabel, activeTab === tab.id && { color: '#FF6B35', fontWeight: '800' }]}>
              {tab.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF5EE' },
  header: {
    paddingHorizontal: 20, paddingBottom: 24,
    borderBottomLeftRadius: 32, borderBottomRightRadius: 32,
    shadowColor: '#FF6B35', shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.3, shadowRadius: 20, elevation: 8,
  },
  headerTop: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  avatar: {
    width: 50, height: 50, borderRadius: 25,
    backgroundColor: 'rgba(255,255,255,0.25)',
    justifyContent: 'center', alignItems: 'center',
    borderWidth: 2, borderColor: 'rgba(255,255,255,0.4)',
  },
  headerInfo: { flex: 1, marginLeft: 12 },
  headerName: { fontSize: 18, fontWeight: '900', color: 'white' },
  headerLevel: { fontSize: 13, color: 'rgba(255,255,255,0.85)', marginTop: 2, fontWeight: '600' },
  gemsBadge: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 16, paddingHorizontal: 12, paddingVertical: 6,
    borderWidth: 2, borderColor: 'rgba(255,255,255,0.3)',
  },
  gemsCount: { fontSize: 16, fontWeight: '900', color: 'white' },
  streakBadge: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    backgroundColor: 'rgba(0,0,0,0.15)',
    borderRadius: 14, paddingHorizontal: 14, paddingVertical: 6,
    alignSelf: 'flex-start',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.2)',
  },
  streakText: { fontSize: 14, fontWeight: '800', color: 'white' },

  scrollContent: { paddingBottom: 100 },
  tabContent: { padding: 20 },

  statsRow: { flexDirection: 'row', gap: 10, marginBottom: 20 },
  statCard: {
    flex: 1, backgroundColor: 'white', borderRadius: 20,
    padding: 14, alignItems: 'center',
    shadowColor: '#000', shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.05, shadowRadius: 10, elevation: 3,
    borderWidth: 2, borderColor: '#F0F0F0',
  },
  statValue: { fontSize: 22, fontWeight: '900', marginTop: 4 },
  statLabel: { fontSize: 11, color: '#A0AEC0', fontWeight: '700', marginTop: 2 },

  section: { marginBottom: 24 },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  sectionTitle: { fontSize: 20, fontWeight: '900', color: '#2D3748' },
  sectionSubtitle: { fontSize: 14, color: '#718096', fontWeight: '600' },

  xpBar: {
    height: 16, backgroundColor: 'rgba(0,0,0,0.08)',
    borderRadius: 10, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(0,0,0,0.05)',
  },
  xpFill: {
    height: '100%', borderRadius: 10,
    backgroundColor: '#FFE66D',
  },
  xpText: { fontSize: 13, color: '#718096', marginTop: 6, fontWeight: '700', textAlign: 'center' },

  gamesGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  gameCard: {
    width: (width - 60) / 2, borderRadius: 24,
    padding: 18, alignItems: 'center',
    shadowColor: '#000', shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1, shadowRadius: 12, elevation: 5,
  },
  gameTitle: { fontSize: 14, fontWeight: '800', color: 'white', textAlign: 'center' },

  subjectCard: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: 'white', borderRadius: 20,
    padding: 14, marginBottom: 10,
    shadowColor: '#000', shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.05, shadowRadius: 10, elevation: 3,
    borderWidth: 2, borderColor: '#F0F0F0',
  },
  subjectIcon: { width: 48, height: 48, borderRadius: 14, justifyContent: 'center', alignItems: 'center' },
  subjectInfo: { flex: 1, marginHorizontal: 12 },
  subjectName: { fontSize: 16, fontWeight: '800', color: '#2D3748', marginBottom: 8 },
  subjectProgress: { height: 8, backgroundColor: '#F3F4F6', borderRadius: 6, overflow: 'hidden' },
  subjectProgressBar: { height: '100%', borderRadius: 6 },
  subjectPercent: { fontSize: 12, fontWeight: '800', marginTop: 4, textAlign: 'left' },

  achievementsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  achievementCard: {
    width: (width - 60) / 2, backgroundColor: 'white',
    borderRadius: 20, padding: 16, alignItems: 'center',
    borderWidth: 2, borderColor: '#FFE8D6',
    shadowColor: '#000', shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.05, shadowRadius: 10, elevation: 3,
  },
  achievementLocked: { borderColor: '#F0F0F0', backgroundColor: '#FAFAFA' },
  achievementTitle: { fontSize: 13, fontWeight: '700', color: '#2D3748', textAlign: 'center', marginTop: 6 },
  achievementBadge: {
    position: 'absolute', top: 8, right: 8,
    backgroundColor: '#4ADE80', borderRadius: 10,
    paddingHorizontal: 8, paddingVertical: 3,
  },

  logoutButton: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    backgroundColor: '#FFF0F0', borderRadius: 18,
    padding: 16, marginTop: 20, gap: 8,
    borderWidth: 2, borderColor: '#FEE2E2',
  },
  logoutText: { fontSize: 16, fontWeight: '800', color: '#EF4444' },

  // Celebration
  celebration: {
    position: 'absolute', inset: 0,
    backgroundColor: 'rgba(0,0,0,0.1)',
    alignItems: 'center', justifyContent: 'center',
    zIndex: 200,
  },
  celebrationEmoji: { fontSize: 80 },
  celebrationText: { fontSize: 32, fontWeight: '900', color: '#FF6B35', marginTop: 16 },
  confetti: { position: 'absolute', fontSize: 32 },

  // Bottom Nav
  bottomNav: {
    position: 'absolute', bottom: 0, left: 0, right: 0,
    backgroundColor: 'white',
    borderTopWidth: 2, borderTopColor: '#FFE8D6',
    flexDirection: 'row', justifyContent: 'space-around',
    paddingTop: 8, paddingHorizontal: 10,
    shadowColor: '#000', shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.05, shadowRadius: 12, elevation: 8,
  },
  navItem: { alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16 },
  navItemActive: { backgroundColor: '#FFF0E8', transform: [{ translateY: -4 }] },
  navLabel: { fontSize: 10, color: '#A0AEC0', marginTop: 2, fontWeight: '600' },

  // Quick Actions
  actionRow: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'white', borderRadius: 18, padding: 14, marginBottom: 10, borderWidth: 2, borderColor: '#F0F0F0' },
  actionIcon: { width: 44, height: 44, borderRadius: 14, justifyContent: 'center', alignItems: 'center' },
  actionText: { flex: 1, fontSize: 15, fontWeight: '800', color: '#2D3748', marginHorizontal: 12 },
});
