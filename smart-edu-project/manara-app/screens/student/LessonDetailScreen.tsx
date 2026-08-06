import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  Dimensions, ActivityIndicator, Linking
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
// Note: WebView replaced with Linking for web compatibility
import { addXP, unlockAchievement, setData, getData, STORAGE_KEYS } from '../../utils/storage';

const { width } = Dimensions.get('window');

export default function LessonDetailScreen({ route, navigation }: any) {
  const insets = useSafeAreaInsets();
  const { lesson } = route.params;
  const [activeTab, setActiveTab] = useState<'content' | 'video'>('content');
  const [isCompleted, setIsCompleted] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const extractVideoId = (url: string) => {
    if (!url) return null;
    const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
    const match = url.match(regExp);
    return (match && match[2].length === 11) ? match[2] : null;
  };

  const videoId = extractVideoId(lesson.videoUrl);

  const handleComplete = async () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setIsCompleted(true);
    await addXP(50);
    await unlockAchievement('first_lesson', 'أول درس مكمل');
    
    const progress = await getData('manara_lesson_progress', []);
    if (!progress.includes(lesson.id)) {
      progress.push(lesson.id);
      await setData('manara_lesson_progress', progress);
    }
  };

  const handleStartQuiz = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    navigation.navigate('Quiz', { subject: lesson.subject, lessonContent: lesson.content });
  };

  const handleOpenVideo = async () => {
    if (lesson.videoUrl) {
      await Linking.openURL(lesson.videoUrl);
    }
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerRow}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Ionicons name="arrow-back" size={28} color="#2D3748" />
          </TouchableOpacity>
          <Text style={styles.headerTitle} numberOfLines={1}>{lesson.title}</Text>
          <View style={{ width: 28 }} />
        </View>
      </View>

      {/* Tabs */}
      <View style={styles.tabs}>
        <TouchableOpacity
          onPress={() => setActiveTab('content')}
          style={[styles.tab, activeTab === 'content' && styles.tabActive]}
        >
          <Text style={[styles.tabText, activeTab === 'content' && styles.tabTextActive]}>
            📜 المحتوى
          </Text>
        </TouchableOpacity>
        {videoId && (
          <TouchableOpacity
            onPress={() => setActiveTab('video')}
            style={[styles.tab, activeTab === 'video' && styles.tabActive]}
          >
            <Text style={[styles.tabText, activeTab === 'video' && styles.tabTextActive]}>
              🎬 الفيديو
            </Text>
          </TouchableOpacity>
        )}
      </View>

      {activeTab === 'content' ? (
        <ScrollView style={styles.body} showsVerticalScrollIndicator={false}>
          <View style={styles.metaRow}>
            <View style={[styles.badge, { backgroundColor: '#FF6B35' }]}>
              <Text style={styles.badgeText}>{lesson.subject}</Text>
            </View>
            <Text style={styles.metaText}>{lesson.grade} • {lesson.term} • {lesson.unit}</Text>
          </View>

          <View style={styles.contentCard}>
            <Text style={styles.contentText}>{lesson.content}</Text>
            <Text style={styles.contentText}>
              هذا درس تعليمي متين يساعد الطالب على فهم المفاهيم الأساسية في موضوع {lesson.subject}. 
              الدرس يشمل شرح مفصل وأمثلة توضيحية وتمارين في النهاية.
            </Text>
          </View>

          {/* Action buttons */}
          <View style={styles.actions}>
            {!isCompleted ? (
              <TouchableOpacity onPress={handleComplete} style={styles.completeBtn}>
                <LinearGradient colors={['#FF6B35', '#FF8F65']} style={styles.btnGradient}>
                  <Ionicons name="checkmark-circle" size={24} color="#FFF" />
                  <Text style={styles.btnText}>أنهيت الدرس (+50 XP)</Text>
                </LinearGradient>
              </TouchableOpacity>
            ) : (
              <View style={[styles.completeBtn, { backgroundColor: '#4ADE80' }]}>
                <Ionicons name="checkmark-done" size={24} color="#FFF" />
                <Text style={styles.btnText}>تم الدرس ✅</Text>
              </View>
            )}

            <TouchableOpacity onPress={handleStartQuiz} style={styles.quizBtn}>
              <Ionicons name="help-circle" size={24} color="#FF6B35" />
              <Text style={styles.quizBtnText}>اختبر نفسك بالدرس</Text>
            </TouchableOpacity>

            {lesson.videoUrl && (
              <TouchableOpacity onPress={handleOpenVideo} style={styles.videoBtn}>
                <Ionicons name="logo-youtube" size={24} color="#FF0000" />
                <Text style={styles.videoBtnText}>شاهد الفيديو على YouTube</Text>
              </TouchableOpacity>
            )}
          </View>
        </ScrollView>
      ) : (
        <View style={styles.videoContainer}>
          {videoId ? (
            <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 }}>
              <Text style={{ fontSize: 48, marginBottom: 16 }}>🎬</Text>
              <Text style={{ fontSize: 18, fontWeight: '800', color: '#FFF', textAlign: 'center', marginBottom: 20 }}>
                الفيديو جاهز للعرض
              </Text>
              <TouchableOpacity onPress={handleOpenVideo} style={styles.openVideoBtn}>
                <Ionicons name="logo-youtube" size={24} color="#FFF" />
                <Text style={styles.openVideoText}>فتح على YouTube</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.noVideo}>
              <Text style={styles.noVideoText}>لا يوجد فيديو لهذا الدرس</Text>
            </View>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { paddingHorizontal: 20 },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 8 },
  headerTitle: { fontSize: 20, fontWeight: '900', color: '#2D3748', flex: 1, textAlign: 'center', marginHorizontal: 8 },
  tabs: { flexDirection: 'row', paddingHorizontal: 20, marginTop: 12, gap: 8 },
  tab: { flex: 1, paddingVertical: 12, borderRadius: 16, backgroundColor: '#FFF', alignItems: 'center', borderWidth: 1, borderColor: '#F0E6D8' },
  tabActive: { backgroundColor: '#FF6B35', borderColor: '#FF6B35' },
  tabText: { fontSize: 15, fontWeight: '700', color: '#718096' },
  tabTextActive: { color: '#FFF' },
  body: { flex: 1, paddingHorizontal: 20 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 16 },
  badge: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 12 },
  badgeText: { fontSize: 13, fontWeight: '800', color: '#FFF' },
  metaText: { fontSize: 14, color: '#A0AEC0', fontWeight: '600' },
  contentCard: { backgroundColor: '#FFF', borderRadius: 24, padding: 20, borderWidth: 1, borderColor: '#F0E6D8' },
  contentText: { fontSize: 16, color: '#2D3748', lineHeight: 28, marginBottom: 12, textAlign: 'right' },
  actions: { paddingVertical: 20, gap: 12 },
  completeBtn: { borderRadius: 20, overflow: 'hidden', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, paddingVertical: 16 },
  btnGradient: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, paddingVertical: 16, width: '100%', borderRadius: 20 },
  btnText: { fontSize: 16, fontWeight: '800', color: '#FFF' },
  quizBtn: { backgroundColor: '#FFF', borderRadius: 20, paddingVertical: 16, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, borderWidth: 2, borderColor: '#FF6B35' },
  quizBtnText: { fontSize: 16, fontWeight: '800', color: '#FF6B35' },
  videoBtn: { backgroundColor: '#FFF', borderRadius: 20, paddingVertical: 16, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, borderWidth: 2, borderColor: '#FF0000' },
  videoBtnText: { fontSize: 16, fontWeight: '800', color: '#FF0000' },
  videoContainer: { flex: 1, backgroundColor: '#000' },
  noVideo: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  noVideoText: { fontSize: 18, color: '#FFF', fontWeight: '700' },
  openVideoBtn: { backgroundColor: '#FF0000', borderRadius: 20, paddingVertical: 14, paddingHorizontal: 24, flexDirection: 'row', alignItems: 'center', gap: 8 },
  openVideoText: { fontSize: 16, fontWeight: '800', color: '#FFF' },
});
