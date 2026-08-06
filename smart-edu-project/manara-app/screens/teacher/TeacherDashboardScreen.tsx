import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useAuth } from '../../App';

const TABS = [
  { id: 'home', label: 'الرئيسية', icon: 'home' },
  { id: 'students', label: 'الطلاب', icon: 'people' },
  { id: 'videos', label: 'الفيديوهات', icon: 'videocam' },
  { id: 'profile', label: 'حسابي', icon: 'person' },
];

const STATS = [
  { label: 'طلاب', value: '24', icon: '👨‍🧐', color: '#F59E0B' },
  { label: 'دروس', value: '12', icon: '📚', color: '#60A5FA' },
  { label: 'اختبارات', value: '8', icon: '🎯', color: '#4ADE80' },
  { label: 'فيديو', value: '15', icon: '🎥', color: '#FB7185' },
];

export default function TeacherDashboardScreen() {
  const insets = useSafeAreaInsets();
  const { logout } = useAuth();
  const [activeTab, setActiveTab] = useState('home');

  const renderHome = () => (
    <View style={styles.tabContent}>
      <View style={styles.statsRow}>
        {STATS.map((s, i) => (
          <View key={i} style={styles.statCard}>
            <Text style={{ fontSize: 28 }}>{s.icon}</Text>
            <Text style={[styles.statValue, { color: s.color }]}>{s.value}</Text>
            <Text style={styles.statLabel}>{s.label}</Text>
          </View>
        ))}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>الأدوات السريعة</Text>
        {[
          { icon: 'videocam', title: 'رفع فيديو جديد', color: '#F59E0B' },
          { icon: 'create', title: 'إنشاء اختبار', color: '#4ADE80' },
          { icon: 'stats-chart', title: 'تقارير الطلاب', color: '#60A5FA' },
          { icon: 'notifications', title: 'إشعارات', color: '#FB7185' },
        ].map((item, i) => (
          <TouchableOpacity key={i} activeOpacity={0.7} style={styles.toolCard} onPress={() => {
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
            Alert.alert(item.title, 'قريباً! سيتم إضافة هذه الميزة في التحديث القادم.');
          }}>
            <View style={[styles.toolIcon, { backgroundColor: item.color + '15' }]}>
              <Ionicons name={item.icon as any} size={24} color={item.color} />
            </View>
            <Text style={styles.toolTitle}>{item.title}</Text>
            <Ionicons name="chevron-back" size={20} color="#A0AEC0" />
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#F59E0B', '#FB923C', '#FF6B35']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.header, { paddingTop: insets.top + 16 }]}>
        <View style={styles.headerTop}>
          <View style={styles.avatar}>
            <Text style={{ fontSize: 30 }}>👨‍🏫</Text>
          </View>
          <View style={styles.headerInfo}>
            <Text style={styles.headerName}>مرحباً يا معلم!</Text>
            <Text style={styles.headerSub}>المرحل العلمي</Text>
          </View>
        </View>
      </LinearGradient>

      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        {activeTab === 'home' && renderHome()}
        {activeTab === 'students' && renderHome()}
        {activeTab === 'videos' && renderHome()}
        {activeTab === 'profile' && (
          <View style={styles.tabContent}>
            <TouchableOpacity activeOpacity={0.7} onPress={() => { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy); logout(); }} style={styles.logoutButton}>
              <Ionicons name="log-out-outline" size={22} color="#EF4444" />
              <Text style={styles.logoutText}>تسجيل الخروج</Text>
            </TouchableOpacity>
          </View>
        )}
      </ScrollView>

      <View style={[styles.bottomNav, { paddingBottom: insets.bottom + 8 }]}>
        {TABS.map((tab) => (
          <TouchableOpacity key={tab.id} activeOpacity={0.7} onPress={() => { Haptics.selectionAsync(); setActiveTab(tab.id); }} style={[styles.navItem, activeTab === tab.id && styles.navItemActive]}>
            <Ionicons name={tab.icon as any} size={24} color={activeTab === tab.id ? '#F59E0B' : '#A0AEC0'} />
            <Text style={[styles.navLabel, activeTab === tab.id && { color: '#F59E0B', fontWeight: '800' }]}>{tab.label}</Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFFBF0' },
  header: { paddingHorizontal: 20, paddingBottom: 24, borderBottomLeftRadius: 32, borderBottomRightRadius: 32, shadowColor: '#F59E0B', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.3, shadowRadius: 20, elevation: 8 },
  headerTop: { flexDirection: 'row', alignItems: 'center' },
  avatar: { width: 50, height: 50, borderRadius: 25, backgroundColor: 'rgba(255,255,255,0.25)', justifyContent: 'center', alignItems: 'center', borderWidth: 2, borderColor: 'rgba(255,255,255,0.4)' },
  headerInfo: { flex: 1, marginLeft: 12 },
  headerName: { fontSize: 18, fontWeight: '900', color: 'white' },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.85)', marginTop: 2, fontWeight: '600' },
  scrollContent: { paddingBottom: 100 },
  tabContent: { padding: 20 },
  statsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginBottom: 20 },
  statCard: { width: '47%', backgroundColor: 'white', borderRadius: 20, padding: 16, alignItems: 'center', shadowColor: '#000', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.05, shadowRadius: 10, elevation: 3, borderWidth: 2, borderColor: '#F0F0F0' },
  statValue: { fontSize: 26, fontWeight: '900', marginTop: 4 },
  statLabel: { fontSize: 12, color: '#A0AEC0', fontWeight: '700', marginTop: 2 },
  section: { marginBottom: 20 },
  sectionTitle: { fontSize: 20, fontWeight: '900', color: '#2D3748', marginBottom: 14 },
  toolCard: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'white', borderRadius: 18, padding: 16, marginBottom: 10, shadowColor: '#000', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.05, shadowRadius: 10, elevation: 3, borderWidth: 2, borderColor: '#F0F0F0' },
  toolIcon: { width: 44, height: 44, borderRadius: 14, justifyContent: 'center', alignItems: 'center', marginRight: 14 },
  toolTitle: { flex: 1, fontSize: 16, fontWeight: '800', color: '#2D3748' },
  logoutButton: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', backgroundColor: '#FFF0F0', borderRadius: 18, padding: 16, marginTop: 20, gap: 8, borderWidth: 2, borderColor: '#FEE2E2' },
  logoutText: { fontSize: 16, fontWeight: '800', color: '#EF4444' },
  bottomNav: { position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: 'white', borderTopWidth: 2, borderTopColor: '#FEF3C7', flexDirection: 'row', justifyContent: 'space-around', paddingTop: 8, paddingHorizontal: 10, shadowColor: '#000', shadowOffset: { width: 0, height: -4 }, shadowOpacity: 0.05, shadowRadius: 12, elevation: 8 },
  navItem: { alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16 },
  navItemActive: { backgroundColor: '#FFFBEB', transform: [{ translateY: -4 }] },
  navLabel: { fontSize: 10, color: '#A0AEC0', marginTop: 2, fontWeight: '600' },
});
