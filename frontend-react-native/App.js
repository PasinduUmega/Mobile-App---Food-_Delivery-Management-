import 'react-native-gesture-handler';
import React, { useMemo, useState } from 'react';
import { StatusBar, useColorScheme } from 'react-native';
import { NavigationContainer, DefaultTheme, DarkTheme } from '@react-navigation/native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import AppNavigator from './src/navigation/AppNavigator';
import { colors } from './src/theme';

export default function App() {
  const systemDark = useColorScheme() === 'dark';
  const [isDarkMode, setIsDarkMode] = useState(systemDark);

  const navTheme = useMemo(() => {
    const base = isDarkMode ? DarkTheme : DefaultTheme;
    return {
      ...base,
      colors: {
        ...base.colors,
        primary: colors.primary,
        background: isDarkMode ? '#121212' : colors.background,
        card: isDarkMode ? '#1E1E1E' : '#FFFFFF',
        text: isDarkMode ? '#F5F5F5' : colors.ink,
        border: isDarkMode ? '#2E2E2E' : '#E8E8E8',
      },
    };
  }, [isDarkMode]);

  return (
    <SafeAreaProvider>
      <NavigationContainer theme={navTheme}>
        <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
        <AppNavigator isDarkMode={isDarkMode} onThemeChanged={setIsDarkMode} />
      </NavigationContainer>
    </SafeAreaProvider>
  );
}
