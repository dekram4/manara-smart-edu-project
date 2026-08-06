import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  Dimensions, FlatList, Image
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { getData, setData, addXP, unlockAchievement, STORAGE_KEYS, getSampleLessons } from '../../utils/storage';

const { width } = Dimensions.get('window');

const SUBJECTS_LIST = [
  { name: 'العلوم', icon: '🔬', color: '#60A5FA' },
  { name: 'العربية', icon: '✍️', color: '#F59E0B' },
  { name: 'التاريخ', icon: '📚', color: '#A78BFA' },
  { name: 'الإسلام', icon: '🤲', color: '#FB7185' },
  { name: 'الجغرافيا', icon: '🌎', color: '#4ADE80' },
  { name: 'الحاسب', icon: '💻', color: '#FB923C' },
];

export default function LessonsScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [selectedSubject, setSelectedSubject] = useState<string | null>(null);
  const [lessons, setLessons] = useState<any[]>([]);
  const [completedLessons, setCompletedLessons] = useState<string[]>([]);

  useEffect(() => {
    loadLessons();
    loadProgress();
  }, []);

  const loadLessons = async () => {
    const saved = await getData(STORAGE_KEYS.LESSONS, []);
    if (saved.length > 0) {
      setLessons(saved);
    } else {
      // Seed with sample lessons
      const samples = getSampleLessons();
      await setData(STORAGE_KEYS.LESSONS, samples);
      setLessons(samples);
    }
  };

  const loadProgress = async () => {
    const progress = await getData('manara_lesson_progress', []);
    setCompletedLessons(progress);
  };

  const filteredLessons = selectedSubject
    ? lessons.filter(l => l.subject === selectedSubject)
    : lessons;

  const handleLessonPress = async (lesson: any) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    navigation.navigate('LessonDetail', { lesson });
  };

  const renderSubjectChip = (subject: typeof SUBJECTS_LIST[0]) => {
    const isActive = selectedSubject === subject.name;
    return (
      <TouchableOpacity
        key={subject.name}
        onPress={() => {
          Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
          setSelectedSubject(isActive ? null : subject.name);
        }}
        style={[styles.subjectChip, isActive && { backgroundColor: subject.color }]}
      >
        <Text style={{ fontSize: 20 }}>{subject.icon}</Text>
        <Text style={[styles.chipText, isActive && styles.chipTextActive]}>
          {subject.name}
        </Text>
      </TouchableOpacity>
    );
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      <LinearGradient colors={['#FF6B35', '#FF8F65']} style={styles.header}>
        <View style={styles.headerRow}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Ionicons name="arrow-back" size={28} color="#FFF" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>📖 الدروس</Text>
          <View style={{ width: 28 }} />
        </View>
      </LinearGradient>

      <ScrollView style={styles.body} showsVerticalScrollIndicator={false}>
        {/* Subject filter */}
        <View style={styles.subjectsRow}>
          {SUBJECTS_LIST.map(renderSubjectChip)}
        </View>

        {/* Lessons list */}
        <Text style={styles.sectionTitle}>
          {selectedSubject || 'كل الدروس'} ({filteredLessons.length})
        </Text>

        {filteredLessons.map((lesson) => {
          const isDone = completedLessons.includes(lesson.id);
          return (
            <TouchableOpacity
              key={lesson.id}
              onPress={() => handleLessonPress(lesson)}
              style={[styles.lessonCard, isDone && styles.lessonDone]}
            >
              <View style={styles.lessonHeader}>
                <View style={[styles.subjectBadge, { backgroundColor: SUBJECTS_LIST.find(s => s.name === lesson.subject)?.color || '#FF6B35' }]}>
                  <Text style={styles.badgeText}>{lesson.subject}</Text>
                </View>
                <Text style={styles.gradeText}>{lesson.grade} • {lesson.term}</Text>
              </View>
              <Text style={styles.lessonTitle}>{lesson.title}</Text>
              <Text style={styles.lessonPreview} numberOfLines={2}>
                {lesson.content}
              </Text>
              <View style={styles.lessonFooter}>
                <Text style={styles.unitText}>📁 {lesson.unit}</Text>
                {lesson.videoUrl ? (
                  <View style={styles.videoBadge}>
                    <Ionicons name="play-circle" size={16} color="#FF6B35" />
                    <Text style={styles.videoText}>فيديو</Text>
                  </View>
                ) : null}
                {isDone && (
                  <View style={styles.doneBadge}>
                    <Ionicons name="checkmark-circle" size={16} color="#4ADE80" />
                    <Text style={styles.doneText}>منتهي</Text>
                  </View>
                )}
              </View>
            </TouchableOpacity>
          );
        })}

        {filteredLessons.length === 0 && (
          <View style={styles.emptyState}>
            <Text style={styles.emptyEmoji}>📖</Text>
            <Text style={styles.emptyText}>لا توجد دروس في هذا المجال</Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { paddingHorizontal: 20, paddingBottom: 20, borderBottomLeftRadius: 30, borderBottomRightRadius: 30 },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 12 },
  headerTitle: { fontSize: 24, fontWeight: '900', color: '#FFF' },
  body: { flex: 1, paddingHorizontal: 16 },
  subjectsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 16, marginBottom: 8 },
  subjectChip: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#FFF', paddingHorizontal: 12, paddingVertical: 8, borderRadius: 20, gap: 6, borderWidth: 1, borderColor: '#F0E6D8' },
  chipText: { fontSize: 13, fontWeight: '700', color: '#5C4A00' },
  chipTextActive: { color: '#FFF' },
  sectionTitle: { fontSize: 18, fontWeight: '900', color: '#2D3748', marginVertical: 16 },
  lessonCard: { backgroundColor: '#FFF', borderRadius: 20, padding: 16, marginBottom: 12, borderWidth: 1, borderColor: '#F0E6D8' },
  lessonDone: { borderColor: '#4ADE80', borderWidth: 2 },
  lessonHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 8 },
  subjectBadge: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 12 },
  badgeText: { fontSize: 12, fontWeight: '700', color: '#FFF' },
  gradeText: { fontSize: 12, color: '#A0AEC0', fontWeight: '600' },
  lessonTitle: { fontSize: 16, fontWeight: '900', color: '#2D3748', marginBottom: 6 },
  lessonPreview: { fontSize: 14, color: '#718096', lineHeight: 20, marginBottom: 10 },
  lessonFooter: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  unitText: { fontSize: 12, color: '#A0AEC0', fontWeight: '600' },
  videoBadge: { flexDirection: 'row', alignItems: 'center', gap: 4, backgroundColor: '#FFF5EE', paddingHorizontal: 8, paddingVertical: 4, borderRadius: 10 },
  videoText: { fontSize: 12, color: '#FF6B35', fontWeight: '700' },
  doneBadge: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  doneText: { fontSize: 12, color: '#4ADE80', fontWeight: '700' },
  emptyState: { alignItems: 'center', paddingVertical: 60 },
  emptyEmoji: { fontSize: 48, marginBottom: 12 },
  emptyText: { fontSize: 16, color: '#A0AEC0', fontWeight: '700' },
});
