// lib/pages/user_list_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final response = await supabase.from('USERS').select();

    setState(() {
      users = response;
      isLoading = false;
    });
  }

  Future<void> updateUser(int index, String key, String newValue) async {
    final user = users[index];
    final id = user['id'];

    await supabase.from('USERS').update({key: newValue}).eq('id', id);

    setState(() {
      users[index][key] = newValue;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("User updated successfully")));
  }

  void showEditDialog(int index, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit $field"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: field),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                updateUser(index, field, controller.text.trim());
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void showAddUserDialog() {
    final orgIdController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedAuthority;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Register New User"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: orgIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID (org_id)',
                  ),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAuthority,
                  decoration: const InputDecoration(labelText: 'Authority'),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                    DropdownMenuItem(value: 'USER', child: Text('USER')),
                    DropdownMenuItem(value: 'VISITOR', child: Text('VISITOR')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedAuthority = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final orgId = orgIdController.text.trim();
                final password = passwordController.text.trim();
                final authority = selectedAuthority;

                if (orgId.isEmpty || password.isEmpty || authority == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All fields are required")),
                  );
                  return;
                }

                final existing =
                    await supabase
                        .from('USERS')
                        .select()
                        .eq('org_id', orgId)
                        .maybeSingle();

                if (existing != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User ID already exists")),
                  );
                  return;
                }

                await supabase.from('USERS').insert({
                  'org_id': orgId,
                  'password': password,
                  'authority': authority,
                });

                Navigator.pop(context);
                fetchUsers();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User registered successfully")),
                );
              },
              child: const Text("Register"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users List')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(user['org_id'] ?? 'No ID'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Authority: ${user['authority']}"),
                          Text("Password: ${user['password']}"),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (field) {
                          showEditDialog(index, field, user[field] ?? '');
                        },
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: 'authority',
                                child: Text('Edit Authority'),
                              ),
                              PopupMenuItem(
                                value: 'password',
                                child: Text('Edit Password'),
                              ),
                            ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddUserDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
