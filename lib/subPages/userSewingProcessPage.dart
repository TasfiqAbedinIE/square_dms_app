import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterProcessPage extends StatefulWidget {
  const RegisterProcessPage({super.key});

  @override
  State<RegisterProcessPage> createState() => _RegisterProcessPageState();
}

class _RegisterProcessPageState extends State<RegisterProcessPage> {
  final supabase = Supabase.instance.client;

  final TextEditingController processNameController = TextEditingController();
  final TextEditingController formController = TextEditingController();
  final TextEditingController smvController = TextEditingController();

  String? selectedItem;
  String? selectedMachine;
  bool isLoading = false;

  final List<String> itemList = [
    "Tee",
    "Polo",
    "Jacket",
    "Trouser",
    "Cardigan",
    "Dress",
    "Tops",
    "Leggings",
    "Apron",
    "Blazer",
    "Skirt",
    "Vest",
    "Tank Top",
    "Sweat Shirt",
    "Pant",
    "Shirt",
    "Short",
    "Boxer",
    "Frock",
    "Romper",
  ];

  List<String> machineList = [];

  @override
  void initState() {
    super.initState();
    fetchMachines();
  }

  Future<void> fetchMachines() async {
    final response = await supabase
        .from('sewing_process_database')
        .select('machine')
        .neq('machine', '')
        .order('machine');

    final data = response as List<dynamic>;
    final uniqueMachines =
        {for (final row in data) row['machine'] as String}.toList()..sort();

    setState(() {
      machineList = uniqueMachines;
    });
  }

  Future<void> registerProcess() async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final processName = processNameController.text.trim();
    final item = selectedItem?.trim() ?? '';
    final machine = selectedMachine?.trim() ?? '';
    final form = formController.text.trim();
    final smv = smvController.text.trim();

    if ([processName, item, machine, smv].any((e) => e.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields except form are required.')),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final smvValue = double.tryParse(smv);
      if (smvValue == null) {
        throw Exception("SMV must be a valid number");
      }

      await supabase.from('sewing_process_database').insert({
        'id': id,
        'process_name': processName,
        'item': item,
        'machine': machine,
        'form': form,
        'smv': smvValue,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Process registered successfully')),
      );

      processNameController.clear();
      formController.clear();
      smvController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register New Process')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: processNameController,
              decoration: const InputDecoration(labelText: 'Process Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedItem,
              decoration: const InputDecoration(labelText: 'Item'),
              items:
                  itemList
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  selectedItem = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedMachine,
              decoration: const InputDecoration(labelText: 'Machine'),
              items:
                  machineList
                      .map(
                        (machine) => DropdownMenuItem(
                          value: machine,
                          child: Text(machine),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  selectedMachine = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: formController,
              decoration: const InputDecoration(labelText: 'Form (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: smvController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'SMV'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isLoading ? null : registerProcess,
              icon: const Icon(Icons.save),
              label:
                  isLoading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
