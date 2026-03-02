import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.blueGrey,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 40,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            color: Colors.blueAccent,
            child: Row(
              children: const [
                Icon(Icons.person, color: Colors.white, size: 40),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'accountName',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      'accountEmail',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: Colors.white),
                  title: Text('Minha Conta'),
                  onTap: () {},
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.white),
                  title: Text('Configurações'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 2),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sair'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
