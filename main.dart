import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color brand = Color(0xFFFFC928);
const Color ink = Color(0xFF202124);
const Color muted = Color(0xFF74777D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MashwariApp());
}

class MashwariApp extends StatelessWidget {
  const MashwariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مشواري',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        colorScheme: ColorScheme.fromSeed(seedColor: brand, primary: brand),
        fontFamily: 'Arial',
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: AuthGate(),
      ),
    );
  }
}

/// يراقب جلسة Firebase: المستخدم المسجل ينتقل للتطبيق، وغيره إلى شاشة الدخول.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return const HomeScreen();
        return const PhoneLoginScreen();
      },
    );
  }
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String? verificationId;
  int? resendToken;
  bool codeSent = false;
  bool busy = false;
  String? errorText;

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String get fullPhone => '+964${phoneController.text.trim()}';

  void showError(String message) {
    if (!mounted) return;
    setState(() {
      errorText = message;
      busy = false;
    });
  }

  Future<void> sendCode() async {
    if (!formKey.currentState!.validate()) return;
    setState(() { busy = true; errorText = null; });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // بعض أجهزة Android تتحقق تلقائياً دون إدخال الرمز.
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          showError(_authError(e));
        },
        codeSent: (String id, int? token) {
          if (!mounted) return;
          setState(() {
            verificationId = id;
            resendToken = token;
            codeSent = true;
            busy = false;
            errorText = null;
          });
        },
        codeAutoRetrievalTimeout: (String id) {
          verificationId = id;
        },
      );
    } on FirebaseAuthException catch (e) {
      showError(_authError(e));
    } catch (_) {
      showError('تعذر إرسال الرمز. تحقق من الاتصال وإعداد Firebase.');
    }
  }

  Future<void> verifyCode() async {
    final code = otpController.text.trim();
    if (code.length != 6 || verificationId == null) {
      showError('أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }
    setState(() { busy = true; errorText = null; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // AuthGate سيحوّل المستخدم تلقائياً إلى الصفحة الرئيسية.
    } on FirebaseAuthException catch (e) {
      showError(_authError(e));
    } catch (_) {
      showError('حدث خطأ أثناء التحقق. حاول مرة أخرى.');
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صحيح.';
      case 'too-many-requests':
        return 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح.';
      case 'session-expired':
        return 'انتهت صلاحية الرمز. أعد إرسال الرمز.';
      case 'quota-exceeded':
        return 'تم تجاوز حد إرسال الرسائل في Firebase.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بالهاتف غير مفعّل في Firebase.';
      default:
        return e.message ?? 'تعذر إكمال تسجيل الدخول.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 82, height: 82,
                        decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(25)),
                        child: const Icon(Icons.local_taxi_rounded, size: 48, color: ink),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('مشواري', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
                    const SizedBox(height: 6),
                    const Text('سجّل دخولك وابدأ مشوارك', textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 15)),
                    const SizedBox(height: 38),
                    Text(codeSent ? 'أدخل رمز التحقق' : 'رقم هاتفك', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    if (!codeSent) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: const Text('+964', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: InputDecoration(
                                hintText: '7XXXXXXXXX',
                                counterText: '',
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              ),
                              validator: (value) {
                                final v = (value ?? '').trim();
                                if (!RegExp(r'^7[0-9]{9}$').hasMatch(v)) {
                                  return 'أدخل رقم عراقي يبدأ بـ 7 ويتكون من 10 أرقام';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('سنرسل لك رسالة SMS تحتوي على رمز تحقق لتأكيد ملكية الرقم.',
                        style: TextStyle(color: muted, fontSize: 12)),
                    ] else ...[
                      Text('أرسلنا رمزاً إلى $fullPhone', style: const TextStyle(color: muted)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 25, letterSpacing: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '••••••',
                          counterText: '',
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ink, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: busy ? null : (codeSent ? verifyCode : sendCode),
                        child: busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(codeSent ? 'تأكيد الرمز' : 'إرسال رمز التحقق',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (codeSent) ...[
                      TextButton(
                        onPressed: busy ? null : () => setState(() {
                          codeSent = false;
                          verificationId = null;
                          otpController.clear();
                          errorText = null;
                        }),
                        child: const Text('تغيير رقم الهاتف'),
                      ),
                      TextButton(
                        onPressed: busy ? null : sendCode,
                        child: const Text('إعادة إرسال الرمز'),
                      ),
                    ],
                    const SizedBox(height: 28),
                    const Text('بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية.',
                      textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AppMode { passenger, driver }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppMode mode = AppMode.passenger;
  int tab = 0;
  String destination = '';
  String carType = 'اقتصادية';
  bool searching = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> signOut() async => FirebaseAuth.instance.signOut();

  @override
  Widget build(BuildContext context) {
    final isPassenger = mode == AppMode.passenger;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_taxi_rounded, color: ink)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مشواري', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
            Text('مشوارك علينا', style: TextStyle(fontSize: 11, color: muted)),
          ]),
        ]),
        actions: [
          PopupMenuButton<AppMode>(
            onSelected: (v) => setState(() { mode = v; tab = 0; }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: AppMode.passenger, child: Text('وضع الراكب')),
              PopupMenuItem(value: AppMode.driver, child: Text('وضع الكابتن')),
            ],
            child: Chip(
              avatar: Icon(isPassenger ? Icons.person_outline : Icons.drive_eta, size: 18),
              label: Text(isPassenger ? 'راكب' : 'كابتن'),
              backgroundColor: const Color(0xFFFFF1C2), side: BorderSide.none,
            ),
          ),
          IconButton(tooltip: 'تسجيل الخروج', onPressed: signOut, icon: const Icon(Icons.logout)),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: tab, children: [
        isPassenger ? _passengerHome() : _driverHome(),
        _activityPage(),
        _accountPage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'رحلاتي'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _passengerHome() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(24)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('وين تحب نوصلك؟', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: ink)),
          SizedBox(height: 6), Text('احجز رحلتك بسهولة وأمان داخل العراق'),
        ])),
      const SizedBox(height: 16), _mapPlaceholder(),
      const SizedBox(height: 18),
      const Text('حدد وجهتك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      TextField(onChanged: (v) => destination = v,
        decoration: InputDecoration(hintText: 'أدخل المنطقة أو العنوان',
          prefixIcon: const Icon(Icons.location_on_outlined), filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
      const SizedBox(height: 16),
      const Text('اختر نوع السيارة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Row(children: [
        _carChoice('اقتصادية', '🚕', 'سعر مناسب'),
        const SizedBox(width: 8), _carChoice('عائلية', '🚙', 'مساحة أكبر'),
        const SizedBox(width: 8), _carChoice('مميزة', '🚘', 'راحة إضافية'),
      ]),
      const SizedBox(height: 20),
      SizedBox(height: 54, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: searching ? null : () {
          if (destination.trim().isEmpty) { showMessage('يرجى إدخال وجهتك أولاً'); return; }
          setState(() => searching = true);
          showMessage('الواجهة جاهزة، وسيتم ربط الطلب بالسائقين في مرحلة الخادم.');
          Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => searching = false); });
        },
        child: Text(searching ? 'جارٍ تجهيز الطلب...' : 'ابحث عن سيارة',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 14),
      const Text('خدمات مشواري', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Row(children: [
        Expanded(child: ServiceTile(icon: Icons.local_taxi, title: 'تكسي')),
        SizedBox(width: 10), Expanded(child: ServiceTile(icon: Icons.delivery_dining, title: 'توصيل')),
        SizedBox(width: 10), Expanded(child: ServiceTile(icon: Icons.schedule, title: 'حجز مسبق')),
      ]),
    ],
  );

  Widget _carChoice(String title, String emoji, String subtitle) {
    final selected = carType == title;
    return Expanded(child: InkWell(
      onTap: () => setState(() => carType = title),
      borderRadius: BorderRadius.circular(16),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
        decoration: BoxDecoration(color: selected ? const Color(0xFFFFF1C2) : Colors.white,
          border: Border.all(color: selected ? brand : Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 26)), const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: muted)),
        ])),
    ));
  }

  Widget _mapPlaceholder() => Container(
    height: 175,
    decoration: BoxDecoration(color: const Color(0xFFE6E9E5), borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFD9DDD7))),
    child: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: MapPatternPainter())),
      const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on, color: Color(0xFFCA3434), size: 38),
        Text('معاينة الخريطة', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('سيتم ربط خرائط Google لاحقاً', style: TextStyle(color: muted, fontSize: 12)),
      ])),
    ]),
  );

  Widget _driverHome() => ListView(padding: const EdgeInsets.all(18), children: [
    Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(22)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('أهلاً بك يا كابتن', style: TextStyle(color: Colors.white70)),
        SizedBox(height: 8),
        Text('جاهز تستقبل رحلاتك؟', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
        SizedBox(height: 8), Text('فعّل حسابك وابدأ باستقبال طلبات الركاب', style: TextStyle(color: Colors.white70)),
      ])),
    const SizedBox(height: 18),
    const Row(children: [
      Expanded(child: StatCard(title: 'أرباح اليوم', value: '0 د.ع', icon: Icons.account_balance_wallet_outlined)),
      SizedBox(width: 10), Expanded(child: StatCard(title: 'رحلات اليوم', value: '0', icon: Icons.route_outlined)),
    ]),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: const Row(children: [
        Icon(Icons.info_outline, color: muted), SizedBox(width: 10),
        Expanded(child: Text('حساب الكابتن يحتاج إلى إكمال البيانات وموافقة الإدارة قبل استقبال الرحلات.')),
      ])),
    const SizedBox(height: 18), _mapPlaceholder(),
  ]);

  Widget _activityPage() => const Center(child: Text('لا توجد رحلات حتى الآن'));
  Widget _accountPage() => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('حسابي', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    const SizedBox(height: 18),
    const CircleAvatar(radius: 38, backgroundColor: Color(0xFFFFF1C2),
      child: Icon(Icons.person, size: 40, color: ink)),
    const SizedBox(height: 12),
    Center(child: Text(FirebaseAuth.instance.currentUser?.phoneNumber ?? 'مستخدم مشواري',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
    const SizedBox(height: 20),
    const ListTile(leading: Icon(Icons.language), title: Text('اللغة'), trailing: Text('العربية')),
    const ListTile(leading: Icon(Icons.help_outline), title: Text('المساعدة والدعم'), trailing: Text('قريباً')),
    const Center(child: Text('مشواري • إصدار 1.1.0', style: TextStyle(color: muted, fontSize: 12))),
  ]);
}

