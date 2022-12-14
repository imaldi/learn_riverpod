import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// contoh basic read only provider
final myStringProvider = Provider((ref) => 'Hello world!');

// contoh write-read provider that preserved the state
// final counterProvider = StateProvider((ref) => 0);
// contoh yang reset ketika pindah halaman
final counterProvider = StateProvider.autoDispose((ref) => 0);

// fake web socket provider
final websocketClientProvider = Provider<WebsocketClient>(
      (ref) {
    return FakeWebsocketClient();
  },
);

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learn Riverpod',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: ElevatedButton(
          child: const Text('Go to Counter Page'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: ((context) => const CounterPage()),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ConsumerWidget is like a StatelessWidget
// but with a WidgetRef parameter added in the build method.
class CounterPage extends ConsumerWidget {
  const CounterPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final counterStreamProvider = StreamProvider.family<int, int>((ref, start) {
      final wsClient = ref.watch(websocketClientProvider);

      return wsClient.getCounterStream(start);
    });

    // AsyncValue is a union of 3 cases - data, error and loading
    final AsyncValue<int> counterStream = ref.watch(counterStreamProvider(5));

    // Using the WidgetRef to get the counter int from the counterProvider.
    // The watch method makes the widget rebuild whenever the int changes value.
    //   - something like setState() but automatic
    final int counter = ref.watch(counterProvider);

    ref.listen<int>(
      counterProvider,
      // "next" is referring to the new state.
      // The "previous" state is sometimes useful for logic in the callback.
          (previous, next) {
        if (next >= 5) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Warning'),
                content:
                Text('Counter dangerously high. Consider resetting it.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  )
                ],
              );
            },
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(counterProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: Text(
          // counter.toString(),
          counterStream
              .when(
            data: (int value) => value,
            error: (Object e, _) => e,
            // While we're waiting for the first counter value to arrive
            // we want the text to display zero.
            loading: () => 0,
          )
              .toString(),
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // Using the WidgetRef to read() the counterProvider just one time.
          //   - unlike watch(), this will never rebuild the widget automatically
          // We don't want to get the int but the actual StateNotifier, hence we access it.
          // StateNotifier exposes the int which we can then mutate (in our case increment).
          ref.read(counterProvider.notifier).state++;
        },
      ),
    );
  }
}

abstract class WebsocketClient {
  Stream<int> getCounterStream([int start]);
}

class FakeWebsocketClient implements WebsocketClient {
  @override
  Stream<int> getCounterStream([int start = 0]) async* {
    int i = start;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      yield i++;
    }
  }
}