import React, { useEffect } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, ScrollView,
  Dimensions, Animated
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../App';

const { width } = Dimensions.get('window');

const ROLES = [
  { key: 'student', title: 'طالب', subtitle: 'تعلم، تفاعل، واختبر', gradient: ['#FF6B35', '#FF6B9D'], icon: '🎓', bg: '#FFF5EE' },
  { key: 'parent', title: 'ولي أمر', subtitle: 'تابع مستوى أبنائك', gradient: ['#FB7185', '#F472B6'], icon: '👨‍👩‍👧‍👦', bg: '#FFF5F7' },
  { key: 'teacher', title: 'معلم', subtitle: 'أدر طلابك ومحتواك', gradient: ['#F59E0B', '#FB923C'], icon: '👨‍🏫', bg: '#FFFBF0' },
  { key: 'admin', title: 'مشرف', subtitle: 'إدارة النظام', gradient: ['#A78BFA', '#818CF8'], icon: '⚙️', bg: '#F9F7FF' },
];

export default function RoleSelectScreen() {
  const insets = useSafeAreaInsets();
  const { setRole } = useAuth();
  const animValues = ROLES.map(() => new Animated.Value(0));

  useEffect(() => {
    Animated.stagger(150,
      animValues.map(v =>
        Animated.spring(v, { toValue: 1, useNativeDriver: true, friction: 6 })
      )
    ).start();
  }, []);

  const handlePress = (role: any) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setRole(role);
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 20 }]}>
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        {/* Logo */}
        <Animated.View style={{ transform: [{ scale: animValues[0] }] }}>
          <View style={styles.logoCircle}>
            <Text style={styles.logoEmoji}>✌️</Text>
          </View>
        </Animated.View>

        <Text style={styles.title}>منارة المعرفة</Text>
        <Text style={styles.subtitle}>اختر نوع حسابك للدخول</Text>

        {/* Role Cards */}
        <View style={styles.cardsContainer}>
          {ROLES.map((role, i) => (
            <Animated.View key={role.key} style={[
              styles.cardWrapper,
              { transform: [{ scale: animValues[i] }, { translateY: animValues[i].interpolate({ inputRange: [0,1], outputRange: [40, 0] }) }] }
            ]}>
              <TouchableOpacity
                activeOpacity={0.7}
                onPress={() => handlePress(role.key)}
                style={[styles.card, { backgroundColor: role.bg }]}
              >
                <LinearGradient
                  colors={role.gradient as [string, string]}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.cardGradient}
                >
                  <Text style={styles.cardIcon}>{role.icon}</Text>
                  <Text style={styles.cardTitle}>{role.title}</Text>
                  <Text style={styles.cardSubtitle}>{role.subtitle}</Text>
                </LinearGradient>
              </TouchableOpacity>
            </Animated.View>
          ))}
        </View>

        <Text style={styles.footer}>مانارا المعرفة © 2026</Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  scroll: { alignItems: 'center', paddingBottom: 40 },
  logoCircle: {
    width: 90, height: 90, borderRadius: 45,
    backgroundColor: '#FF6B35',
    justifyContent: 'center', alignItems: 'center',
    shadowColor: '#FF6B35', shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4, shadowRadius: 20, elevation: 10,
  },
  logoEmoji: { fontSize: 40 },
  title: { fontSize: 28, fontWeight: '900', color: '#2D3748', marginTop: 16, marginBottom: 6 },
  subtitle: { fontSize: 16, color: '#718096', marginBottom: 30, fontWeight: '600' },
  cardsContainer: { width: width - 40, gap: 14 },
  cardWrapper: { borderRadius: 24, overflow: 'hidden' },
  card: {
    borderRadius: 24, overflow: 'hidden',
    shadowColor: '#000', shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08, shadowRadius: 12, elevation: 4,
  },
  cardGradient: {
    padding: 24,
    alignItems: 'center',
    borderRadius: 24,
  },
  cardIcon: { fontSize: 40, marginBottom: 10 },
  cardTitle: { fontSize: 22, fontWeight: '900', color: 'white', marginBottom: 6 },
  cardSubtitle: { fontSize: 14, color: 'rgba(255,255,255,0.85)', fontWeight: '600' },
  footer: { marginTop: 30, fontSize: 12, color: '#A0AEC0', fontWeight: '500' },
});
