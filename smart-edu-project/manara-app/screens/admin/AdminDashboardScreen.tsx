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
  { id: 'users', label: 'المستخدمون', icon: 'people' },
  { id: 'reports', label: 'التقارير', icon: 'document-text' },
  { id: 'profile', label: 'حسابي', icon: 'person' },
];

const ADMIN_STATS = [
  { label: 'طلاب', value: '156', icon: '👨‍🧐', color: '#60A5FA' },
  { label: 'معلمين', value: '24', icon: '👨‍🏫', color: '#F59E0B' },
  { label: 'ولياء', value: '89', icon: '👨‍👩‍👧‍👦', color: '#FB7185' },
  { label: 'فيديو', value: '42', icon: '🎥', color: '#A78BFA' },
];

const MANAGEMENT_TOOLS = [
  { icon: 'people', title: 'إدارة المستخدمين', color: '#60A5FA' },
  { icon: 'videocam', title: 'مراجعة الفيديوهات', color: '#A78BFA' },
  { icon: 'stats-chart', title: 'التقارير الشاملة', color: '#4ADE80' },
  { icon: 'settings', title: 'إعدادات النظام', color: '#F59E0B' },
  { icon: 'notifications', title: 'إشعارات', color: '#FB7185' },
  { icon: 'shield', title: 'الصلاحيات', color: '#818CF8' },
];

