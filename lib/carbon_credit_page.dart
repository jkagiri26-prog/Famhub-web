import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'carbon_provider.dart'; 

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
            Text(
              'Carbon Portal',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Offset Balance', 
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  '${provider.totalBalance.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 32, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Recent Activity', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          if (provider.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No recent transactions"),
            )
          else
            ...provider.transactions.map((tx) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  // FIX: Icons.Eco -> Icons.eco
                  leading: const CircleAvatar(child: Icon(Icons.eco, size: 20)),
                  title: Text(tx.projectName, 
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(tx.date.toString().substring(0, 10)),
                  trailing: Text('+${tx.amountKg}kg',
                      style: const TextStyle(
                        color: Colors.green, 
                        fontWeight: FontWeight.bold
                      )),
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
          decoration: const InputDecoration(
            labelText: 'Distance (KM)', 
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.route),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => 
              _res = (double.tryParse(_controller.text) ?? 0) * 0.2),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Calculate Impact'),
          ),
        ),
        if (_res > 0)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: [
                const Text('Estimated Carbon Footprint:'),
                Text('${_res.toStringAsFixed(2)} kg CO2e',
                    style: TextStyle(
                      fontSize: 24,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('1 Offset = 100kg'),
        trailing: Text('\$$price', 
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        onTap: () => showModalBottomSheet(
          context: context,
          builder: (ctx) => _TradeSheet(name: name, price: price),
        ),
      ),
    );
  }
}

class _TradeSheet extends StatelessWidget {
  final String name;
  final double price;
  const _TradeSheet({required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          Text('Confirm Purchase', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '10% (\$${(price * 0.1).toStringAsFixed(2)}) goes to Village Fund',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<CarbonProvider>().processTrade(name, 100.0, price);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction Successful!'))
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Pay & Offset'),
            ),
          ),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.groups_rounded, size: 64, color: Colors.blueGrey),
        const SizedBox(height: 16),
        Text(
          'Village Fund: \$${provider.communityFund.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 28, 
            fontWeight: FontWeight.bold, 
            color: Colors.blueGrey
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'These funds are automatically split among local cooperatives to support infrastructure and ensure the community benefits equally from every credit traded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}