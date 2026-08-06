import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  TextInput, ActivityIndicator
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { solveMathProblem } from '../../utils/ai';
import { addXP, addGems, unlockAchievement } from '../../utils/storage';

const SAMPLE_PROBLEMS = [
  '12 + 7 × 3 - 5 = ?',
  'اجمع زوايا الزواوي 5, 8, 12, 3, 9',
  'ما ناتج 25% من 200 ؟',
  '2³ + 3² = ?',
];

export default function MathSolverScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [problem, setProblem] = useState('');
  const [solution, setSolution] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [history, setHistory] = useState<any[]>([]);

  const handleSolve = async () => {
    if (!problem.trim()) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setIsLoading(true);

    const result = await solveMathProblem(problem);
    setSolution(result);
    setIsLoading(false);

    await addXP(15);
    await unlockAchievement('math_solver', 'حلال الرياضيات');

    setHistory(prev => [{ problem, solution: result, time: new Date().toLocaleTimeString() }, ...prev].slice(0, 10));
  };

  const handleSample = (p: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setProblem(p);
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>⚡ حل المسائل</Text>
        <View style={{ width: 28 }} />
      </View>

      <ScrollView style={styles.body} showsVerticalScrollIndicator={false}>
        {/* Input card */}
        <View style={styles.inputCard}>
          <Text style={styles.inputLabel}>اكتب المسألة الرياضية:</Text>
          <TextInput
            style={styles.input}
            placeholder="مثال: 12 + 7 × 3 = ?"
            value={problem}
            onChangeText={setProblem}
            multiline
            textAlign="right"
          />
          <TouchableOpacity onPress={handleSolve} disabled={isLoading} style={styles.solveBtn}>
            {isLoading ? (
              <ActivityIndicator color="#FFF" />
            ) : (
              <>
                <Ionicons name="flash" size={20} color="#FFF" />
                <Text style={styles.solveText}>حل باستخدام AI (+15 XP)</Text>
              </>
            )}
          </TouchableOpacity>
        </View>

        {/* Sample problems */}
        <Text style={styles.sectionTitle}>📝 أمثلة جاهزة</Text>
        {SAMPLE_PROBLEMS.map((p, i) => (
          <TouchableOpacity key={i} onPress={() => handleSample(p)} style={styles.sampleCard}>
            <Text style={styles.sampleText}>{p}</Text>
            <Ionicons name="arrow-back-circle" size={20} color="#FF6B35" />
          </TouchableOpacity>
        ))}

        {/* Solution */}
        {solution && (
          <View style={styles.solutionCard}>
            <View style={styles.solutionHeader}>
              <Ionicons name="checkmark-circle" size={24} color="#4ADE80" />
              <Text style={styles.solutionTitle}>الحل</Text>
            </View>
            <Text style={styles.solutionText}>{solution}</Text>
          </View>
        )}

        {/* History */}
        {history.length > 0 && (
          <>
            <Text style={styles.sectionTitle}>📋 السجل</Text>
            {history.map((h, i) => (
              <View key={i} style={styles.historyCard}>
                <Text style={styles.historyProblem}>{h.problem}</Text>
                <Text style={styles.historyTime}>{h.time}</Text>
              </View>
            ))}
          </>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 22, fontWeight: '900', color: '#2D3748' },
  body: { flex: 1, paddingHorizontal: 20 },
  inputCard: { backgroundColor: '#FFF', borderRadius: 24, padding: 20, marginBottom: 16, borderWidth: 1, borderColor: '#F0E6D8' },
  inputLabel: { fontSize: 14, fontWeight: '700', color: '#A0AEC0', marginBottom: 12, textAlign: 'right' },
  input: { backgroundColor: '#F7F2EC', borderRadius: 16, padding: 16, fontSize: 16, color: '#2D3748', minHeight: 80, textAlign: 'right' },
  solveBtn: { backgroundColor: '#FF6B35', borderRadius: 16, paddingVertical: 14, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 12 },
  solveText: { fontSize: 16, fontWeight: '800', color: '#FFF' },
  sectionTitle: { fontSize: 16, fontWeight: '900', color: '#2D3748', marginVertical: 12 },
  sampleCard: { backgroundColor: '#FFF', borderRadius: 16, padding: 16, marginBottom: 8, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderWidth: 1, borderColor: '#F0E6D8' },
  sampleText: { fontSize: 15, fontWeight: '700', color: '#2D3748', flex: 1, textAlign: 'right' },
  solutionCard: { backgroundColor: '#F0FDF4', borderRadius: 24, padding: 20, marginVertical: 16, borderWidth: 2, borderColor: '#4ADE80' },
  solutionHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 },
  solutionTitle: { fontSize: 18, fontWeight: '900', color: '#16A34A' },
  solutionText: { fontSize: 15, color: '#2D3748', lineHeight: 24, textAlign: 'right' },
  historyCard: { backgroundColor: '#FFF', borderRadius: 12, padding: 12, marginBottom: 6, borderWidth: 1, borderColor: '#F0E6D8' },
  historyProblem: { fontSize: 14, fontWeight: '700', color: '#2D3748' },
  historyTime: { fontSize: 11, color: '#A0AEC0', marginTop: 4 },
});
