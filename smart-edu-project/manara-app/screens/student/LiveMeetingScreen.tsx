import React, { useState } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, Linking, ScrollView, TextInput
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

// Demo meeting rooms for the platform
const DEMO_ROOMS = [
  { id: '1', name: 'اجتماع الصف السابس - العلوم', teacher: 'أحمد المعلم', subject: 'العلوم', status: 'live', participants: 12, time: '10:00 - 11:00' },
  { id: '2', name: 'اجتماع الصف الرابع - الرياضيات', teacher: 'فاطمة المعلم', subject: 'الحاسب', status: 'upcoming', participants: 0, time: '12:00 - 13:00' },
  { id: '3', name: 'اجتماع أولياء الأمور - الإسلام', teacher: 'المشرف', subject: 'الإسلام', status: 'live', participants: 8, time: '14:00 - 15:00' },
];

export default function LiveMeetingScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [activeTab, setActiveTab] = useState<'live' | 'upcoming'>('live');
  const [roomCode, setRoomCode] = useState('');

  const filtered = DEMO_ROOMS.filter(r => activeTab === 'live' ? r.status === 'live' : r.status === 'upcoming');

  const handleJoin = async (room: typeof DEMO_ROOMS[0]) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    // For demo, open Jitsi Meet with room name
    const jitsiUrl = `https://meet.jit.si/manara-${room.id}`;
    await Linking.openURL(jitsiUrl);
  };

  const handleJoinByCode = async () => {
    if (!roomCode.trim()) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const jitsiUrl = `https://meet.jit.si/${roomCode.trim()}`;
    await Linking.openURL(jitsiUrl);
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>📹 الاجتماع المباشر</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* Join by code */}
      <View style={styles.codeCard}>
        <Text style={styles.codeLabel}>أدخل رمز الغرفة</Text>
        <View style={styles.codeRow}>
          <TextInput
            style={styles.codeInput}
            placeholder="manara-room123"
            value={roomCode}
            onChangeText={setRoomCode}
            textAlign="center"
          />
          <TouchableOpacity onPress={handleJoinByCode} style={styles.joinBtn}>
            <Text style={styles.joinText}>دخول</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Tabs */}
      <View style={styles.tabs}>
        <TouchableOpacity
          onPress={() => setActiveTab('live')}
          style={[styles.tab, activeTab === 'live' && styles.tabActive]}
        >
          <Text style={[styles.tabText, activeTab === 'live' && styles.tabTextActive]}>
            🔴 مباشر ({DEMO_ROOMS.filter(r => r.status === 'live').length})
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={() => setActiveTab('upcoming')}
          style={[styles.tab, activeTab === 'upcoming' && styles.tabActive]}
        >
          <Text style={[styles.tabText, activeTab === 'upcoming' && styles.tabTextActive]}>
            ⏰ قادم ({DEMO_ROOMS.filter(r => r.status === 'upcoming').length})
          </Text>
        </TouchableOpacity>
      </View>

      {/* Rooms list */}
      <ScrollView style={styles.body} showsVerticalScrollIndicator={false}>
        {filtered.map((room) => (
          <View key={room.id} style={styles.roomCard}>
            <View style={styles.roomHeader}>
              <View style={[styles.statusBadge, { backgroundColor: room.status === 'live' ? '#FEF2F2' : '#FFFBEE' }]}>
                <View style={[styles.statusDot, { backgroundColor: room.status === 'live' ? '#EF4444' : '#F59E0B' }]} />
                <Text style={[styles.statusText, { color: room.status === 'live' ? '#EF4444' : '#F59E0B' }]}>
                  {room.status === 'live' ? 'مباشر' : 'قادم'}
                </Text>
              </View>
              <Text style={styles.roomTime}>🕐 {room.time}</Text>
            </View>

            <Text style={styles.roomName}>{room.name}</Text>
            <View style={styles.roomMeta}>
              <Text style={styles.teacherText}>👨‍🏫 {room.teacher}</Text>
              <Text style={styles.subjectText}>📚 {room.subject}</Text>
            </View>

            {room.status === 'live' && (
              <View style={styles.participantsRow}>
                <Text style={styles.participantsText}>👥 {room.participants} مشارك</Text>
              </View>
            )}

            <TouchableOpacity
              onPress={() => handleJoin(room)}
              style={[styles.joinRoomBtn, room.status === 'upcoming' && styles.upcomingBtn]}
            >
              <Ionicons name="videocam" size={20} color="#FFF" />
              <Text style={styles.joinRoomText}>
                {room.status === 'live' ? 'انضم الآن' : 'تذكير'}
              </Text>
            </TouchableOpacity>
          </View>
        ))}

        {filtered.length === 0 && (
          <View style={styles.empty}>
            <Text style={styles.emptyEmoji}>📹</Text>
            <Text style={styles.emptyText}>لا توجد اجتماعات {activeTab === 'live' ? 'مباشرة' : 'قادمة'}</Text>
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
  codeCard: { backgroundColor: '#FFF', marginHorizontal: 20, borderRadius: 20, padding: 16, marginBottom: 12, borderWidth: 1, borderColor: '#F0E6D8' },
  codeLabel: { fontSize: 14, fontWeight: '700', color: '#A0AEC0', marginBottom: 10, textAlign: 'center' },
  codeRow: { flexDirection: 'row', gap: 10 },
  codeInput: { flex: 1, backgroundColor: '#F7F2EC', borderRadius: 16, padding: 12, fontSize: 15, color: '#2D3748', fontWeight: '700' },
  joinBtn: { backgroundColor: '#FF6B35', borderRadius: 16, paddingHorizontal: 20, paddingVertical: 12, justifyContent: 'center' },
  joinText: { fontSize: 15, fontWeight: '800', color: '#FFF' },
  tabs: { flexDirection: 'row', paddingHorizontal: 20, gap: 8, marginBottom: 12 },
  tab: { flex: 1, paddingVertical: 12, borderRadius: 16, backgroundColor: '#FFF', alignItems: 'center', borderWidth: 1, borderColor: '#F0E6D8' },
  tabActive: { backgroundColor: '#FF6B35', borderColor: '#FF6B35' },
  tabText: { fontSize: 15, fontWeight: '700', color: '#718096' },
  tabTextActive: { color: '#FFF' },
  body: { flex: 1, paddingHorizontal: 20 },
  roomCard: { backgroundColor: '#FFF', borderRadius: 24, padding: 20, marginBottom: 12, borderWidth: 1, borderColor: '#F0E6D8' },
  roomHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  statusBadge: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10 },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  statusText: { fontSize: 12, fontWeight: '800' },
  roomTime: { fontSize: 13, color: '#A0AEC0', fontWeight: '600' },
  roomName: { fontSize: 17, fontWeight: '900', color: '#2D3748', marginBottom: 8, lineHeight: 24 },
  roomMeta: { flexDirection: 'row', gap: 16, marginBottom: 10 },
  teacherText: { fontSize: 13, color: '#718096', fontWeight: '600' },
  subjectText: { fontSize: 13, color: '#718096', fontWeight: '600' },
  participantsRow: { marginBottom: 12 },
  participantsText: { fontSize: 13, color: '#4ADE80', fontWeight: '800' },
  joinRoomBtn: { backgroundColor: '#FF6B35', borderRadius: 16, paddingVertical: 14, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 },
  upcomingBtn: { backgroundColor: '#F59E0B' },
  joinRoomText: { fontSize: 16, fontWeight: '900', color: '#FFF' },
  empty: { alignItems: 'center', paddingVertical: 60 },
  emptyEmoji: { fontSize: 48, marginBottom: 12 },
  emptyText: { fontSize: 16, color: '#A0AEC0', fontWeight: '700' },
});
