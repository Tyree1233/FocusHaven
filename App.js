import { StatusBar } from 'expo-status-bar';
import { useEffect, useState } from 'react';
import {
  Image,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

const FOCUS_SECONDS = 25 * 60;

function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60).toString().padStart(2, '0');
  const remainingSeconds = (seconds % 60).toString().padStart(2, '0');
  return `${minutes}:${remainingSeconds}`;
}

export default function App() {
  const [secondsLeft, setSecondsLeft] = useState(FOCUS_SECONDS);
  const [isRunning, setIsRunning] = useState(false);

  useEffect(() => {
    if (!isRunning || secondsLeft === 0) return undefined;

    const timer = setInterval(() => {
      setSecondsLeft((current) => current - 1);
    }, 1000);

    return () => clearInterval(timer);
  }, [isRunning, secondsLeft]);

  useEffect(() => {
    if (secondsLeft === 0) setIsRunning(false);
  }, [secondsLeft]);

  const resetTimer = () => {
    setIsRunning(false);
    setSecondsLeft(FOCUS_SECONDS);
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="light" />
      <View style={styles.container}>
        <View style={styles.brandRow}>
          <Image source={require('./assets/focushaven-logo.png')} style={styles.logo} />
          <View>
            <Text style={styles.brand}>FocusHaven</Text>
            <Text style={styles.tagline}>Where focus feels safe</Text>
          </View>
        </View>

        <View style={styles.greeting}>
          <Text style={styles.eyebrow}>YOUR QUIET SPACE</Text>
          <Text style={styles.title}>One gentle step at a time.</Text>
          <Text style={styles.subtitle}>Settle in, breathe deeply, and give your attention a place to rest.</Text>
        </View>

        <View style={styles.timerCard}>
          <Text style={styles.sessionLabel}>{secondsLeft === 0 ? 'SESSION COMPLETE' : 'FOCUS SESSION'}</Text>
          <Text style={styles.timer}>{formatTime(secondsLeft)}</Text>
          <View style={styles.progressTrack}>
            <View style={[styles.progressFill, { width: `${((FOCUS_SECONDS - secondsLeft) / FOCUS_SECONDS) * 100}%` }]} />
          </View>
          <Text style={styles.timerHint}>A calm 25-minute focus session</Text>

          <Pressable
            accessibilityRole="button"
            onPress={() => setIsRunning((running) => !running)}
            style={({ pressed }) => [styles.primaryButton, pressed && styles.pressed]}
          >
            <Text style={styles.primaryButtonText}>{isRunning ? 'Pause session' : secondsLeft === 0 ? 'Start again' : 'Begin focus'}</Text>
          </Pressable>
          <Pressable accessibilityRole="button" onPress={resetTimer} style={styles.resetButton}>
            <Text style={styles.resetButtonText}>Reset timer</Text>
          </Pressable>
        </View>

        <View style={styles.intentionCard}>
          <Text style={styles.intentionLabel}>TODAY'S INTENTION</Text>
          <Text style={styles.intention}>“I only need to begin.”</Text>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: '#211442' },
  container: { flex: 1, backgroundColor: '#211442', paddingHorizontal: 24, paddingTop: 18 },
  brandRow: { alignItems: 'center', flexDirection: 'row', gap: 12 },
  logo: { borderRadius: 20, height: 50, width: 50 },
  brand: { color: '#FFE8D5', fontSize: 23, fontWeight: '700', letterSpacing: -0.4 },
  tagline: { color: '#D9C6F8', fontSize: 12, marginTop: 2 },
  greeting: { marginTop: 58 },
  eyebrow: { color: '#F57AC9', fontSize: 12, fontWeight: '700', letterSpacing: 1.5 },
  title: { color: '#FFF4EC', fontSize: 36, fontWeight: '700', letterSpacing: -1.1, lineHeight: 43, marginTop: 10 },
  subtitle: { color: '#D5C6E8', fontSize: 16, lineHeight: 24, marginTop: 14 },
  timerCard: { backgroundColor: '#352260', borderColor: '#5B3E91', borderRadius: 28, borderWidth: 1, marginTop: 34, padding: 28, shadowColor: '#130927', shadowOpacity: 0.45, shadowRadius: 20, elevation: 8 },
  sessionLabel: { color: '#F6B1DA', fontSize: 12, fontWeight: '700', letterSpacing: 1.4, textAlign: 'center' },
  timer: { color: '#FFF1E4', fontSize: 68, fontVariant: ['tabular-nums'], fontWeight: '700', letterSpacing: -2, marginTop: 10, textAlign: 'center' },
  progressTrack: { backgroundColor: '#4C3579', borderRadius: 8, height: 8, marginTop: 14, overflow: 'hidden' },
  progressFill: { backgroundColor: '#F167B9', borderRadius: 8, height: '100%' },
  timerHint: { color: '#C7B8DB', fontSize: 13, marginTop: 12, textAlign: 'center' },
  primaryButton: { alignItems: 'center', backgroundColor: '#F16FBA', borderRadius: 16, marginTop: 28, paddingVertical: 16 },
  primaryButtonText: { color: '#28133F', fontSize: 16, fontWeight: '800' },
  resetButton: { alignItems: 'center', marginTop: 16 },
  resetButtonText: { color: '#DCCBF0', fontSize: 14, fontWeight: '600' },
  intentionCard: { backgroundColor: '#2B1B52', borderRadius: 20, marginTop: 22, padding: 20 },
  intentionLabel: { color: '#AA90D1', fontSize: 11, fontWeight: '700', letterSpacing: 1.2 },
  intention: { color: '#F9E8DA', fontSize: 18, fontStyle: 'italic', marginTop: 8 },
  pressed: { opacity: 0.82 },
});
