import React from 'react';
import { View, Text, FlatList, StyleSheet, Pressable } from 'react-native';
import { colors } from '../theme';

const ORDERS = [
  { id: '1001', status: 'PAID', total: 2800, date: '20/4/2026 · 11:25' },
  { id: '1002', status: 'PREPARING', total: 1650, date: '19/4/2026 · 19:10' },
  { id: '1003', status: 'COMPLETED', total: 920, date: '18/4/2026 · 13:40' },
];

export default function OrdersScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Orders</Text>

      <FlatList
        data={ORDERS}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <Pressable style={styles.card}>
            <View style={styles.row}>
              <Text style={styles.orderNo}>#{item.id}</Text>
              <Text style={styles.status}>{item.status}</Text>
            </View>
            <Text style={styles.total}>LKR {item.total.toFixed(2)}</Text>
            <Text style={styles.date}>{item.date}</Text>
          </Pressable>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  title: { fontSize: 24, fontWeight: '800', color: colors.ink, padding: 16 },
  list: { paddingHorizontal: 16, gap: 10 },
  card: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 12,
    padding: 14,
  },
  row: { flexDirection: 'row', justifyContent: 'space-between' },
  orderNo: { fontWeight: '700', color: colors.ink },
  status: { color: '#2563EB', fontWeight: '700', fontSize: 12 },
  total: { marginTop: 8, fontSize: 18, fontWeight: '800', color: colors.ink },
  date: { marginTop: 6, color: colors.muted, fontSize: 12 },
});
