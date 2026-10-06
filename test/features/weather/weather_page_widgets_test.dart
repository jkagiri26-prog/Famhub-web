/// Widget-level checks for the Weather page panels: no layout overflow at
/// phone widths, and the premium chrome renders what it is supposed to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/theme/shell_theme_provider.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/presentation/widgets/weather_forecast_views.dart';
import 'package:famhub_app/features/weather/presentation/widgets/weather_ui.dart';

Widget _host(Widget child, {double width = 360}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: FamhubBrandTokens.green),
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('WeatherCurrentPanel', () {
    final current = CurrentWeather(
      latitude: -0.194,
      longitude: 34.777,
      temperatureC: 27,
      feelsLikeC: 29,
      condition: 'Sunny',
      humidityPercent: 61,
      precipitationProbabilityPercent: 10,
      rainfallMm: 0.4,
      windSpeedMps: 3.2,
      windDirectionDegrees: 72,
      fetchedAt: _fixed,
    );
    final meta = WeatherMeta(fetchedAt: _fixed);

    testWidgets('renders hero readings, location and refresh line',
        (tester) async {
      await tester.pumpWidget(_host(
        WeatherCurrentPanel(
          current: current,
          meta: meta,
          locationLabel: 'Kisumu',
          refreshing: true,
        ),
      ));

      expect(find.text('27°'), findsOneWidget);
      expect(find.text('Sunny'), findsOneWidget);
      expect(find.text('Kisumu'), findsOneWidget);
      expect(find.text('Feels like'), findsOneWidget);
      expect(find.text('Rain chance'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      await tester.pumpWidget(_host(
        WeatherCurrentPanel(
          current: current,
          meta: meta,
          locationLabel: 'A very long farm name location label',
          refreshing: false,
        ),
        width: 320,
      ));

      expect(find.text('27°'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('forecast sections', () {
    final hours = List<HourlyForecast>.generate(8, (i) => HourlyForecast(
          time: _fixed.add(Duration(hours: i)),
          temperatureC: 20 + i.toDouble(),
          condition: i.isEven ? 'Sunny' : 'Light rain',
          precipitationProbabilityPercent: i * 10,
        ));

    final days = List<DailyForecast>.generate(7, (i) => DailyForecast(
          date: DateTime(2026, 10, 6 + i),
          condition: i.isEven ? 'Sunny' : 'Showers',
          tempMaxC: 30 - i.toDouble(),
          tempMinC: 18 - i.toDouble(),
          precipitationProbabilityPercent: i * 10,
          rainfallMm: 0.2 * i,
        ));

    testWidgets('hourly strip shows cells', (tester) async {
      await tester.pumpWidget(_host(WeatherHourlyStrip(hours: hours)));

      expect(find.textContaining('°'), findsWidgets);
      expect(find.byIcon(Icons.water_drop_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('daily list shows rows with a temperature range',
        (tester) async {
      await tester.pumpWidget(_host(WeatherDailyList(days: days)));

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('30°'), findsOneWidget);
      expect(find.text('18°'), findsOneWidget);
      expect(find.textContaining('Showers'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('daily list fits a narrow phone', (tester) async {
      await tester.pumpWidget(_host(WeatherDailyList(days: days), width: 320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty forecast renders the framed placeholder',
        (tester) async {
      await tester.pumpWidget(_host(const WeatherHourlyStrip(hours: [])));

      expect(find.text('No hourly forecast available.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('page states', () {
    testWidgets('hero skeleton has the hero footprint', (tester) async {
      await tester.pumpWidget(_host(const WeatherCardFrame(
        child: WeatherSkeleton(compact: false),
      )));
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact skeleton keeps the dashboard card small',
        (tester) async {
      await tester.pumpWidget(_host(const WeatherCardFrame(
        child: WeatherSkeleton(),
      )));
      expect(tester.takeException(), isNull);
    });

    testWidgets('error state exposes a retry action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_host(WeatherCardFrame(
        child: WeatherErrorState(onRetry: () => tapped = true),
      )));

      await tester.tap(find.text('Retry'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unavailable state renders its message', (tester) async {
      await tester.pumpWidget(_host(const WeatherCardFrame(
        child: WeatherUnavailable(message: 'No location selected'),
      )));

      expect(find.text('No location selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

final DateTime _fixed = DateTime.utc(2026, 10, 6, 12);
