import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> users = [];
  bool isLoading = true;

  String searchQuery = '';

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

  Future<bool> updateUser(int index, Map<String, dynamic> updatedFields) async {
    try {
      final user = users[index];
      final id = user['org_id'];

      await supabase.from('USERS').update(updatedFields).eq('org_id', id);

      return true; // ✅ Assume success if no exception
    } catch (e) {
      print('Update error: $e'); // You can see actual errors in console
      return false;
    }
  }

  Future<void> deleteUser(int index) async {
    final user = users[index];
    final id = user['org_id'];

    await supabase.from('USERS').delete().eq('org_id', id);

    setState(() {
      users.removeAt(index);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("User deleted successfully")));
  }

  void showUserDialog({Map<String, dynamic>? user, int? index}) {
    final isEditing = user != null;
    final orgIdController = TextEditingController(text: user?['org_id'] ?? '');
    final nameController = TextEditingController(text: user?['name'] ?? '');
    final departmentController = TextEditingController(
      text: user?['dept'] ?? '',
    );
    final designationController = TextEditingController(
      text: user?['designation'] ?? '',
    );
    final passwordController = TextEditingController(
      text: user?['password'] ?? '',
    );
    final selectedAuthorityController = TextEditingController(
      text: user?['authority'],
    );
    final workingAreaController = TextEditingController(
      text: user?['working_area'],
    );

    final List<String> dept_list = [
      'CUTTING',
      'EMBROIDERY',
      'PRINTING',
      'SEWING',
      'FINISHING',
      'QUALITY ASSURANCE',
      'WASHING',
      'IE & Workstudy',
      'PLANNING',
      'MAINTENANCE',
      'OPERATIONS',
      'MATERIAL MANAGEMENT',
      'HR & ADMIN',
      'CAP PRODUCTION',
      'R&D DESIGN',
      'TECHNICAL & PRODUCT DEV',
      'ACCOUNTS',
      'TRAINING & DEV.',
    ];

    final List<String> deg_list = [
      'Executive Director',
      'Director',
      'Production Director',
      'General Manager',
      'Deputy General Manager',
      'Assistant General Manager',
      'Sr. Manager',
      'Manager',
      'Deputy Manager',
      'Assistant Manager',
      'Sr. Executive-I',
      'Sr. Executive-II',
      'Executive-I',
      'Executive-II',
      'Executive-III',
      'Officer',
      'Assistant Officer',
      'PO',
      'APO',
      'MO',
      'AMO',
      'QO',
      'AQO',
      'TO',
      'ATO',
      'Plant Physician',
      'Medical Officer',
    ];

    final List<String> authority_list = ["ADMIN", "USER", "GUEST"];

    final List<String> workingArea_list = [
      "Cutting",
      "Embroidery",
      "Printing",
      "Finishing",
      "Quality Assurance",
      'Washing',
      "Planning",
      "Maintenance",
      "Cap Production",
      "Technical & Product Dev",
      "1-6",
      "7-15",
      "16-21",
      "22-30",
      "31,36",
      "37-41",
      "42-46",
      "47-49",
      "50-55",
      "56-62",
      "63-69",
      "70-76",
      "77-81",
      "82-86",
      "87-91",
      "92-96",
      "97-105",
      "106-114",
      "116-124",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? "Edit User" : "Register New User"),
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
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                // SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value:
                      departmentController.text.isNotEmpty
                          ? departmentController.text
                          : null,
                  decoration: const InputDecoration(labelText: "Department"),
                  items:
                      dept_list.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Text(dept),
                        );
                      }).toList(),
                  onChanged: (value) {
                    departmentController.text = value ?? '';
                  },
                ),
                DropdownButtonFormField<String>(
                  value:
                      designationController.text.isNotEmpty
                          ? designationController.text
                          : null,
                  decoration: const InputDecoration(labelText: "Designation"),
                  items:
                      deg_list.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Text(dept),
                        );
                      }).toList(),
                  onChanged: (value) {
                    designationController.text = value ?? '';
                  },
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: false,
                ),
                DropdownButtonFormField<String>(
                  value:
                      workingAreaController.text.isNotEmpty
                          ? workingAreaController.text
                          : null,
                  decoration: const InputDecoration(labelText: "Working Area"),
                  items:
                      workingArea_list.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Text(dept),
                        );
                      }).toList(),
                  onChanged: (value) {
                    workingAreaController.text = value ?? '';
                  },
                ),
                DropdownButtonFormField<String>(
                  value:
                      selectedAuthorityController.text.isNotEmpty
                          ? selectedAuthorityController.text
                          : null,
                  decoration: const InputDecoration(labelText: 'Authority'),
                  items:
                      authority_list.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child: Text(dept),
                        );
                      }).toList(),
                  onChanged:
                      (value) => selectedAuthorityController.text = value ?? '',
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
                final name = nameController.text.trim();
                final department = departmentController.text.trim();
                final designation = designationController.text.trim();
                final password = passwordController.text.trim();
                final authority = selectedAuthorityController.text.trim();
                final working_area = workingAreaController.text.trim();

                if ([
                  orgId,
                  name,
                  department,
                  designation,
                  password,
                  authority,
                  working_area,
                ].any((element) => element == null || element.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All fields are required")),
                  );
                  return;
                }

                bool success = false;

                if (isEditing) {
                  success = await updateUser(index!, {
                    'org_id': orgId,
                    'authority': authority,
                    'password': password,
                    'dept': department,
                    'designation': designation,
                    'name': name,
                    'working_area': working_area,
                  });
                } else {
                  try {
                    await supabase.from('USERS').insert({
                      'org_id': orgId,
                      'authority': authority,
                      'password': password,
                      'dept': department,
                      'designation': designation,
                      'name': name,
                      'working_area': working_area,
                    });
                    success = true;
                  } catch (e) {
                    success = false;
                  }
                }

                if (success) {
                  Navigator.pop(context); // ✅ Close modal after success
                  await fetchUsers(); // ✅ Refresh list

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? "User updated successfully"
                            : "User registered successfully",
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Failed to update. Please try again."),
                    ),
                  );
                }
              },
              child: Text(isEditing ? "Update" : "Register"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by ID',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.trim();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount:
                          users.where((user) {
                            final id = user['org_id']?.toLowerCase() ?? '';
                            return id.contains(searchQuery.toLowerCase());
                          }).length,
                      itemBuilder: (context, index) {
                        final filteredUsers =
                            users.where((user) {
                              final id = user['org_id']?.toLowerCase() ?? '';
                              return id.contains(searchQuery.toLowerCase());
                            }).toList();

                        final user = filteredUsers[index];
                        return Dismissible(
                          key: Key(user['id'].toString()),
                          background: Container(
                            color: Colors.blue,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              showUserDialog(
                                user: user,
                                index: users.indexOf(user),
                              );
                              return false;
                            } else {
                              final confirmed = await showDialog(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: const Text('Delete User'),
                                      content: const Text(
                                        'Are you sure you want to delete this user?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirmed)
                                await deleteUser(users.indexOf(user));
                              return confirmed;
                            }
                          },
                          child: Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(
                                user['name'] ?? 'No Name',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${user['org_id'] ?? '-'}'),
                                  Text('Password: ${user['password'] ?? '-'}'),
                                  Text('Department: ${user['dept'] ?? '-'}'),
                                  Text(
                                    'Designation: ${user['designation'] ?? '-'}',
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.more_vert),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showUserDialog(),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
