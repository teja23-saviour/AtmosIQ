# AtmosIQ — Weather Intelligence

Responsive Flutter weather dashboard for Android and Web. Uses the free Open-Meteo Geocoding and Forecast APIs; no API key is required.

## Features
- Search cities worldwide
- Live temperature, feels-like temperature and weather condition
- Humidity, wind speed, surface pressure and precipitation
- Hourly outlook (up to 24 hours)
- Seven-day forecast and daily UV index
- Celsius/Fahrenheit toggle
- Responsive desktop, tablet and phone layouts
- Loading and error states
- Dark weather dashboard UI

## Requirements
Flutter stable, Dart 3.4+, Android SDK for Android builds, Chrome for web testing, and internet access.

## Setup and run
This source bundle includes the Flutter application and web configuration. Generate the standard Android/Web platform folders on your Windows machine:

```powershell
flutter create --platforms=android,web .
flutter pub get
flutter run -d chrome
```

For Android:
```powershell
flutter devices
flutter run -d <android-device-id>
```

Build Android APK:
```powershell
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

Build web locally:
```powershell
flutter build web --release
```
Output: `build/web`

## Netlify deployment
The included `netlify.toml` configures:
- Build command: `bash scripts/netlify_build.sh`
- Publish directory: `build/web`

Recommended deployment:
1. Push this project to GitHub.
2. In Netlify, choose **Add new project → Import an existing project**.
3. Select the GitHub repository.
4. Confirm the build command and publish directory from `netlify.toml`.
5. Deploy and review the build log.

The build script downloads the Flutter stable SDK in Netlify's Linux build environment, enables web, installs dependencies, and builds the release website. The first build can take several minutes. Netlify hosts the web version; Android APKs are built separately.

## APIs
- Geocoding: https://geocoding-api.open-meteo.com/
- Weather forecast: https://api.open-meteo.com/

Weather conditions are mapped from Open-Meteo/WMO weather codes.

## Suggested lab demonstration
1. Show the current weather for the default city.
2. Search for another city, such as Tokyo or London.
3. Toggle Celsius/Fahrenheit.
4. Explain the weather metrics.
5. Scroll through hourly and seven-day forecasts.
6. Open the Netlify URL and show the responsive website.

## Project structure
```text
AtmosIQ/
├── lib/main.dart
├── web/index.html
├── web/manifest.json
├── scripts/netlify_build.sh
├── netlify.toml
├── pubspec.yaml
└── README.md
```
