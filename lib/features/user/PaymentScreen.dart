import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> studioData;

  const PaymentScreen({
    super.key,
    required this.bookingData,
    required this.studioData,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = "UPI";
  String selectedBank = "HDFC";
  bool isProcessing = false;
  bool isSuccess = false;

  /// 🔗 Launch payment apps
  Future<void> launchPaymentApp() async {
    const upiId = "yourupi@bank"; // 🔥 replace with your UPI ID
    const name = "Studio Booking";
    const amount = "1";

    try {
      if (selectedMethod == "UPI") {
        // 🔥 Opens ANY UPI app (GPay, PhonePe, Paytm, etc.)
        final uri = Uri.parse(
          "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}&am=$amount&cu=INR",
        );

        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } 
      else if (selectedMethod == "Net Banking") {
        // 💡 Dummy net banking simulation
        _showBankDialog();
        return;
      } 
      else if (selectedMethod == "Debit/Credit Card" ||
               selectedMethod == "Cash on Arrival") {
        handlePayment();
        return;
      }

      // ✅ simulate success after returning
      handlePayment();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No payment app available")),
      );
    }
  }

  /// 🏦 Bank selection popup
  void _showBankDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Select Bank"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bankOption("HDFC"),
              _bankOption("SBI"),
              _bankOption("ICICI"),
              _bankOption("Axis Bank"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                handlePayment(); // simulate success
              },
              child: const Text("Proceed"),
            )
          ],
        );
      },
    );
  }

  Widget _bankOption(String bank) {
    return RadioListTile(
      value: bank,
      groupValue: selectedBank,
      onChanged: (val) {
        setState(() => selectedBank = val.toString());
      },
      title: Text(bank),
    );
  }

  /// ⏳ Fake success
  void handlePayment() async {
    setState(() => isProcessing = true);

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      isProcessing = false;
      isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: isSuccess ? _buildSuccessUI() : _buildPaymentUI(),
      ),
    );
  }

  /// ================= PAYMENT UI =================
Widget _buildPaymentUI() {
  return SingleChildScrollView(
    key: const ValueKey("payment"),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Payment Method",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        _paymentOption("UPI", Icons.qr_code),
        _paymentOption("Net Banking", Icons.account_balance),
        _paymentOption("Debit/Credit Card", Icons.credit_card),
        _paymentOption("Cash on Arrival", Icons.money),

        const SizedBox(height: 40), // spacing before button

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isProcessing ? null : launchPaymentApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.all(14),
            ),
            child: isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Confirm Payment Method",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ),
      ],
    ),
  );
}

  /// ================= SUCCESS UI =================
  Widget _buildSuccessUI() {
    return Center(
      key: const ValueKey("success"),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 90),
          const SizedBox(height: 16),

          const Text(
            "Payment Successful",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Text("Paid via $selectedMethod"),

          if (selectedMethod == "Net Banking")
            Text("Bank: $selectedBank"),

          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text("Go to Home"),
          )
        ],
      ),
    );
  }

  /// ================= OPTION TILE =================
  Widget _paymentOption(String title, IconData icon) {
    return RadioListTile(
      value: title,
      groupValue: selectedMethod,
      onChanged: (value) {
        setState(() {
          selectedMethod = value.toString();
        });
      },
      title: Row(
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
    );
  }
}