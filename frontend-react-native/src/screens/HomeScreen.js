import React from 'react';
import { View, Text, FlatList, Pressable, StyleSheet, Switch } from 'react-native';
import { colors } from '../theme';

const MOCK_RESTAURANTS = [
  { id: '1', name: 'Spice Hub', eta: '20-30 min' },
  { id: '2', name: 'Burger Barn', eta: '15-25 min' },
  { id: '3', name: 'Green Bowl', eta: '25-35 min' },
];

export default function HomeScreen({ navigation, isDarkMode, onThemeChanged }) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Home</Text>
        <View style={styles.themeRow}>
          <Text style={styles.themeText}>Dark</Text>
          <Switch value={isDarkMode} onValueChange={onThemeChanged} />
        </View>
      </View>

      <FlatList
        data={MOCK_RESTAURANTS}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <Pressable style={styles.card} onPress={() => navigation.navigate('Cart')}>
            <Text style={styles.cardTitle}>{item.name}</Text>
            <Text style={styles.cardMeta}>{item.eta}</Text>
          </Pressable>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  header: {
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: colors.line,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: { fontSize: 24, fontWeight: '800', color: colors.ink },
  themeRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  themeText: { color: colors.muted, fontWeight: '600' },
  list: { padding: 16, gap: 12 },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.line,
    padding: 14,
  },
  cardTitle: { fontSize: 16, fontWeight: '700', color: colors.ink },
  cardMeta: { marginTop: 6, color: colors.muted },
});
