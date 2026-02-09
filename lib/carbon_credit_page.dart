import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CarbonCreditPage extends StatelessWidget {
  const CarbonCreditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text('Carbon Portal', 
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TabBar(
              isScrollable: true,
              labelColor: theme.colorScheme.primary,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Calculate'),
                Tab(text: 'Market'),
                Tab(text: 'Village Impact'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(),
                  _CalculatorTab(),
                  _MarketplaceTab(),
                  _CommunityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TAB SUB-WIDGETS ---

class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CarbonProvider>();
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary, 
              borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Offset Balance', style: TextStyle(color: Colors.white70)),
                Text('${provider.totalBalance.toStringAsFixed(2)} kg', 
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, 
            child: Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold))),
          ...provider.transactions.map((tx) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tx.projectName),
            trailing: Text('+${tx.amountKg}kg', 
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }
}

class _CalculatorTab extends StatefulWidget {
  @override
  State<_CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<_CalculatorTab> {
  final _controller = TextEditingController();
  double _res = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Distance (KM)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _res = (double.tryParse(_controller.text) ?? 0) * 0.2),
          child: const Text('Calculate Impact'),
        ),
        if (_res > 0) Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text('Estimate: ${_res.toStringAsFixed(2)} kg CO2e', 
            style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _MarketplaceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _item(context, 'Mau Forest Reforestation', 15.00),
        _item(context, 'Turkana Wind Farm', 12.50),
        _item(context, 'Methane Capture Kiambu', 9.00),
      ],
    );
  }

  Widget _item(BuildContext context, String name, double price) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name),
        trailing: Text('\$$price'),
        onTap: () => showModalBottomSheet(
          context: context,
          builder: (ctx) => _TradeSheet(name: name, price: price),
        ),
      ),
    );
  }
}

class _TradeSheet extends StatelessWidget {
  final String name; final double price;
  const _TradeSheet({required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Confirm Purchase', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text('10% (\$${(price * 0.1).toStringAsFixed(2)}) goes to Village Fund', 
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              context.read<CarbonProvider>().processTrade(name, 100.0, price);
              Navigator.pop(context);
            },
            child: const Text('Pay & Offset'),
          )),
        ],
      ),
    );
  }
}

class _CommunityTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CarbonProvider>();
    return Column(
      children: [
        Text('Village Fund: \$${provider.communityFund.toStringAsFixed(2)}', 
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 20),
        const Text(
          'These funds are automatically split among local cooperatives to support infrastructure and ensure the community benefits equally from every credit traded.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
