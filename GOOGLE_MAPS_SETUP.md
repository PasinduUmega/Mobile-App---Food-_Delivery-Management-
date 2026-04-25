# Google Maps API Setup Guide

The map features in the app require a valid Google Maps API key. Follow these steps to set it up:

## Quick Fix Checklist

- [ ] Google Maps API key obtained from Google Cloud Console
- [ ] API key added to `android/app/src/main/AndroidManifest.xml`
- [ ] Google Maps Android API enabled in Cloud Console
- [ ] SHA-1 fingerprint added to API key restrictions (optional but recommended)
- [ ] App rebuilt with `flutter clean && flutter pub get && flutter run`

## Step 1: Get Your API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. **Enable APIs:**
   - Search for "Google Maps Android API"
   - Click and enable it
   - Search for "Maps SDK for Android"
   - Click and enable it
4. Go to **Credentials** → **Create Credentials** → **API Key**
   - Choose **Android**
   - Name it something like "Food Delivery Maps"
5. Copy your API key

## Step 2: Get Your SHA-1 Certificate Fingerprint

Run this command in PowerShell:

```powershell
Get-ChildItem -Path "$ENV:APPDATA\.android\debug.keystore" | ForEach-Object {
  & 'C:\Program Files\Android\Android Studio\jre\bin\keytool.exe' `
    -list -v -keystore $_.FullName -alias androiddebugkey -storepass android -keypass android
}
```

Look for the line that says `SHA1:` - copy the entire fingerprint (without "SHA1:" prefix).

Example: `D3:4C:8E:D8:...` (all the hex characters)

## Step 3: Restrict Your API Key (Recommended)

1. In Google Cloud Console, go to **Credentials** → find your API key
2. Click the API key to open its details
3. Under **Application restrictions**, select **Android apps**
4. Click **Add an Android app restriction**
5. Add two entries:
   - **Package name:** `com.example.food_delivery`
   - **SHA-1 Fingerprint:** (from Step 2)

## Step 4: Add the API Key to Your App

Open `android/app/src/main/AndroidManifest.xml` and replace this:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE" />
```

With your actual key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyD..." />
```

## Step 5: Rebuild & Test

```bash
flutter clean
flutter pub get
flutter run
```

## Debugging: Why Map is Showing Errors

### Check the logs while running:

```bash
flutter run -v
```

**Look for these error messages:**

| Error | Cause | Solution |
|-------|-------|----------|
| `Authorization failure` | API key not set or invalid | Verify API key in AndroidManifest.xml |
| `API Key: YOUR_API_KEY_HERE` | Placeholder key still in use | Update AndroidManifest.xml with real key |
| `Cannot enable MyLocation layer` | Location permissions not granted | App will ask on first load |
| `"Map failed to load"` | Google Maps API not enabled | Enable in Cloud Console |

### Debugging Steps:

1. **Check if API key is set:**
   ```bash
   grep "com.google.android.geo.API_KEY" android/app/src/main/AndroidManifest.xml
   ```
   Should NOT show `YOUR_API_KEY_HERE`

2. **Verify APIs are enabled in Cloud Console:**
   - Go to Cloud Console → APIs & Services → Enabled APIs
   - Should see both "Google Maps Android API" and "Maps SDK for Android"

3. **Check SHA-1 restriction matches:**
   - Run keytool command again (Step 2)
   - Compare with what's in Cloud Console

4. **Look for debug logs in app:**
   - When viewing a tracking map, check VS Code output panel
   - Look for lines starting with `🗺️` or `📍` for debug info
   - Look for `❌` for error messages

### Common Issues:

**Issue:** "Map shows blank white screen"
- **Fix:** Wait 5-10 minutes for API propagation after enabling in Cloud Console
- **Or:** Try using a different WiFi or mobile data (sometimes cached DNS)

**Issue:** "Markers don't show up"
- **Cause:** Delivery/order has no location data yet
- **Fix:** Assign driver and ensure driver location is being tracked
- **Check:** Look for `📍 Delivery location` or `📍 Driver location` in logs

**Issue:** "Delete Order button is disabled"
- **Cause:** Order status is PAID, COMPLETED, PREPARING, or READY
- **Fix:** Only PENDING_PAYMENT, CANCELLED, or FAILED orders can be deleted
- **Hover:** Over the delete button to see status tooltip

**Issue:** "Tracking map won't refresh"
- **Cause:** API query failing or no delivery assigned
- **Fix:** Tap refresh button to retry
- **Check:** Logs for `Tracking load error` messages

## References

- [Google Maps Android SDK Documentation](https://developers.google.com/maps/documentation/android-sdk/start)
- [API Key Documentation](https://developers.google.com/maps/documentation/maps-static/get-api-key)
- [Android SHA-1 Fingerprint Guide](https://developers.google.com/android/guides/client-auth)

## Still Having Issues?

1. Check `flutter run -v` output for error messages
2. Look at app logs for `❌` error indicators
3. Verify API key in Cloud Console → Credentials (look for restriction warnings)
4. Check that you're using a real device or emulator with Google Play Services
5. Try Android emulator with "Google APIs" image instead of basic emulator
