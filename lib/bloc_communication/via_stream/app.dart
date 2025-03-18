import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'notepad_bloc.dart';
import 'person_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Communication Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BlocProviderWrapper(),
    );
  }
}

// Wrapper to allow BloC recreation
class BlocProviderWrapper extends StatefulWidget {
  const BlocProviderWrapper({super.key});

  @override
  State<BlocProviderWrapper> createState() => _BlocProviderWrapperState();
}

class _BlocProviderWrapperState extends State<BlocProviderWrapper> {
  // Use a key to force rebuild of BloC providers
  Key _blocKey = UniqueKey();

  void _resetBlocs() {
    setState(() {
      _blocKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      key: _blocKey,
      providers: [
        BlocProvider(create: (_) => NotepadBloc()),
        BlocProvider(create: (context) => PersonBloc(context.read<NotepadBloc>())),
      ],
      child: HomePage(onReset: _resetBlocs),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onReset;

  const HomePage({super.key, required this.onReset});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personBloc = context.read<PersonBloc>();
    final notepadBloc = context.watch<NotepadBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Communication Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset BLoCs',
            onPressed: widget.onReset,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: BlocBuilder<PersonBloc, PersonState>(
              builder: (context, state) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          labelText: 'Add a note',
                          border: OutlineInputBorder(),
                        ),
                        enabled: state is! PersonWriting,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed:
                          state is PersonWriting
                              ? null
                              : () {
                                if (_controller.text.isNotEmpty) {
                                  personBloc.add(AddNote(_controller.text));
                                  _controller.clear();
                                }
                              },
                      child:
                          state is PersonWriting
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                              : const Text('Add'),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<NotepadBloc, List<String>>(
              builder: (context, notes) {
                if (notes.isEmpty) {
                  return const Center(
                    child: Text('No notes yet! Add one to get started.'),
                  );
                }

                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(notes[index]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showEditDialog(context, index, notes[index]);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              personBloc.add(RemoveNote(index));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, int index, String currentNote) {
    final TextEditingController editController = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Note'),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Edit note'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (editController.text.isNotEmpty) {
                  context.read<PersonBloc>().add(EditNote(index, editController.text));
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((_) => editController.dispose());
  }
}