class ServiceTile extends StatelessWidget {
  final IconData icon; final String title;
  const ServiceTile({super.key, required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [Icon(icon, size: 25), const SizedBox(height: 6),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]));
}

class StatCard extends StatelessWidget {
  final String title, value; final IconData icon;
  const StatCard({super.key, required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: muted), const SizedBox(height: 10),
      Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      Text(title, style: const TextStyle(color: muted, fontSize: 12)),
    ]));
}

class MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = Colors.white..strokeWidth = 13..style = PaintingStyle.stroke;
    final thin = Paint()..color = const Color(0xFFD4DBD2)..strokeWidth = 2;
    final p1 = Path()..moveTo(-10, size.height * .25)..lineTo(size.width * .35, size.height * .4)..lineTo(size.width + 10, size.height * .15);
    final p2 = Path()..moveTo(size.width * .15, size.height + 5)..lineTo(size.width * .48, size.height * .55)..lineTo(size.width * .78, -5);
    final p3 = Path()..moveTo(-5, size.height * .8)..lineTo(size.width * .5, size.height * .72)..lineTo(size.width + 5, size.height * .9);
    canvas.drawPath(p1, road); canvas.drawPath(p2, road); canvas.drawPath(p3, road);
    canvas.drawPath(p1, thin); canvas.drawPath(p2, thin); canvas.drawPath(p3, thin);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
