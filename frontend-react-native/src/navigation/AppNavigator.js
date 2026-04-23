import React, { useState } from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Text } from 'react-native';
import AuthScreen from '../screens/AuthScreen';
import HomeScreen from '../screens/HomeScreen';
import CartScreen from '../screens/CartScreen';
import OrdersScreen from '../screens/OrdersScreen';
import { colors } from '../theme';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

function MainTabs({ onThemeChanged, isDarkMode }) {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.ink,
        tabBarInactiveTintColor: '#6B7280',
        tabBarStyle: { backgroundColor: '#FFFFFF' },
      }}
    >
      <Tab.Screen
        name="Home"
        options={{ tabBarIcon: () => <Text>🏠</Text> }}
      >
        {(props) => (
          <HomeScreen
            {...props}
            isDarkMode={isDarkMode}
            onThemeChanged={onThemeChanged}
          />
        )}
      </Tab.Screen>
      <Tab.Screen
        name="Cart"
        component={CartScreen}
        options={{ tabBarIcon: () => <Text>🛒</Text> }}
      />
      <Tab.Screen
        name="Orders"
        component={OrdersScreen}
        options={{ tabBarIcon: () => <Text>📦</Text> }}
      />
    </Tab.Navigator>
  );
}

export default function AppNavigator({ isDarkMode, onThemeChanged }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      {!isAuthenticated ? (
        <Stack.Screen name="Auth">
          {(props) => <AuthScreen {...props} onLoggedIn={() => setIsAuthenticated(true)} />}
        </Stack.Screen>
      ) : (
        <Stack.Screen name="Main">
          {(props) => (
            <MainTabs
              {...props}
              isDarkMode={isDarkMode}
              onThemeChanged={onThemeChanged}
            />
          )}
        </Stack.Screen>
      )}
    </Stack.Navigator>
  );
}
