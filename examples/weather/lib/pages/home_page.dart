import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/cities_controller.dart';
import '../widgets/city_card.dart';
import 'search_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final citiesController = context.read<CitiesController>();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: SignalBuilder(
              builder: (context, child) {
                return Text('Weather (${citiesController.count.value})');
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: citiesController.cities.isEmpty
              ? const Center(
                  child: Text('No cities — add one with the + button'),
                )
              : ListView.builder(
                  itemCount: citiesController.cities.length,
                  itemBuilder: (context, index) {
                    final city = citiesController.cities[index];
                    return CityCard(key: ValueKey(city), city: city);
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
