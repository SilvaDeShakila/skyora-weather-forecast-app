import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_model.dart';
import '../services/weather_service.dart';

const Color _background = Color(0xFF07111F);
const Color _surface = Color(0xFF101E30);
const Color _blue = Color(0xFF55B8FF);
const Color _purple = Color(0xFF8B7CFF);
const Color _muted = Color(0xFF91A5BD);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _searchController =
      TextEditingController();

  WeatherData? _weather;
  bool _loading = false;
  String? _error;
  String _selectedCity = 'Colombo';
  List<String> _favorites = [];
  List<String> _recentCities = [];
  int _selectedTab = 0;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedCities();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchWeather('Colombo');
    });
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted && !_loading && _weather != null) {
        _fetchWeather(_selectedCity);
      }
    });
  }

  Future<void> _loadSavedCities() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favorites = prefs.getStringList('weather_favorites') ?? [];
      _recentCities = prefs.getStringList('weather_recent') ?? [];
    });
  }

  Future<void> _saveCities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('weather_favorites', _favorites);
    await prefs.setStringList('weather_recent', _recentCities);
  }

  Future<void> _fetchWeather(String city) async {
    final query = city.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a city name to search.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _selectedCity = query;
    });

    try {
      final result = await _weatherService.fetchWeather(query);
      if (!mounted) return;

      final updatedRecent = [
        result.cityName,
        ..._recentCities.where(
          (item) => item.toLowerCase() != result.cityName.toLowerCase(),
        ),
      ].take(6).toList();

      setState(() {
        _weather = result;
        _selectedCity = result.cityName;
        _recentCities = updatedRecent;
        _loading = false;
      });
      _searchController.clear();
      await _saveCities();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final city = _weather?.cityName;
    if (city == null) return;

    setState(() {
      final existing = _favorites.indexWhere(
        (item) => item.toLowerCase() == city.toLowerCase(),
      );
      if (existing >= 0) {
        _favorites.removeAt(existing);
      } else {
        _favorites.add(city);
      }
    });
    await _saveCities();
  }

  bool get _isFavorite => _weather != null &&
      _favorites.any(
        (city) => city.toLowerCase() == _weather!.cityName.toLowerCase(),
      );

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          backgroundColor: _surface,
          onRefresh: () => _fetchWeather(_selectedCity),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSearch()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _blue),
                        SizedBox(height: 18),
                        Text('Fetching the latest weather...',
                            style: TextStyle(color: _muted)),
                      ],
                    ),
                  ),
                )
              else if (_error != null && _weather == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildError(),
                )
              else if (_weather != null) ...[
                SliverToBoxAdapter(child: _buildWeatherHero(_weather!)),
                SliverToBoxAdapter(child: _buildHighlights(_weather!)),
                SliverToBoxAdapter(child: _buildHourly(_weather!)),
                SliverToBoxAdapter(child: _buildForecast(_weather!)),
                SliverToBoxAdapter(child: _buildSunTimes(_weather!)),
                SliverToBoxAdapter(child: _buildSavedCities()),
                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.orangeAccent)),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ] else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmpty(),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _surface,
        indicatorColor: _blue.withValues(alpha: 0.16),
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
          if (index == 1) {
            _showFavorites();
          } else if (index == 2) {
            _showRecent();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud, color: _blue),
            label: 'Weather',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite, color: _blue),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history, color: _blue),
            label: 'Recent',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/skyora_logo.png',
              height: 46,
              width: 46,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Skyora',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6)),
                Text('YOUR PERSONAL WEATHER',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh weather',
            onPressed: _loading ? null : () => _fetchWeather(_selectedCity),
            icon: const Icon(Icons.refresh_rounded, color: _blue),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: _fetchWeather,
          decoration: InputDecoration(
            hintText: 'Search city (e.g. Colombo)',
            hintStyle: const TextStyle(color: _muted, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: _blue),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: () => _fetchWeather(_searchController.text),
              icon: const Icon(Icons.arrow_forward_rounded, color: _blue),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 17),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherHero(WeatherData w) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17395B), Color(0xFF18223F), _surface],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _blue.withValues(alpha: 0.19)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 17, color: _blue),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${w.cityName}${w.region.isNotEmpty ? ', ${w.region}' : ''}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _toggleFavorite,
                  tooltip: _isFavorite ? 'Remove favorite' : 'Add favorite',
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.pinkAccent : _muted,
                  ),
                ),
              ],
            ),
            Text(w.country,
                style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${w.temperature.round()}°',
                          style: const TextStyle(
                              fontSize: 76,
                              height: 1.0,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -4)),
                      const SizedBox(height: 8),
                      Text(w.condition,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      Text(
                        'Feels like ${w.feelsLike.round()}°C',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _weatherIcon(w.iconUrl, size: 94),
                    const SizedBox(height: 3),
                    Text(w.isDay ? 'DAYTIME' : 'NIGHT',
                        style: const TextStyle(
                            color: _blue,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.update, size: 15, color: _muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Updated ${_formatTime(w.lastUpdated)}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
                const Icon(Icons.wifi, size: 15, color: _blue),
                const SizedBox(width: 5),
                const Text('LIVE DATA',
                    style: TextStyle(
                        color: _blue,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlights(WeatherData w) {
    final items = [
      _Metric(Icons.water_drop_outlined, 'Humidity', '${w.humidity}%', _blue),
      _Metric(Icons.air_rounded, 'Wind', '${w.windKph.round()} km/h', _purple),
      _Metric(Icons.speed_rounded, 'Pressure', '${w.pressureMb.round()} mb', Colors.orangeAccent),
      _Metric(Icons.visibility_outlined, 'Visibility', '${w.visibilityKm.toStringAsFixed(1)} km', Colors.tealAccent),
      _Metric(Icons.wb_sunny_outlined, 'UV Index', w.uv.toStringAsFixed(1), Colors.amberAccent),
      _Metric(Icons.umbrella_outlined, 'Rain chance',
          '${w.forecast.isNotEmpty ? w.forecast.first.chanceOfRain : 0}%', Colors.lightBlueAccent),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Weather highlights', 'CURRENT CONDITIONS'),
          const SizedBox(height: 13),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.85,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _muted, fontSize: 10)),
                          const SizedBox(height: 5),
                          Text(item.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHourly(WeatherData w) {
    final now = DateTime.now();
    final hours = w.hourlyForecast
        .where((hour) => hour.time.isAfter(now.subtract(const Duration(hours: 1))))
        .take(12)
        .toList();

    final chartHours = hours.isNotEmpty
        ? hours
        : w.hourlyForecast.take(12).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 23),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading('Hourly forecast', 'NEXT HOURS'),
            const SizedBox(height: 6),
            const Text('Temperature trend · °C',
                style: TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 15),
            SizedBox(
              height: 132,
              width: double.infinity,
              child: CustomPaint(
                painter: _TemperatureChartPainter(
                  values: chartHours.map((h) => h.temperature).toList(),
                  lineColor: _blue,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chartHours.length,
                separatorBuilder: (context, index) => const SizedBox(width: 19),
                itemBuilder: (context, index) {
                  final hour = chartHours[index];
                  return SizedBox(
                    width: 47,
                    child: Column(
                      children: [
                        Text(_formatHour(hour.time),
                            style: const TextStyle(color: _muted, fontSize: 10)),
                        _weatherIcon(hour.iconUrl, size: 35),
                        Text('${hour.temperature.round()}°',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Icon(Icons.water_drop,
                            size: 11,
                            color: hour.chanceOfRain > 30 ? _blue : _muted),
                        Text('${hour.chanceOfRain}%',
                            style: const TextStyle(color: _muted, fontSize: 9)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecast(WeatherData w) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 23),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading('5-day forecast', 'PLAN AHEAD'),
            const SizedBox(height: 17),
            if (w.forecast.isNotEmpty)
              SizedBox(
                height: 100,
                child: CustomPaint(
                  painter: _ForecastRangePainter(days: w.forecast),
                  child: const SizedBox.expand(),
                ),
              ),
            const SizedBox(height: 10),
            ...w.forecast.map((day) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 49,
                        child: Text(_dayLabel(day.date),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 5),
                      _weatherIcon(day.iconUrl, size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(day.condition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11)),
                      ),
                      Text('${day.chanceOfRain}%',
                          style: const TextStyle(color: _blue, fontSize: 11)),
                      const SizedBox(width: 13),
                      Text('${day.maxTemp.round()}°',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Text('${day.minTemp.round()}°',
                          style: const TextStyle(color: _muted)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSunTimes(WeatherData w) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 23),
      child: Row(
        children: [
          Expanded(
            child: _sunCard(
              icon: Icons.wb_twilight_rounded,
              label: 'SUNRISE',
              value: w.sunrise,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _sunCard(
              icon: Icons.nights_stay_outlined,
              label: 'SUNSET',
              value: w.sunset,
              color: _purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sunCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                        letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCities() {
    if (_favorites.isEmpty && _recentCities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_favorites.isNotEmpty) ...[
            _sectionHeading('Favorite cities', 'SAVED'),
            const SizedBox(height: 11),
            _cityChips(_favorites, Icons.favorite, Colors.pinkAccent),
            const SizedBox(height: 20),
          ],
          if (_recentCities.isNotEmpty) ...[
            _sectionHeading('Recent searches', 'HISTORY'),
            const SizedBox(height: 11),
            _cityChips(_recentCities, Icons.history, _blue),
          ],
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'Weather data powered by WeatherAPI.com',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cityChips(List<String> cities, IconData icon, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cities
          .map(
            (city) => ActionChip(
              avatar: Icon(icon, size: 15, color: color),
              label: Text(city),
              backgroundColor: _surface,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
              labelStyle: const TextStyle(fontSize: 12),
              onPressed: () => _fetchWeather(city),
            ),
          )
          .toList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 56),
            const SizedBox(height: 18),
            const Text('Could not load weather',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(_error ?? 'Please try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _fetchWeather(_selectedCity),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Check your internet connection and WEATHER_API_KEY in .env.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_queue_rounded, size: 65, color: _blue),
            SizedBox(height: 15),
            Text('Your weather, at a glance',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('Search for a city to see current conditions and forecasts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, String tag) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
        ),
        Text(tag,
            style: const TextStyle(
                color: _muted,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _weatherIcon(String url, {double size = 42}) {
    var normalized = url;
    if (normalized.startsWith('//')) normalized = 'https:$normalized';

    if (normalized.isEmpty) {
      return Icon(Icons.cloud_outlined, size: size, color: _blue);
    }

    return Image.network(
      normalized,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.cloud_outlined,
        size: size,
        color: _blue,
      ),
    );
  }

  Future<void> _showFavorites() async {
    if (_favorites.isEmpty) {
      _showMessage('No favorite cities yet. Tap the heart on a city.');
      return;
    }
    _showCityPicker('Favorite cities', _favorites);
  }

  Future<void> _showRecent() async {
    if (_recentCities.isEmpty) {
      _showMessage('Your recent searches will appear here.');
      return;
    }
    _showCityPicker('Recent searches', _recentCities);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showCityPicker(String title, List<String> cities) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            ...cities.map(
              (city) => ListTile(
                leading: const Icon(Icons.location_on_outlined, color: _blue),
                title: Text(city),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _fetchWeather(city);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatHour(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour ${time.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    }
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }
}

class _Metric {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Metric(this.icon, this.label, this.value, this.color);
}

class _TemperatureChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;

  const _TemperatureChartPainter({
    required this.values,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final minValue = values.reduce(math.min) - 2;
    final maxValue = values.reduce(math.max) + 2;
    final range = math.max(maxValue - minValue, 1.0);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height -
          ((values[i] - minValue) / range) * (size.height - 20) -
          10;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middleX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        middleX, previous.dy, middleX, current.dy, current.dx, current.dy,
      );
    }

    final area = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.28),
          lineColor.withValues(alpha: 0.01),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    canvas.drawPath(area, fillPaint);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        3,
        Paint()..color = lineColor,
      );
      canvas.drawCircle(
        points[i],
        5,
        Paint()..color = lineColor.withValues(alpha: 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}

class _ForecastRangePainter extends CustomPainter {
  final List<ForecastDay> days;

  const _ForecastRangePainter({required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    final minimum = days.map((d) => d.minTemp).reduce(math.min) - 2;
    final maximum = days.map((d) => d.maxTemp).reduce(math.max) + 2;
    final range = math.max(maximum - minimum, 1.0);
    final spacing = size.width / days.length;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final x = spacing * i + spacing / 2;
      final top = size.height -
          ((day.maxTemp - minimum) / range) * (size.height - 12) - 6;
      final bottom = size.height -
          ((day.minTemp - minimum) / range) * (size.height - 12) - 6;

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        Paint()
          ..shader = const LinearGradient(
            colors: [_blue, _purple],
          ).createShader(Rect.fromLTRB(x, top, x + 1, bottom))
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${day.maxTemp.round()}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, top - 15));

      final lowPainter = TextPainter(
        text: TextSpan(
          text: '${day.minTemp.round()}°',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lowPainter.paint(canvas, Offset(x - lowPainter.width / 2, bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastRangePainter oldDelegate) =>
      oldDelegate.days != days;
}








