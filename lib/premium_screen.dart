import 'package:flutter/material.dart';
import 'services/billing_service.dart';

final billing = BillingService();

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchy Premium"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Desbloqueia o Premium ",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            const Text("✔ 4 receitas por dia"),
            const Text("✔ Sem anúncios"),
            const Text("✔ Receitas completas"),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () async {
                try {
                  await billing.buy("premium_monthly");

                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Erro na compra")),
                  );
                }
              },
              child: const Text("Subscrever 3.49€/mês"),
            ),
          ],
        ),
      ),
    );
  }
}