export default function AdminDashboardScreen() {
  const insets = useSafeAreaInsets();
  const { logout } = useAuth();
  const [activeTab, setActiveTab] = useState('home');

  const renderHome = () => (
    <View style={styles.tabContent}>
      {/* System overview */}
      <View style={styles.overviewCard}>
        <Text style={styles.overviewTitle}>نظرة شاملة على النظام</Text>
        <View style={styles.overviewRow}>
          {ADMIN_STATS.map((s, i) => (
            <View key={i} style={styles.overviewItem}>
              <Text style={{ fontSize: 28 }}>{s.icon}</Text>
              <Text style={[styles.overviewValue, { color: s.color }]}>{s.value}</Text>
              <Text style={styles.overviewLabel}>{s.label}</Text>
            </View>
          ))}
        </View>
      </View>

      {/* Management tools */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>أدوات الإدارة</Text>
        <View style={styles.toolsGrid}>
          {MANAGEMENT_TOOLS.map((tool, i) => (
            <TouchableOpacity key={i} activeOpacity={0.7} style={styles.toolCard} onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
              Alert.alert(tool.title, 'قريباً! سيتم إضافة هذه الأداة في التحديث القادم.');
            }}>
              <View style={[styles.toolIcon, { backgroundColor: tool.color + '15' }]}>
                <Ionicons name={tool.icon as any} size={24} color={tool.color} />
              </View>
              <Text style={[styles.toolTitle, { color: tool.color }]}>{tool.title}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Notifications panel */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>إشعارات الفيديوهات</Text>
        <View style={styles.notificationCard}>
          <View style={styles.notificationDot} />
          <View style={styles.notificationInfo}>
            <Text style={styles.notificationTitle}>فيديو جديد من المعلم أحمد</Text>
            <Text style={styles.notificationTime}>منذ 5 دقائق</Text>
          </View>
          <Ionicons name="chevron-back" size={20} color="#A0AEC0" />
        </View>
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#A78BFA', '#818CF8', '#6366F1']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.header, { paddingTop: insets.top + 16 }]}>
        <View style={styles.headerTop}>
          <View style={styles.avatar}><Text style={{ fontSize: 30 }}>⚙️</Text></View>
          <View style={styles.headerInfo}>
            <Text style={styles.headerName}>لوحة إدارة المشرف</Text>
            <Text style={styles.headerSub}>مشرف المنصة</Text>
          </View>
        </View>
      </LinearGradient>

      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        {activeTab === 'home' && renderHome()}
        {activeTab === 'users' && renderHome()}
        {activeTab === 'reports' && renderHome()}
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
            <Ionicons name={tab.icon as any} size={24} color={activeTab === tab.id ? '#A78BFA' : '#A0AEC0'} />
            <Text style={[styles.navLabel, activeTab === tab.id && { color: '#A78BFA', fontWeight: '800' }]}>{tab.label}</Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F9F7FF' },
  header: { paddingHorizontal: 20, paddingBottom: 24, borderBottomLeftRadius: 32, borderBottomRightRadius: 32, shadowColor: '#A78BFA', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.3, shadowRadius: 20, elevation: 8 },
  headerTop: { flexDirection: 'row', alignItems: 'center' },
  avatar: { width: 50, height: 50, borderRadius: 25, backgroundColor: 'rgba(255,255,255,0.25)', justifyContent: 'center', alignItems: 'center', borderWidth: 2, borderColor: 'rgba(255,255,255,0.4)' },
  headerInfo: { flex: 1, marginLeft: 12 },
  headerName: { fontSize: 18, fontWeight: '900', color: 'white' },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.85)', marginTop: 2, fontWeight: '600' },
  scrollContent: { paddingBottom: 100 },
  tabContent: { padding: 20 },
  overviewCard: { backgroundColor: 'white', borderRadius: 24, padding: 20, marginBottom: 20, shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.06, shadowRadius: 12, elevation: 4, borderWidth: 2, borderColor: '#F0F0F0' },
  overviewTitle: { fontSize: 18, fontWeight: '900', color: '#2D3748', marginBottom: 16 },
  overviewRow: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-around' },
  overviewItem: { width: '45%', alignItems: 'center', marginBottom: 14 },
  overviewValue: { fontSize: 26, fontWeight: '900', marginTop: 4 },
  overviewLabel: { fontSize: 12, color: '#A0AEC0', fontWeight: '700', marginTop: 2 },
  section: { marginBottom: 20 },
  sectionTitle: { fontSize: 20, fontWeight: '900', color: '#2D3748', marginBottom: 14 },
  toolsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  toolCard: { width: '47%', backgroundColor: 'white', borderRadius: 18, padding: 16, alignItems: 'center', shadowColor: '#000', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.05, shadowRadius: 10, elevation: 3, borderWidth: 2, borderColor: '#F0F0F0' },
  toolIcon: { width: 48, height: 48, borderRadius: 14, justifyContent: 'center', alignItems: 'center', marginBottom: 10 },
  toolTitle: { fontSize: 13, fontWeight: '800', textAlign: 'center' },
  notificationCard: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'white', borderRadius: 18, padding: 16, shadowColor: '#000', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.05, shadowRadius: 10, elevation: 3, borderWidth: 2, borderColor: '#F0F0F0' },
  notificationDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: '#EF4444', marginRight: 12 },
  notificationInfo: { flex: 1 },
  notificationTitle: { fontSize: 15, fontWeight: '800', color: '#2D3748' },
  notificationTime: { fontSize: 12, color: '#A0AEC0', marginTop: 2, fontWeight: '600' },
  logoutButton: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', backgroundColor: '#FFF0F0', borderRadius: 18, padding: 16, marginTop: 20, gap: 8, borderWidth: 2, borderColor: '#FEE2E2' },
  logoutText: { fontSize: 16, fontWeight: '800', color: '#EF4444' },
  bottomNav: { position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: 'white', borderTopWidth: 2, borderTopColor: '#EDE9FE', flexDirection: 'row', justifyContent: 'space-around', paddingTop: 8, paddingHorizontal: 10, shadowColor: '#000', shadowOffset: { width: 0, height: -4 }, shadowOpacity: 0.05, shadowRadius: 12, elevation: 8 },
  navItem: { alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16 },
  navItemActive: { backgroundColor: '#F9F7FF', transform: [{ translateY: -4 }] },
  navLabel: { fontSize: 10, color: '#A0AEC0', marginTop: 2, fontWeight: '600' },
});
