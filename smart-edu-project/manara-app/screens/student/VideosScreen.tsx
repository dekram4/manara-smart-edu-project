import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  Dimensions, Linking
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { getData, STORAGE_KEYS, getSampleVideos } from '../../utils/storage';

const { width } = Dimensions.get('window');

export default function VideosScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [videos, setVideos] = useState<any[]>([]);
  const [selectedSubject, setSelectedSubject] = useState<string | null>(null);

  const SUBJECTS = [
    { name: 'العلوم', color: '#60A5FA' },
    { name: 'العربية', color: '#F59E0B' },
    { name: 'الإسلام', color: '#FB7185' },
    { name: 'التاريخ', color: '#A78BFA' },
  ];

  useEffect(() => {
    loadVideos();
  }, []);

  const loadVideos = async () => {
    const saved = await getData(STORAGE_KEYS.VIDEOS, []);
    if (saved.length > 0) setVideos(saved);
    else {
      const samples = getSampleVideos();
      setVideos(samples);
    }
  };

  const filtered = selectedSubject
    ? videos.filter(v => v.subject === selectedSubject)
    : videos;

  const handlePlay = async (video: any) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (video.url) {
      await Linking.openURL(`https://www.youtube.com/watch?v=${video.url}`);
    }
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>🎬 سينما منارة</Text>
        <View style={{ width: 28 }} />
      </View>

      <ScrollView style={styles.body} showsVerticalScrollIndicator={false}>
        {/* Subject filter */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.filterRow}>
          <TouchableOpacity
            onPress={() => setSelectedSubject(null)}
            style={[styles.filterChip, !selectedSubject && styles.filterActive]}
          >
            <Text style={[styles.filterText, !selectedSubject && styles.filterTextActive]}>الكل</Text>
          </TouchableOpacity>
          {SUBJECTS.map((s) => (
            <TouchableOpacity
              key={s.name}
              onPress={() => setSelectedSubject(selectedSubject === s.name ? null : s.name)}
              style={[styles.filterChip, selectedSubject === s.name && { backgroundColor: s.color, borderColor: s.color }]}
            >
              <Text style={[styles.filterText, selectedSubject === s.name && styles.filterTextActive]}>{s.name}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        {/* Videos grid */}
        <View style={styles.grid}>
          {filtered.map((video) => (
            <TouchableOpacity
              key={video.id}
              onPress={() => handlePlay(video)}
              style={styles.videoCard}
            >
              <View style={styles.thumbnail}>
                <View style={[styles.thumbOverlay, { backgroundColor: SUBJECTS.find(s => s.name === video.subject)?.color || '#FF6B35' }]}>
                  <Ionicons name="play" size={40} color="#FFF" />
                </View>
                <View style={[styles.subjectTag, { backgroundColor: SUBJECTS.find(s => s.name === video.subject)?.color || '#FF6B35' }]}>
                  <Text style={styles.tagText}>{video.subject}</Text>
                </View>
              </View>
              <View style={styles.videoInfo}>
                <Text style={styles.videoTitle} numberOfLines={2}>{video.title}</Text>
                <Text style={styles.teacherText}>👨‍🏫 {video.teacher}</Text>
                <Text style={styles.gradeText}>{video.grade}</Text>
              </View>
            </TouchableOpacity>
          ))}
        </View>

        {filtered.length === 0 && (
          <View style={styles.empty}>
            <Text style={styles.emptyEmoji}>🎬</Text>
            <Text style={styles.emptyText}>لا توجد فيديوهات في هذا المجال</Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 22, fontWeight: '900', color: '#2D3748' },
  body: { flex: 1 },
  filterRow: { paddingHorizontal: 16, marginVertical: 12 },
  filterChip: { paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20, backgroundColor: '#FFF', borderWidth: 1, borderColor: '#F0E6D8', marginRight: 8 },
  filterActive: { backgroundColor: '#FF6B35', borderColor: '#FF6B35' },
  filterText: { fontSize: 14, fontWeight: '700', color: '#5C4A00' },
  filterTextActive: { color: '#FFF' },
  grid: { paddingHorizontal: 16, flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  videoCard: { backgroundColor: '#FFF', borderRadius: 20, overflow: 'hidden', borderWidth: 1, borderColor: '#F0E6D8', width: (width - 52) / 2 },
  thumbnail: { width: '100%', height: 120, backgroundColor: '#F7F2EC', position: 'relative' },
  thumbOverlay: { flex: 1, justifyContent: 'center', alignItems: 'center', opacity: 0.9 },
  subjectTag: { position: 'absolute', top: 8, right: 8, paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8 },
  tagText: { fontSize: 11, fontWeight: '800', color: '#FFF' },
  videoInfo: { padding: 12 },
  videoTitle: { fontSize: 14, fontWeight: '800', color: '#2D3748', marginBottom: 6, lineHeight: 20 },
  teacherText: { fontSize: 12, color: '#718096', marginBottom: 2 },
  gradeText: { fontSize: 11, color: '#A0AEC0' },
  empty: { alignItems: 'center', paddingVertical: 80 },
  emptyEmoji: { fontSize: 48, marginBottom: 12 },
  emptyText: { fontSize: 16, color: '#A0AEC0', fontWeight: '700' },
});
