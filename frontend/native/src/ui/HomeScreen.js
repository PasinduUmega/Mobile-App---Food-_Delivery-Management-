/** Parallels `lib/ui/home_screen.dart` / store browse (loads live `/api/stores`). */
import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
  Switch,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { colors } from '../theme';
import { api } from '../services/api';

export default function HomeScreen({ navigation, isDarkMode, onThemeChanged }) {
  const [stores, setStores] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      await api.health();
      const data = await api.listStores();
      setStores(Array.isArray(data?.items) ? data.items : []);
    } catch (e) {
      setError(e?.message ?? String(e));
      setStores([]);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const onRefresh = () => {
    setRefreshing(true);
    load();
  };

  const headerBg = isDarkMode ? '#1E1E1E' : '#FFFFFF';
  const cardBg = isDarkMode ? '#2A2A2A' : '#FFFFFF';

  return (
    <View style={[styles.container, isDarkMode && styles.containerDark]}>
      <View style={[styles.header, { backgroundColor: headerBg }]}>
        <Text style={[styles.title, isDarkMode && styles.textDark]}>Stores</Text>
        <View style={styles.themeRow}>
          <Text style={styles.themeText}>Dark</Text>
          <Switch value={isDarkMode} onValueChange={onThemeChanged} />
        </View>
      </View>

      {loading && (
        <View style={styles.center}>
          <ActivityIndicator size="large" color={colors.primary} />
        </View>
      )}

      {!loading && error && (
        <View style={styles.banner}>
          <Text style={styles.bannerText}>{error}</Text>
          <Text style={styles.bannerHint}>Check backend and native/src/config.js.</Text>
        </View>
      )}

      {!loading && (
        <FlatList
          data={stores}
          keyExtractor={(item) => String(item.id)}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <Pressable
              style={[styles.card, { backgroundColor: cardBg }]}
              onPress={() => navigation.navigate('Cart')}
            >
              <Text style={[styles.cardTitle, isDarkMode && styles.textDark]}>{item.name}</Text>
              {item.address ? (
                <Text style={styles.cardMeta}>{item.address}</Text>
              ) : null}
            </Pressable>
          )}
          ListEmptyComponent={
            !error ? (
              <Text style={styles.empty}>No stores yet. Seed via admin or POST /api/stores.</Text>
            ) : null
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  containerDark: { backgroundColor: '#121212' },
  header: {
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: colors.line,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: { fontSize: 24, fontWeight: '800', color: colors.ink },
  textDark: { color: '#F5F5F5' },
  themeRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  themeText: { color: colors.muted, fontWeight: '600' },
  center: { padding: 24, alignItems: 'center' },
  banner: { margin: 16, padding: 12, borderRadius: 10, backgroundColor: '#FEF2F2' },
  bannerText: { color: '#991B1B', fontWeight: '700' },
  bannerHint: { marginTop: 6, color: '#7F1D1D', fontSize: 13 },
  list: { padding: 16, gap: 12, flexGrow: 1 },
  card: {
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.line,
    padding: 14,
  },
  cardTitle: { fontSize: 16, fontWeight: '700', color: colors.ink },
  cardMeta: { marginTop: 6, color: colors.muted },
  empty: { textAlign: 'center', marginTop: 24, color: colors.muted, paddingHorizontal: 16 },
});
