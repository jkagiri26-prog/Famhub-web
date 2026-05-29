class DashboardHost extends StatefulWidget {
  const DashboardHost({super.key});

  @override
  State<DashboardHost> createState() => _DashboardHostState();
}

class _DashboardHostState extends State<DashboardHost> {
  late final DashboardCompositionEngine engine;

  late final Future<CompositionSnapshot> _future;

  @override
  void initState() {
    super.initState();

    engine = DashboardCompositionEngine(
      moduleResolver: ModuleResolver(
        registry: DashboardModuleRegistry(),
      ),
      layoutResolver: LayoutResolver(),
    );

    _future = engine.build(
      context: const LayoutContext(
        device: LayoutDeviceType.mobile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompositionSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          body: DashboardRendererWidget(
            snapshot: snapshot.data!,
          ),
        );
      },
    );
  }
}