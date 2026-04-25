import React, { useMemo, useState } from 'react';
import { View, Text, FlatList, Pressable, StyleSheet } from 'react-native';
import { colors } from '../theme';

const INITIAL_ITEMS = [
  { id: '1', name: 'Chicken Burger', qty: 1, unitPrice: 1200 },
  { id: '2', name: 'Fries', qty: 2, unitPrice: 500 },
];

export default function CartScreen() {
  const [items, setItems] = useState(INITIAL_ITEMS);

  const subtotal = useMemo(
    () => items.reduce((sum, it) => sum + it.qty * it.unitPrice, 0),
    [items]
  );

  const updateQty = (id, delta) => {
    setItems((prev) =>
      prev
        .map((it) => (it.id === id ? { ...it, qty: it.qty + delta } : it))
        .filter((it) => it.qty > 0)
    );
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>My Cart</Text>

      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <View style={{ flex: 1 }}>
              <Text style={styles.itemName}>{item.name}</Text>
              <Text style={styles.itemPrice}>LKR {item.unitPrice.toFixed(2)}</Text>
            </View>
            <View style={styles.qtyRow}>
              <Pressable onPress={() => updateQty(item.id, -1)} style={styles.qtyBtn}>
                <Text style={styles.qtyBtnText}>-</Text>
              </Pressable>
              <Text style={styles.qty}>{item.qty}</Text>
              <Pressable onPress={() => updateQty(item.id, 1)} style={styles.qtyBtn}>
                <Text style={styles.qtyBtnText}>+</Text>
              </Pressable>
            </View>
          </View>
        )}
      />

      <View style={styles.bottom}>
        <View style={styles.totalRow}>
          <Text style={styles.totalLabel}>Total</Text>
          <Text style={styles.totalValue}>LKR {subtotal.toFixed(2)}</Text>
        </View>
        <Pressable style={styles.checkoutBtn}>
          <Text style={styles.checkoutText}>Checkout Now</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  title: { fontSize: 24, fontWeight: '800', color: colors.ink, padding: 16 },
  list: { paddingHorizontal: 16, gap: 10, paddingBottom: 140 },
  card: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 12,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
  },
  itemName: { fontSize: 16, fontWeight: '700', color: colors.ink },
  itemPrice: { marginTop: 4, color: '#FF6A00', fontWeight: '600' },
  qtyRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  qtyBtn: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: '#F2F2F2',
    alignItems: 'center',
    justifyContent: 'center',
  },
  qtyBtnText: { fontSize: 18, fontWeight: '700' },
  qty: { minWidth: 20, textAlign: 'center', fontWeight: '700', color: colors.ink },
  bottom: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: '#FFFFFF',
    borderTopWidth: 1,
    borderTopColor: colors.line,
    padding: 16,
  },
  totalRow: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 12 },
  totalLabel: { color: colors.muted, fontSize: 16 },
  totalValue: { fontSize: 20, fontWeight: '800', color: colors.ink },
  checkoutBtn: {
    backgroundColor: '#FF6A00',
    borderRadius: 10,
    alignItems: 'center',
    paddingVertical: 14,
  },
  checkoutText: { color: '#FFFFFF', fontWeight: '700', fontSize: 16 },
});
