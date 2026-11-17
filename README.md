# 🌤️ AtmosIQ — Weather Intelligence

**A responsive, real-time weather application built with Flutter.**

AtmosIQ provides weather information through a clean, modern interface, including current conditions, hourly forecasts, weekly predictions, air-quality information and location-based weather updates.

🌐 **Live Demo:** [https://atmosiq-weather.netlify.app/](https://atmosiq-weather.netlify.app/)

📦 **GitHub Repository:** [https://github.com/teja23-saviour/AtmosIQ](https://github.com/teja23-saviour/AtmosIQ)

---

## ✨ Features

- 🌍 **Global City Search** — Search for cities around the world.
- 📍 **Automatic Location Detection** — Get weather information for your current location.
- 🌡️ **Live Weather Information** — Temperature, feels-like temperature and weather conditions.
- ❤️ **Favorite Cities** — Save and quickly access frequently searched cities.
- 🌧️ **Hourly Forecast** — View upcoming weather conditions.
- 📅 **Seven-Day Forecast** — Explore the weekly weather outlook.
- 🌬️ **Air Quality Information** — View AQI, PM2.5 and PM10 information.
- ⚠️ **Weather Advisories** — Application-generated weather notifications based on forecast conditions.
- 💧 **Weather Metrics** — Humidity, wind speed, pressure, precipitation and UV index.
- 🌡️ **Temperature Conversion** — Switch between Celsius and Fahrenheit.
- 📱 **Responsive Interface** — Designed for desktop, tablet and mobile screens.
- ⚡ **Loading and Error Handling** — User-friendly loading, refresh and error states.
- 🎨 **Modern UI** — Clean, light-themed interface with weather icons and subtle animations.
- 💾 **Local Preferences** — Save favorite cities and application data using SharedPreferences.

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform UI development |
| Dart | Application programming language |
| Open-Meteo API | Weather forecast data |
| Open-Meteo Geocoding API | City search and coordinates |
| Open-Meteo Air Quality API | Air quality information |
| Geolocator | Device location detection |
| SharedPreferences | Local data persistence |
| HTTP | API communication |
| Netlify | Web application hosting |
| Git & GitHub | Version control and source management |

## 🌐 APIs Used

AtmosIQ uses free Open-Meteo services.

- **Geocoding API:** https://geocoding-api.open-meteo.com/
- **Weather Forecast API:** https://api.open-meteo.com/
- **Air Quality API:** https://air-quality-api.open-meteo.com/

No API key is required for the standard Open-Meteo endpoints used by this project.

*Note: Air-quality values and weather advisories are informational estimates and should not be treated as official emergency alerts.*

## 📋 Requirements

- Flutter SDK (stable channel)
- Dart SDK compatible with the project
- Android SDK (for Android development)
- Chrome (for local web testing)
- Git
- Internet connection

## 🚀 Installation and Setup

### 1. Clone the repository

```bash
git clone https://github.com/teja23-saviour/AtmosIQ.git
```

### 2. Navigate to the project

```bash
cd AtmosIQ
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run on Chrome

```bash
flutter run -d chrome
```

### 5. Run on Android

Connect an Android device with USB debugging enabled.

```bash
flutter devices
flutter run
```

## 📦 Build Instructions

### Build Android APK

```bash
flutter build apk --release
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Build Flutter Web

```bash
flutter build web --release
```

Web output:

```text
build/web/
```

## ☁️ Netlify Deployment

AtmosIQ is deployed using Netlify.

**Live application:** https://atmosiq-weather.netlify.app/

The project uses `netlify.toml` to configure deployment.

| Configuration | Value |
|---|---|
| Build command | `bash scripts/netlify_build.sh` |
| Publish directory | `build/web` |
| Deployment branch | `main` |
| Hosting platform | Netlify |

The build script downloads the Flutter stable SDK in the Netlify Linux environment, configures Flutter for web, installs project dependencies and generates the production web build.

### Deployment workflow

1. Push project changes to GitHub.
2. Netlify detects the repository update.
3. Netlify executes the Flutter build script.
4. The generated web application is published.
5. The updated website becomes available through the live URL.

## 📂 Project Structure

```text
AtmosIQ/
│
├── android/
│   └── app/
│
├── lib/
│   └── main.dart
│
├── web/
│   ├── index.html
│   └── manifest.json
│
├── scripts/
│   └── netlify_build.sh
│
├── test/
│   └── widget_test.dart
│
├── netlify.toml
├── pubspec.yaml
├── pubspec.lock
├── .gitignore
└── README.md
```

## 🧪 Suggested Project Demonstration

1. Launch AtmosIQ and display the current weather.
2. Search for cities such as Tokyo, London or New Delhi.
3. Demonstrate automatic location detection.
4. Add a city to favorites and access it again.
5. Switch between Celsius and Fahrenheit.
6. Explore hourly and seven-day forecasts.
7. Demonstrate air-quality information and weather advisories.
8. Resize the browser to demonstrate responsive layouts.
9. Open the live Netlify deployment.

## 🔮 Future Improvements

- Interactive weather maps.
- Historical weather analysis.
- Weather notifications.
- Extended forecast information.
- Improved weather visualizations.
- Additional accessibility improvements.

## 👨‍💻 Author

**Teja Rayavarapu**

- GitHub: [@teja23-saviour](https://github.com/teja23-saviour)
- Project: [AtmosIQ](https://github.com/teja23-saviour/AtmosIQ)
- Live Demo: [AtmosIQ Weather](https://atmosiq-weather.netlify.app/)

---

⭐ If you find this project interesting, consider giving the repository a star!

**Built with Flutter and powered by Open-Meteo.**