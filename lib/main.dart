
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AtmosIQApp());
}

class AtmosIQApp extends StatelessWidget {
  const AtmosIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2878C8);

    return MaterialApp(
      title: 'AtmosIQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F8FC),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const WeatherPage(),
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  static const Color primary = Color(0xFF2878C8);
  static const String weatherCacheKey = 'atmosiq_weather_cache';
  static const String lastCityKey = 'atmosiq_last_city';
  static const String favoritesKey = 'atmosiq_favorite_cities';

  final TextEditingController searchController = TextEditingController();

  Map<String, dynamic>? current;
  Map<String, dynamic>? hourly;
  Map<String, dynamic>? daily;
  Map<String, dynamic>? airQuality;

  String city = 'New Delhi';
  String? errorMessage;
  String? infoMessage;
  DateTime? lastUpdated;

  List<String> favoriteCities = [];

  bool loading = true;
  bool refreshing = false;
  bool fahrenheit = false;
  bool locating = false;

  double? currentLatitude;
  double? currentLongitude;

  int requestNumber = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCity = prefs.getString(lastCityKey);
    final savedFavorites = prefs.getStringList(favoritesKey) ?? [];

    if (!mounted) return;

    setState(() {
      favoriteCities = savedFavorites;
      if (savedCity != null && savedCity.isNotEmpty) {
        city = savedCity;
      }
    });

    final cached = prefs.getString(weatherCacheKey);

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            current = Map<String, dynamic>.from(decoded['current'] as Map);
            hourly = Map<String, dynamic>.from(decoded['hourly'] as Map);
            daily = Map<String, dynamic>.from(decoded['daily'] as Map);

            final savedAir = decoded['air_quality'];
            airQuality = savedAir is Map
                ? Map<String, dynamic>.from(savedAir)
                : null;

            city = decoded['city'] as String? ?? city;
            currentLatitude = (decoded['latitude'] as num?)?.toDouble();
            currentLongitude = (decoded['longitude'] as num?)?.toDouble();

            final savedTime = decoded['saved_at'] as String?;
            lastUpdated = savedTime == null
                ? null
                : DateTime.tryParse(savedTime);

            loading = false;
          });
        }
      } catch (_) {
        // Ignore invalid or outdated cached data.
      }
    }

    if (city == 'My location' &&
        currentLatitude != null &&
        currentLongitude != null) {
      await _loadWeatherAtCoordinates(
        currentLatitude!,
        currentLongitude!,
        'My location',
      );
    } else {
      await loadWeather(city);
    }
  }

  Future<Map<String, dynamic>> _getCoordinates(String name) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': name,
        'count': '1',
        'language': 'en',
        'format': 'json',
      },
    );

    final response = await http.get(uri).timeout(
          const Duration(seconds: 12),
        );

    if (response.statusCode != 200) {
      throw Exception('Could not find that city. Please try again.');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) {
      throw Exception('City not found. Check the spelling and try again.');
    }

    final result = results.first as Map<String, dynamic>;

    return {
      'latitude': (result['latitude'] as num).toDouble(),
      'longitude': (result['longitude'] as num).toDouble(),
      'name': result['name'] as String? ?? name,
      'country': result['country'] as String? ?? '',
    };
  }

  Future<Map<String, dynamic>> _getWeather(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,'
                'is_day,precipitation,weather_code,wind_speed_10m,'
                'surface_pressure',
        'hourly':
            'temperature_2m,precipitation_probability,weather_code',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
                'sunrise,sunset,uv_index_max,'
                'precipitation_probability_max,wind_speed_10m_max',
        'forecast_days': '7',
        'timezone': 'auto',
      },
    );

    final response = await http.get(uri).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception('Weather service is temporarily unavailable.');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _getAirQuality(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.https(
        'air-quality-api.open-meteo.com',
        '/v1/air-quality',
        {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'current':
              'us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide',
          'timezone': 'auto',
        },
      );

      final response = await http.get(uri).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final value = decoded['current'];

      if (value is! Map<String, dynamic>) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadWeather(String name) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      setState(() {
        errorMessage = 'Enter a city name.';
      });
      return;
    }

    final thisRequest = ++requestNumber;

    setState(() {
      loading = current == null;
      refreshing = current != null;
      locating = false;
      errorMessage = null;
      infoMessage = null;
      airQuality = null;
    });

    try {
      final coordinates = await _getCoordinates(trimmedName);

      if (!mounted || thisRequest != requestNumber) return;

      final latitude = coordinates['latitude'] as double;
      final longitude = coordinates['longitude'] as double;
      final cityName = coordinates['name'] as String;
      final country = coordinates['country'] as String;

      final displayName = country.isEmpty
          ? cityName
          : '$cityName, $country';

      await _fetchAndApply(
        latitude,
        longitude,
        displayName,
        thisRequest,
      );
    } catch (e) {
      if (!mounted || thisRequest != requestNumber) return;

      setState(() {
        loading = false;
        refreshing = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadWeatherAtCoordinates(
    double latitude,
    double longitude,
    String label,
  ) async {
    final thisRequest = ++requestNumber;

    setState(() {
      loading = current == null;
      refreshing = current != null;
      locating = false;
      errorMessage = null;
      infoMessage = null;
      airQuality = null;
    });

    try {
      await _fetchAndApply(
        latitude,
        longitude,
        label,
        thisRequest,
      );
    } catch (e) {
      if (!mounted || thisRequest != requestNumber) return;

      setState(() {
        loading = false;
        refreshing = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _fetchAndApply(
    double latitude,
    double longitude,
    String label,
    int thisRequest,
  ) async {
    final weather = await _getWeather(latitude, longitude);

    if (!mounted || thisRequest != requestNumber) return;

    final newCurrent =
        Map<String, dynamic>.from(weather['current'] as Map);
    final newHourly =
        Map<String, dynamic>.from(weather['hourly'] as Map);
    final newDaily =
        Map<String, dynamic>.from(weather['daily'] as Map);

    final now = DateTime.now();

    setState(() {
      city = label;
      current = newCurrent;
      hourly = newHourly;
      daily = newDaily;
      airQuality = null;
      currentLatitude = latitude;
      currentLongitude = longitude;
      lastUpdated = now;
      loading = false;
      refreshing = false;
      errorMessage = null;
    });

    await _saveCache(
      label,
      newCurrent,
      newHourly,
      newDaily,
      null,
      latitude,
      longitude,
      now,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastCityKey, label);

    // Air quality is fetched separately so it cannot delay the weather display.
    unawaited(_refreshAirQuality(
      latitude,
      longitude,
      label,
      thisRequest,
    ));
  }

  Future<void> _refreshAirQuality(
    double latitude,
    double longitude,
    String label,
    int thisRequest,
  ) async {
    final result = await _getAirQuality(latitude, longitude);

    if (!mounted || thisRequest != requestNumber || city != label) return;

    if (result != null) {
      setState(() {
        airQuality = result;
      });

      await _saveCache(
        city,
        current!,
        hourly!,
        daily!,
        result,
        latitude,
        longitude,
        lastUpdated ?? DateTime.now(),
      );
    }
  }

  Future<void> _saveCache(
    String name,
    Map<String, dynamic> currentData,
    Map<String, dynamic> hourlyData,
    Map<String, dynamic> dailyData,
    Map<String, dynamic>? airData,
    double latitude,
    double longitude,
    DateTime time,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        weatherCacheKey,
        jsonEncode({
          'city': name,
          'current': currentData,
          'hourly': hourlyData,
          'daily': dailyData,
          'air_quality': airData,
          'latitude': latitude,
          'longitude': longitude,
          'saved_at': time.toIso8601String(),
        }),
      );
    } catch (_) {
      // Weather remains usable even if local caching fails.
    }
  }

  Future<void> _useCurrentLocation() async {
    if (locating) return;

    setState(() {
      locating = true;
      errorMessage = null;
      infoMessage = null;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location is turned off. Enable Location Services on your device.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. You can still search for a city.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is blocked. Enable it in your device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!mounted) return;

      await _loadWeatherAtCoordinates(
        position.latitude,
        position.longitude,
        'My location',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        locating = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final normalized = city.trim();

    if (normalized.isEmpty || normalized == 'My location') {
      setState(() {
        infoMessage = 'Search for a city to add it to your favorites.';
      });
      return;
    }

    final exists = favoriteCities.any(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );

    setState(() {
      if (exists) {
        favoriteCities.removeWhere(
          (item) => item.toLowerCase() == normalized.toLowerCase(),
        );
        infoMessage = '$normalized removed from favorites.';
      } else {
        favoriteCities.add(normalized);
        infoMessage = '$normalized added to favorites.';
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(favoritesKey, favoriteCities);
  }

  bool get isFavorite {
    return favoriteCities.any(
      (item) => item.toLowerCase() == city.toLowerCase(),
    );
  }

  double _number(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  String _temperature(dynamic value) {
    final celsius = _number(value);
    final result = fahrenheit ? (celsius * 9 / 5) + 32 : celsius;
    return '${result.round()}°';
  }

  String _condition(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Weather conditions';
  }

  IconData _weatherIcon(int code, {bool isDay = true}) {
    if (code == 0) {
      return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }
    if (code == 1 || code == 2) {
      return isDay ? Icons.cloud_queue_rounded : Icons.cloud_rounded;
    }
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain_rounded;
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.water_drop_rounded;
    if (code >= 85 && code <= 86) return Icons.ac_unit_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  String _hourLabel(String? value) {
    if (value == null) return '--';

    final date = DateTime.tryParse(value);
    if (date == null) return '--';

    final hour = date.hour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour $suffix';
  }

  String _dayLabel(String? value, int index) {
    if (value == null) return '--';
    final date = DateTime.tryParse(value);
    if (date == null) return '--';
    if (index == 0) return 'Today';
    if (index == 1) return 'Tomorrow';

    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];

    return weekdays[date.weekday - 1];
  }

  String get updatedLabel {
    if (lastUpdated == null) return 'Weather information';

    final difference = DateTime.now().difference(lastUpdated!);

    if (difference.inMinutes < 1) return 'Updated just now';
    if (difference.inMinutes < 60) {
      return 'Updated ${difference.inMinutes} min ago';
    }

    return 'Updated ${difference.inHours} hr ago';
  }

  List<Map<String, dynamic>> get advisories {
    if (current == null || daily == null) return [];

    final results = <Map<String, dynamic>>[];

    final temperature = _number(current!['temperature_2m']);
    final wind = _number(current!['wind_speed_10m']);

    final uvValues = daily!['uv_index_max'] as List<dynamic>? ?? [];
    final rainValues =
        daily!['precipitation_probability_max'] as List<dynamic>? ?? [];

    final uv = uvValues.isEmpty ? 0 : _number(uvValues.first);
    final rain = rainValues.isEmpty ? 0 : _number(rainValues.first);

    if (temperature >= 38) {
      results.add({
        'title': 'High temperature',
        'message': 'It may be very hot. Stay hydrated and take breaks in shade.',
        'icon': Icons.thermostat_rounded,
        'color': const Color(0xFFE58A35),
      });
    }

    if (wind >= 45) {
      results.add({
        'title': 'Strong winds',
        'message': 'Wind speeds may be high. Be cautious outdoors.',
        'icon': Icons.air_rounded,
        'color': const Color(0xFF537CC5),
      });
    }

    if (uv >= 8) {
      results.add({
        'title': 'High UV index',
        'message': 'UV levels may be high. Consider shade and sun protection.',
        'icon': Icons.wb_sunny_rounded,
        'color': const Color(0xFFE39A32),
      });
    }

    if (rain >= 70) {
      results.add({
        'title': 'High chance of rain',
        'message': 'Rain is likely in the forecast. Consider carrying an umbrella.',
        'icon': Icons.umbrella_rounded,
        'color': const Color(0xFF438BCB),
      });
    }

    return results;
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D2B3A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8492A2),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAF0F6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF233B55).withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.cloud_rounded,
            color: primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AtmosIQ',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D2B3A),
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                'Weather, made simple.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8290A0),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Use my location',
          onPressed: locating ? null : _useCurrentLocation,
          icon: locating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded),
          color: primary,
        ),
        IconButton(
          tooltip: 'Refresh weather',
          onPressed: refreshing || loading
              ? null
              : () {
                  if (city == 'My location' &&
                      currentLatitude != null &&
                      currentLongitude != null) {
                    _loadWeatherAtCoordinates(
                      currentLatitude!,
                      currentLongitude!,
                      city,
                    );
                  } else {
                    loadWeather(city);
                  }
                },
          icon: refreshing
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          color: primary,
        ),
        PopupMenuButton<bool>(
          tooltip: 'Temperature unit',
          initialValue: fahrenheit,
          onSelected: (value) => setState(() => fahrenheit = value),
          icon: const Icon(Icons.thermostat_rounded, color: primary),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: false,
              child: Text('Celsius (°C)'),
            ),
            PopupMenuItem(
              value: true,
              child: Text('Fahrenheit (°F)'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _searchBox() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE6EDF4)),
            ),
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                loadWeather(value);
                searchController.clear();
              },
              decoration: const InputDecoration(
                hintText: 'Search city...',
                hintStyle: TextStyle(color: Color(0xFF9AA7B5)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF8393A5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          height: 52,
          width: 54,
          child: FilledButton(
            onPressed: () {
              loadWeather(searchController.text);
              searchController.clear();
            },
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
      ],
    );
  }

  Widget _favorites() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Favorite cities',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF34465A),
              ),
            ),
            const Spacer(),
            Text(
              '${favoriteCities.length} saved',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9AA6B4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (favoriteCities.isEmpty)
          const Text(
            'Tap the heart on a city to save it here.',
            style: TextStyle(
              color: Color(0xFF929EAC),
              fontSize: 12,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: favoriteCities.map((favorite) {
                final selected =
                    favorite.toLowerCase() == city.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      Icons.location_city_rounded,
                      size: 15,
                      color: selected ? primary : const Color(0xFF7E8D9D),
                    ),
                    label: Text(favorite),
                    onPressed: () => loadWeather(favorite),
                    backgroundColor:
                        selected ? const Color(0xFFEAF3FD) : Colors.white,
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFBBD7F5)
                          : const Color(0xFFE6EDF4),
                    ),
                    labelStyle: TextStyle(
                      color: selected
                          ? primary
                          : const Color(0xFF536477),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _heroCard() {
    final temp = _number(current!['temperature_2m']);
    final code = _number(current!['weather_code']).round();
    final isDay = _number(current!['is_day'], 1) == 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2878C8), Color(0xFF55A0DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: _toggleFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _temperature(temp),
                      style: const TextStyle(
                        fontSize: 66,
                        height: 1,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: -3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _condition(code),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Feels like ${_temperature(current!['apparent_temperature'])}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _weatherIcon(code, isDay: isDay),
                size: 88,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                updatedLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (refreshing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    IconData icon,
    String label,
    String value,
    String detail,
  ) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEAF0F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 21),
          const SizedBox(height: 13),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8492A2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF25374A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(
              color: Color(0xFF9AA6B4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics() {
    final humidity = _number(current!['relative_humidity_2m']).round();
    final wind = _number(current!['wind_speed_10m']);
    final pressure = _number(current!['surface_pressure']).round();
    final rain = _number(current!['precipitation']);

    final uvValues = daily!['uv_index_max'] as List<dynamic>? ?? [];
    final uv = uvValues.isEmpty ? 0 : _number(uvValues.first);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metricCard(
          Icons.water_drop_outlined,
          'Humidity',
          '$humidity%',
          'Relative humidity',
        ),
        _metricCard(
          Icons.air_rounded,
          'Wind speed',
          '${wind.round()} km/h',
          'Current wind',
        ),
        _metricCard(
          Icons.speed_rounded,
          'Pressure',
          '$pressure hPa',
          'Surface pressure',
        ),
        _metricCard(
          Icons.grain_rounded,
          'Precipitation',
          '${rain.toStringAsFixed(1)} mm',
          'Current amount',
        ),
        _metricCard(
          Icons.wb_sunny_outlined,
          'UV index',
          uv.toStringAsFixed(1),
          'Daily maximum',
        ),
      ],
    );
  }

  String _aqiDescription(double aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Sensitive groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very unhealthy';
    return 'Hazardous';
  }

  Color _aqiColor(double aqi) {
    if (aqi <= 50) return const Color(0xFF269B68);
    if (aqi <= 100) return const Color(0xFFD3A12B);
    if (aqi <= 150) return const Color(0xFFE58A35);
    if (aqi <= 200) return const Color(0xFFD95C58);
    if (aqi <= 300) return const Color(0xFF8A65B5);
    return const Color(0xFF80505B);
  }

  Widget _airQualityCard() {
    if (airQuality == null) {
      return _panel(
        child: Row(
          children: [
            const Icon(
              Icons.air_rounded,
              color: primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Air quality',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Air-quality data is loading or unavailable.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8795A4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    final aqi = _number(airQuality!['us_aqi'], -1);
    final pm25 = _number(airQuality!['pm2_5'], -1);
    final pm10 = _number(airQuality!['pm10'], -1);
    final color = _aqiColor(aqi < 0 ? 0 : aqi);

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.air_rounded, color: primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Air quality',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF25374A),
                  ),
                ),
              ),
              Text(
                'US AQI',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  aqi < 0 ? '--' : aqi.round().toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aqi < 0 ? 'Unavailable' : _aqiDescription(aqi),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Model-based air-quality estimate',
                      style: TextStyle(
                        color: Color(0xFF8B98A6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _airValue(
                  'PM2.5',
                  pm25 < 0 ? '--' : '${pm25.toStringAsFixed(1)} µg/m³',
                ),
              ),
              Expanded(
                child: _airValue(
                  'PM10',
                  pm10 < 0 ? '--' : '${pm10.toStringAsFixed(1)} µg/m³',
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const Text(
            'Air-quality estimates may differ from readings at local monitoring stations.',
            style: TextStyle(
              color: Color(0xFF9AA6B4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _airValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B98A6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF34465A),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _advisoriesCard() {
    final items = advisories;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: primary,
                size: 21,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Weather advisories',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF25374A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: items.isEmpty
                      ? const Color(0xFFEAF5EF)
                      : const Color(0xFFFFF2E5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} notices',
                  style: TextStyle(
                    color: items.isEmpty
                        ? const Color(0xFF269B68)
                        : const Color(0xFFC47A27),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF269B68),
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No major weather advisories from the current forecast.',
                    style: TextStyle(
                      color: Color(0xFF718092),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          else
            ...items.map((item) {
              final color = item['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: color,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              color: Color(0xFF34465A),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['message'] as String,
                            style: const TextStyle(
                              color: Color(0xFF8492A2),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 3),
          const Text(
            'These are app-generated advisories based on forecast thresholds, not official government alerts.',
            style: TextStyle(
              color: Color(0xFF9AA6B4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hourlyForecast() {
    final times = hourly!['time'] as List<dynamic>? ?? [];
    final temperatures =
        hourly!['temperature_2m'] as List<dynamic>? ?? [];
    final codes = hourly!['weather_code'] as List<dynamic>? ?? [];
    final probabilities =
        hourly!['precipitation_probability'] as List<dynamic>? ?? [];

    final now = DateTime.now();
    var startIndex = times.indexWhere((value) {
      final parsed = DateTime.tryParse(value.toString());
      return parsed != null && !parsed.isBefore(now);
    });

    if (startIndex < 0) startIndex = 0;

    final endIndex = (startIndex + 12).clamp(0, times.length);

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Hourly forecast',
            subtitle: 'The next 12 hours',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                endIndex - startIndex,
                (offset) {
                  final index = startIndex + offset;
                  final code = _number(codes[index]).round();
                  final probability = index < probabilities.length
                      ? _number(probabilities[index]).round()
                      : 0;

                  return Container(
                    width: 69,
                    margin: const EdgeInsets.only(right: 9),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 7,
                    ),
                    decoration: BoxDecoration(
                      color: index == startIndex
                          ? const Color(0xFFEAF3FD)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _hourLabel(times[index].toString()),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF7F8D9C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Icon(
                          _weatherIcon(code),
                          color: primary,
                          size: 23,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _temperature(temperatures[index]),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2B3B4E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          Icons.water_drop_outlined,
                          color: const Color(0xFF5299D3),
                          size: 12,
                        ),
                        Text(
                          '$probability%',
                          style: const TextStyle(
                            color: Color(0xFF8292A3),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyForecast() {
    final times = daily!['time'] as List<dynamic>? ?? [];
    final codes = daily!['weather_code'] as List<dynamic>? ?? [];
    final maximum =
        daily!['temperature_2m_max'] as List<dynamic>? ?? [];
    final minimum =
        daily!['temperature_2m_min'] as List<dynamic>? ?? [];
    final rain =
        daily!['precipitation_probability_max'] as List<dynamic>? ?? [];

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            '7-day forecast',
            subtitle: 'A look at the week ahead',
          ),
          ...List.generate(times.length, (index) {
            final code = _number(codes[index]).round();
            final rainChance =
                index < rain.length ? _number(rain[index]).round() : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      _dayLabel(times[index].toString(), index),
                      style: const TextStyle(
                        color: Color(0xFF506174),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _weatherIcon(code),
                    size: 21,
                    color: primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _condition(code),
                      style: const TextStyle(
                        color: Color(0xFF8A98A7),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (rainChance > 0) ...[
                    const Icon(
                      Icons.water_drop_outlined,
                      size: 12,
                      color: Color(0xFF579BD1),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$rainChance%',
                      style: const TextStyle(
                        color: Color(0xFF8292A3),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    _temperature(maximum[index]),
                    style: const TextStyle(
                      color: Color(0xFF34465A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _temperature(minimum[index]),
                    style: const TextStyle(
                      color: Color(0xFF9AA6B4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF6D5D0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFC65C50),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFF9E4F47),
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => errorMessage = null),
            icon: const Icon(Icons.close, size: 17),
            color: const Color(0xFF9E4F47),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    if (infoMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FD),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              infoMessage!,
              style: const TextStyle(
                color: Color(0xFF376D9E),
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => infoMessage = null),
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            color: primary,
          ),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return SizedBox(
      width: double.infinity,
      child: _panel(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: const Column(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: primary,
              ),
            ),
            SizedBox(height: 17),
            Text(
              'Getting your weather...',
              style: TextStyle(
                color: Color(0xFF40546A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'This usually takes a few seconds.',
              style: TextStyle(
                color: Color(0xFF98A4B1),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherContent(bool wide) {
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(),
        const SizedBox(height: 17),
        _sectionTitle('Weather details'),
        _metrics(),
        const SizedBox(height: 17),
        _sectionTitle('Air quality'),
        _airQualityCard(),
        const SizedBox(height: 17),
        _sectionTitle('Weather advisories'),
        _advisoriesCard(),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hourlyForecast(),
        const SizedBox(height: 17),
        _dailyForecast(),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: leftColumn),
          const SizedBox(width: 18),
          Expanded(flex: 5, child: rightColumn),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leftColumn,
        const SizedBox(height: 17),
        rightColumn,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 26 : 16,
                    vertical: 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 22),
                      _searchBox(),
                      const SizedBox(height: 17),
                      _favorites(),
                      const SizedBox(height: 17),
                      _errorBanner(),
                      _infoBanner(),
                      if (loading && current == null) ...[
                        _loadingView(),
                      ] else if (current != null &&
                          hourly != null &&
                          daily != null) ...[
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: KeyedSubtree(
                            key: ValueKey(city),
                            child: _weatherContent(wide),
                          ),
                        ),
                      ] else if (errorMessage != null) ...[
                        _panel(
                          child: const Text(
                            'Weather could not be loaded. Check your connection or search for another city.',
                            style: TextStyle(
                              color: Color(0xFF718092),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 25),
                      const Center(
                        child: Text(
                          'Weather data by Open-Meteo  •  AtmosIQ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFA1ACB8),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
