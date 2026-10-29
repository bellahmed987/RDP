import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'core/api.dart';

const recoveryQuestions = [
  'What was the name of your first school?',
  'What was the name of your first pet?',
  'What city were you born in?',
  'What is your favorite book?',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotifications.initialize();
  runApp(const RdpApp());
}

class PushNotifications {
  static final local = FlutterLocalNotificationsPlugin();
  static bool firebaseReady = false;
  static String? setupIssue;

  static Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await local.initialize(settings: settings);
    const channel = AndroidNotificationChannel(
      'sharekind_updates',
      'ShareKind updates',
      description: 'Requests, messages, and pickup updates',
      importance: Importance.high,
    );
    await local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      firebaseReady = true;
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen((message) async {
        final notification = message.notification;
        if (notification == null) return;
        await local.show(
          id: message.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'sharekind_updates',
              'ShareKind updates',
              channelDescription: 'Requests, messages, and pickup updates',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      });
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _uploadToken(token),
      );
    } catch (error) {
      setupIssue = error.toString();
      debugPrint('Firebase push is not configured: $error');
    }
  }

  static Future<void> registerDevice() async {
    if (!firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _uploadToken(token);
    } catch (error) {
      debugPrint('Could not register push token: $error');
    }
  }

  static Future<void> _uploadToken(String token) async {
    if (Api.instance.dio.options.headers['Authorization'] == null) return;
    try {
      await Api.instance.dio.put(
        '/notifications/device-token',
        data: {'token': token},
      );
    } on DioException catch (error) {
      debugPrint('Could not save push token: ${error.message}');
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}

class RdpApp extends StatelessWidget {
  const RdpApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ShareKind',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff19d5b2),
        brightness: Brightness.dark,
        primary: const Color(0xff20dfbd),
        secondary: const Color(0xffffc66d),
        surface: const Color(0xff171f23),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff0c1114),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff0c1114),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xffedf5f0),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xff151d21),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xff253237)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff151d21),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xff29383c)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xff20dfbd), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xff11181c),
        indicatorColor: const Color(0xff163d38),
        elevation: 8,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xff171f23),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    ),
    home: const Gate(),
  );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Map<String, dynamic>? user;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      await Api.instance.restore();
      user = await Api.instance.me();
      Api.instance.role = user?['role']?.toString();
      Api.instance.userId = (user?['id'] as num?)?.toInt();
    } catch (_) {
      await Api.instance.setToken(null);
    }
    if (mounted) setState(() => loading = false);
  }

  void signedIn(Map<String, dynamic> u) => setState(() {
    user = u;
    Api.instance.role = u['role']?.toString();
    Api.instance.userId = (u['id'] as num?)?.toInt();
  });
  Future<void> signOut() async {
    await Api.instance.setToken(null);
    Api.instance.role = null;
    Api.instance.userId = null;
    setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : user == null
      ? AuthScreen(onSignedIn: signedIn)
      : Home(user: user!, onSignOut: signOut);
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onSignedIn});
  final ValueChanged<Map<String, dynamic>> onSignedIn;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController(),
      city = TextEditingController();
  final recoveryAnswers = List.generate(4, (_) => TextEditingController());
  String role = 'RECIPIENT';
  bool register = false,
      recoveryStep = false,
      busy = false,
      accountCreated = false;
  String? error;

  bool validateAccountDetails() {
    final user = username.text.trim();
    if (name.text.trim().isEmpty ||
        user.length < 3 ||
        user.length > 30 ||
        !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(user) ||
        password.text.length < 10) {
      setState(
        () => error = 'Enter your name, a username of 3–30 letters, numbers or underscores, and a password of at least 10 characters.',
      );
      return false;
    }
    return true;
  }

  void continueToRecovery() {
    if (!validateAccountDetails()) return;
    setState(() {
      recoveryStep = true;
      error = null;
    });
  }

  Future<void> submit() async {
    if (register && !recoveryStep) {
      continueToRecovery();
      return;
    }
    if (register && !validateAccountDetails()) return;
    if (register &&
        recoveryAnswers.any((answer) => answer.text.trim().isEmpty)) {
      setState(() => error = 'Please answer all four recovery questions.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        await Api.instance.register(
          name.text.trim(),
          username.text.trim(),
          password.text,
          role,
          city.text.trim(),
          recoveryAnswers.map((answer) => answer.text.trim()).toList(),
        );
        await Api.instance.setToken(null);
        if (!mounted) return;
        setState(() {
          register = false;
          recoveryStep = false;
          accountCreated = true;
          error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully. Sign in with your username.',
            ),
          ),
        );
      } else {
        final res = await Api.instance.login(
          username.text.trim(),
          password.text,
        );
        await Api.instance.setToken(res['token']);
        widget.onSignedIn(Map<String, dynamic>.from(res['user']));
      }
    } on DioException catch (e) {
      setState(
        () => error = e.response?.data is Map
            ? e.response!.data['message']?.toString() ?? 'Check your details.'
            : 'Cannot reach the server. Start the backend and try again.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xff123a34),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism,
                    size: 40,
                    color: Color(0xff20dfbd),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'ShareKind',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Text(
                  'Good things find good people.',
                  textAlign: TextAlign.center,
                ),
                if (accountCreated) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xff123a34),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Account created successfully. Sign in with your username.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (register && !recoveryStep) ...[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: username,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: '3–30 letters, numbers or _',
                    ),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  DropdownButtonFormField(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Account type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'RECIPIENT',
                        child: Text('Recipient'),
                      ),
                      DropdownMenuItem(value: 'DONOR', child: Text('Donor')),
                    ],
                    onChanged: (v) => setState(() => role = v ?? role),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (10+ characters)',
                    ),
                  ),
                ] else if (register) ...[
                  Text(
                    'Password recovery',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Answer these questions to help recover your account later.',
                  ),
                  for (var i = 0; i < recoveryQuestions.length; i++)
                    TextField(
                      controller: recoveryAnswers[i],
                      decoration: InputDecoration(
                        labelText: recoveryQuestions[i],
                      ),
                    ),
                ] else ...[
                  TextField(
                    controller: username,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                ],
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy
                      ? null
                      : (register && !recoveryStep
                            ? continueToRecovery
                            : submit),
                  child: Text(
                    busy
                        ? 'Please wait…'
                        : register
                        ? recoveryStep
                              ? 'Create account'
                              : 'Next'
                        : 'Sign in',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (register && recoveryStep) {
                      recoveryStep = false;
                    } else {
                      register = !register;
                      recoveryStep = false;
                    }
                    error = null;
                  }),
                  child: Text(
                    register
                        ? (recoveryStep ? 'Back to account details' : 'Sign in')
                        : 'Create an account',
                  ),
                ),
                if (!register)
                  TextButton.icon(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PasswordRecoveryPage(),
                      ),
                    ),
                    icon: const Icon(Icons.lock_reset_outlined),
                    label: const Text('Forgot password?'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.user, required this.onSignOut});
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int index = 0;
  String? adminRoleFilter;
  int unreadNotifications = 0;
  int? latestNotificationId;
  bool notificationBaselineReady = false;
  bool checkingNotifications = false;
  Timer? notificationTimer;
  final myDonationsKey = GlobalKey<_DonationListState>();

  @override
  void initState() {
    super.initState();
    PushNotifications.registerDevice();
    WidgetsBinding.instance.addObserver(this);
    if (!PushNotifications.firebaseReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          snack(
            context,
            'Phone alerts need Firebase setup. See FIREBASE_PUSH_SETUP.md.',
          );
        }
      });
    }
    _refreshNotifications(notifyNew: false);
    notificationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshNotifications(),
    );
  }

  @override
  void dispose() {
    notificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNotifications();
  }

  Future<void> _refreshNotifications({bool notifyNew = true}) async {
    if (checkingNotifications) return;
    checkingNotifications = true;
    try {
      final result = await Api.instance.dio.get('/notifications');
      final rows = (result.data as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();
      final newIds = rows
          .map((row) => row['id'])
          .whereType<num>()
          .map((id) => id.toInt())
          .toList();
      final latest = newIds.isEmpty
          ? null
          : newIds.reduce((a, b) => a > b ? a : b);
      final unread = rows.where((row) => row['read'] != true).length;
      final shouldAnnounce =
          notifyNew &&
          notificationBaselineReady &&
          latest != null &&
          (latestNotificationId == null || latest > latestNotificationId!);
      if (mounted) {
        setState(() => unreadNotifications = unread);
        if (shouldAnnounce) {
          final incoming = rows.where(
            (row) => (row['id'] as num?)?.toInt() == latest,
          );
          if (incoming.isNotEmpty) {
            snack(
              context,
              incoming.first['title']?.toString() ??
                  'You have a new notification.',
            );
          }
        }
      }
      if (latest != null &&
          (latestNotificationId == null || latest > latestNotificationId!)) {
        latestNotificationId = latest;
      }
      notificationBaselineReady = true;
    } on DioException {
      // The notification inbox stays available when the server reconnects.
    } finally {
      checkingNotifications = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'];
    final donor = role == 'DONOR', admin = role == 'ADMIN';
    final labels = admin
        ? ['Overview', 'Accounts', 'Listings', 'Requests', 'Reports']
        : donor
        ? ['Donations', 'Incoming requests', 'Messages', 'Profile']
        : [
            'Explore',
            'My requests',
            'Favorites',
            'For you',
            'Messages',
            'Profile',
          ];
    final pages = admin
        ? [
            AdminPage(
              onNavigate: (destination, roleFilter) => setState(() {
                index = destination;
                adminRoleFilter = roleFilter;
              }),
            ),
            UsersPage(
              key: ValueKey(adminRoleFilter),
              roleFilter: adminRoleFilter,
            ),
            const AdminDonationsPage(),
            const AdminRequestsPage(),
            const AdminReportsPage(),
          ]
        : donor
        ? [
            DonationList(mine: true, key: myDonationsKey),
            const RequestList(incoming: true),
            const ConversationsPage(),
            ProfilePage(user: widget.user),
          ]
        : [
            const DonationList(mine: false),
            const RequestList(incoming: false),
            const FavoritesPage(),
            const RecsPage(),
            const ConversationsPage(),
            ProfilePage(user: widget.user),
          ];
    final icons = admin
        ? [
            Icons.dashboard_rounded,
            Icons.groups_2_rounded,
            Icons.inventory_2_rounded,
            Icons.receipt_long_rounded,
            Icons.flag_rounded,
          ]
        : donor
        ? [
            Icons.inventory_2,
            Icons.inbox,
            Icons.chat_bubble_outline,
            Icons.person,
          ]
        : [
            Icons.explore,
            Icons.inbox,
            Icons.favorite,
            Icons.auto_awesome,
            Icons.chat_bubble_outline,
            Icons.person,
          ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xff123a34),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xff1a655b)),
              ),
              child: const Icon(
                Icons.volunteer_activism,
                size: 20,
                color: Color(0xff20dfbd),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ShareKind',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: unreadNotifications == 0
                ? 'Notifications'
                : '$unreadNotifications unread notifications',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
              _refreshNotifications(notifyNew: false);
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (unreadNotifications > 0)
                  Positioned(
                    right: -7,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        unreadNotifications > 99
                            ? '99+'
                            : '$unreadNotifications',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ShareKind help',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const HelpDialog(),
            ),
            icon: const Icon(Icons.help_outline),
          ),
          if (donor && index == 0)
            IconButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => DonationForm(
                  onSaved: () => myDonationsKey.currentState?.refresh(),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          IconButton(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.025, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          index = i;
          if (admin && i == 1) adminRoleFilter = null;
        }),
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}

class DonationList extends StatefulWidget {
  const DonationList({super.key, required this.mine});
  final bool mine;
  @override
  State<DonationList> createState() => _DonationListState();
}

class _DonationListState extends State<DonationList> {
  final search = TextEditingController();
  String? category;
  double? nearbyLatitude, nearbyLongitude;
  double nearbyRadius = 5;
  bool mapView = false;
  late Future<dynamic> future;
  static const cats = [
    'FOOD',
    'CLOTHING',
    'ELECTRONICS',
    'BOOKS',
    'FURNITURE',
    'TOYS',
    'HOUSEHOLD',
    'OTHER',
  ];
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async {
    final r = widget.mine
        ? await Api.instance.dio.get('/donations/mine')
        : nearbyLatitude != null && nearbyLongitude != null
        ? await Api.instance.dio.get(
            '/donations/nearby',
            queryParameters: {
              'latitude': nearbyLatitude,
              'longitude': nearbyLongitude,
              'radiusKm': nearbyRadius,
              if (category != null) 'category': category,
            },
          )
        : await Api.instance.dio.get(
            '/donations',
            queryParameters: {
              if (search.text.isNotEmpty) 'q': search.text,
              if (category != null) 'category': category,
            },
          );
    return r.data;
  }

  void refresh() {
    if (!mounted) return;
    setState(() => future = load());
  }

  Future<void> chooseNearby() async {
    ll.LatLng? selected = nearbyLatitude != null && nearbyLongitude != null
        ? ll.LatLng(nearbyLatitude!, nearbyLongitude!)
        : null;
    if (!MapTilerMap.enabled) {
      snack(
        context,
        'Configure MAPTILER_API_KEY in mobile/maptiler.env.json to choose a nearby location.',
      );
      return;
    }
    final location = await showDialog<PickedLocation>(
      context: context,
      builder: (_) => MapLocationPicker(initialLocation: selected),
    );
    if (!mounted || location == null) return;
    selected = location.point;
    final radius = TextEditingController(text: nearbyRadius.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nearby resources'),
        content: TextField(
          controller: radius,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Radius in km (up to 100)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Find nearby'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    final parsedRadius = double.tryParse(radius.text);
    if (parsedRadius == null || parsedRadius <= 0 || parsedRadius > 100) {
      snack(context, 'Enter a radius greater than 0 and up to 100 km.');
      return;
    }
    setState(() {
      nearbyLatitude = selected!.latitude;
      nearbyLongitude = selected.longitude;
      nearbyRadius = parsedRadius;
      future = load();
    });
  }

  Widget _categoryChip(String label, String? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: category == value,
      onSelected: (_) {
        setState(() => category = value);
        refresh();
      },
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: category == value
            ? const Color(0xff071512)
            : const Color(0xffadbdc0),
      ),
      backgroundColor: const Color(0xff151d21),
      selectedColor: const Color(0xff20dfbd),
      side: BorderSide(
        color: category == value
            ? const Color(0xff20dfbd)
            : const Color(0xff253237),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  Widget _viewToggle(String label, IconData icon, bool selected) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => setState(() => mapView = label == 'Map'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff20dfbd) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? const Color(0xff071512)
                  : const Color(0xffadbdc0),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xff071512)
                    : const Color(0xffadbdc0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!widget.mine)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: search,
                onSubmitted: (_) => refresh(),
                decoration: InputDecoration(
                  hintText: 'Search baby gear, food, furniture…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: refresh,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _categoryChip('All', null),
                    ...cats.map((x) => _categoryChip(pretty(x), x)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xff151d21),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xff253237)),
                      ),
                      child: Row(
                        children: [
                          _viewToggle(
                            'List',
                            Icons.view_list_rounded,
                            !mapView,
                          ),
                          _viewToggle('Map', Icons.map_outlined, mapView),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: nearbyLatitude == null
                        ? chooseNearby
                        : () {
                            setState(() {
                              nearbyLatitude = null;
                              nearbyLongitude = null;
                              future = load();
                            });
                          },
                    icon: Icon(
                      nearbyLatitude == null
                          ? Icons.near_me_outlined
                          : Icons.close_rounded,
                    ),
                    label: Text(nearbyLatitude == null ? 'Near me' : 'Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      Expanded(
        child: FutureBuilder<dynamic>(
          future: future,
          builder: (c, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return ErrorPane(onRetry: refresh);
            final data = s.data;
            final List items =
                (data is List ? data : (data is Map ? data['items'] ?? [] : []))
                    .where(
                      (x) =>
                          !widget.mine ||
                          (x is Map && x['status'] != 'CANCELLED'),
                    )
                    .toList();
            if (items.isEmpty) {
              return EmptyPane(
                title: widget.mine ? 'No donations yet' : 'No resources found',
                subtitle: widget.mine
                    ? 'Tap + to publish one.'
                    : 'Try another search.',
              );
            }
            if (mapView) {
              if (!MapTilerMap.enabled) {
                return const Center(
                  child: Text('MapTiler key is not configured.'),
                );
              }
              final points = items
                  .where(
                    (x) =>
                        x is Map &&
                        x['latitude'] != null &&
                        x['longitude'] != null,
                  )
                  .toList();
              if (points.isEmpty) {
                return const Center(
                  child: Text('No listings have map locations yet.'),
                );
              }
              return DonationBrowseMap(
                items: points.cast<Map<String, dynamic>>(),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mine
                              ? 'Your listings'
                              : 'Find something useful',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.mine
                              ? 'Manage what you have shared with your community.'
                              : 'Good things are being shared near you.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  ...items.map(
                    (x) => DonationCard(
                      item: Map<String, dynamic>.from(x),
                      isOwner: widget.mine,
                      onChanged: refresh,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final available = status == 'AVAILABLE';
    final reserved = status == 'RESERVED';
    final background = available
        ? const Color(0xff123a34)
        : reserved
        ? const Color(0xff48351f)
        : const Color(0xff303936);
    final foreground = available
        ? const Color(0xff20dfbd)
        : reserved
        ? const Color(0xfff0c47d)
        : const Color(0xffc0cbc4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        pretty(status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Widget _requestStatusBadge(String status) {
  final color = switch (status) {
    'ACCEPTED' => const Color(0xff20dfbd),
    'COMPLETED' => const Color(0xff7bd89c),
    'PENDING' => const Color(0xffffc66d),
    'REJECTED' || 'CANCELLED' => const Color(0xffff8794),
    _ => const Color(0xffaebdc0),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .28)),
    ),
    child: Text(
      pretty(status),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class DonationCard extends StatefulWidget {
  const DonationCard({
    super.key,
    required this.item,
    this.isOwner = false,
    this.onChanged,
  });
  final Map<String, dynamic> item;
  final bool isOwner;
  final VoidCallback? onChanged;
  @override
  State<DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends State<DonationCard> {
  bool favorite = false, savingFavorite = false;
  int photoIndex = 0;
  Map<String, dynamic> get item => widget.item;
  @override
  void initState() {
    super.initState();
    favorite = item['favorite'] == true;
  }

  Future<void> toggleFavorite() async {
    if (savingFavorite) return;
    setState(() => savingFavorite = true);
    try {
      final path = '/favorites/${item['id']}';
      if (favorite) {
        await Api.instance.dio.delete(path);
      } else {
        await Api.instance.dio.post(path);
      }
      if (mounted) setState(() => favorite = !favorite);
    } on DioException catch (e) {
      if (mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not update saved items.',
        );
      }
    } finally {
      if (mounted) setState(() => savingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = (item['imageUrls'] as List? ?? [])
        .whereType<String>()
        .toList();
    final baseUri = Uri.parse(Api.instance.dio.options.baseUrl);
    final status = item['status']?.toString() ?? 'AVAILABLE';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 188,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photos.isNotEmpty)
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (index) =>
                        setState(() => photoIndex = index),
                    itemBuilder: (_, index) => Image.network(
                      baseUri.resolve(photos[index]).toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _photoPlaceholder(),
                    ),
                  )
                else
                  _photoPlaceholder(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black26,
                        Colors.transparent,
                        Colors.black54,
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: _StatusPill(status: status),
                ),
                if (photos.length > 1)
                  Positioned(
                    right: 62,
                    top: 17,
                    child: _imageCountPill(photoIndex + 1, photos.length),
                  ),
                if (Api.instance.role == 'RECIPIENT')
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Material(
                      color: const Color(0xcc101719),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: favorite ? 'Remove saved item' : 'Save item',
                        onPressed: savingFavorite ? null : toggleFavorite,
                        icon: Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: favorite
                              ? const Color(0xffff7c91)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (photos.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 9,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        photos.length.clamp(0, 6),
                        (i) => Container(
                          width: i == photoIndex ? 18 : 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == photoIndex
                                ? const Color(0xff20dfbd)
                                : Colors.white70,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? 'Donation',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (widget.isOwner)
                      PopupMenuButton<String>(
                        tooltip: 'Listing options',
                        onSelected: (choice) =>
                            choice == 'edit' ? edit(context) : delete(context),
                        itemBuilder: (_) => [
                          if (status == 'AVAILABLE')
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit listing'),
                            ),
                          if (status != 'PICKED_UP' && status != 'CANCELLED')
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete listing'),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _detailPill(
                      Icons.category_outlined,
                      pretty(item['category'] ?? 'Item'),
                    ),
                    _detailPill(
                      Icons.inventory_2_outlined,
                      '${item['availableQuantity'] ?? item['quantity'] ?? 1} available',
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Text(
                  item['description'] ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: const Color(0xffaebdc0), height: 1.35),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => viewDonor(context),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xff173b36),
                        child: Text(
                          (item['donorName']?.toString().isNotEmpty ?? false)
                              ? item['donorName']
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: Color(0xff20dfbd),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['donorName'] ?? 'Community donor',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              item['city'] ??
                                  item['donorCity'] ??
                                  item['pickupAddress'] ??
                                  'Location not set',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff91a2a5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item['latitude'] != null && item['longitude'] != null)
                        IconButton(
                          tooltip: 'View pickup map',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => DonationMap(item: item),
                          ),
                          icon: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xff20dfbd),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isOwner &&
                    (item['pickupAddress']?.toString().isNotEmpty ??
                        false)) ...[
                  const SizedBox(height: 8),
                  _detailPill(
                    Icons.place_outlined,
                    item['pickupAddress'].toString(),
                  ),
                ],
                if (!widget.isOwner && status == 'RESERVED')
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Pickup is being arranged',
                      style: TextStyle(
                        color: Color(0xffffc66d),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (!widget.isOwner &&
                    Api.instance.role == 'RECIPIENT' &&
                    status == 'AVAILABLE') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => contactDonor(context),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Message'),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () => request(context),
                          icon: const Icon(Icons.volunteer_activism_rounded),
                          label: const Text('Request item'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
    color: const Color(0xff1a292d),
    alignment: Alignment.center,
    child: const Icon(
      Icons.volunteer_activism_rounded,
      size: 42,
      color: Color(0xff20dfbd),
    ),
  );

  Widget _detailPill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xff202b2f),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xff20dfbd)),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xffd3dfdf),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _imageCountPill(int current, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xcc101719),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$current/$count',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  Future<void> edit(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => DonationForm(donation: item, onSaved: widget.onChanged),
    );
  }

  Future<void> viewDonor(BuildContext context) async {
    final donorId = item['donorId'];
    if (donorId is! int) {
      snack(context, 'Donor profile is unavailable.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DonorProfilePage(donorId: donorId)),
    );
  }

  Future<void> contactDonor(BuildContext context) async {
    try {
      final response = await Api.instance.dio.post(
        '/donations/${item['id']}/conversation',
      );
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversation: Map<String, dynamic>.from(response.data),
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not start a conversation with the donor.',
        );
      }
    }
  }

  Future<void> delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: const Text(
          'The listing will be removed from available resources. Any pending requests will be declined.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep listing'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete listing'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.instance.dio.delete('/donations/${item['id']}');
      widget.onChanged?.call();
      if (context.mounted) snack(context, 'Listing deleted.');
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'This listing could not be deleted.',
        );
      }
    }
  }

  Future<void> request(BuildContext context) async {
    final qty = TextEditingController(text: '1'), msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Request item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              controller: msg,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.dio.post(
        '/donations/${item['id']}/requests',
        data: {'quantity': int.tryParse(qty.text) ?? 1, 'message': msg.text},
      );
      if (context.mounted) snack(context, 'Request sent.');
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Request could not be sent.',
        );
      }
    }
  }
}

List<Widget> _donationPhotoStrip(Map<String, dynamic> item) {
  final paths = (item['imageUrls'] as List? ?? []).whereType<String>().toList();
  if (paths.isEmpty) return const [];
  final baseUri = Uri.parse(Api.instance.dio.options.baseUrl);
  return [
    const SizedBox(height: 12),
    SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            baseUri.resolve(paths[index]).toString(),
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 200,
              height: 150,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    ),
  ];
}

class DonationForm extends StatefulWidget {
  const DonationForm({super.key, this.onSaved, this.donation});
  final VoidCallback? onSaved;
  final Map<String, dynamic>? donation;
  @override
  State<DonationForm> createState() => _DonationFormState();
}

class _DonationFormState extends State<DonationForm> {
  final title = TextEditingController(),
      description = TextEditingController(),
      qty = TextEditingController(text: '1'),
      address = TextEditingController(),
      city = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  final Set<String> uploadedPhotoPaths = {};
  final List<XFile> photos = [];
  ll.LatLng? pickupLocation;
  String cat = 'FOOD', condition = 'GOOD';
  bool busy = false;
  int? createdDonationId;
  bool get isEditing => widget.donation != null;

  @override
  void initState() {
    super.initState();
    final donation = widget.donation;
    if (donation == null) return;
    title.text = donation['title']?.toString() ?? '';
    description.text = donation['description']?.toString() ?? '';
    qty.text = (donation['quantity'] ?? 1).toString();
    address.text = donation['pickupAddress']?.toString() ?? '';
    city.text = donation['city']?.toString() ?? '';
    cat = donation['category']?.toString() ?? cat;
    condition = donation['condition']?.toString() ?? condition;
    final lat = donation['latitude'];
    final lon = donation['longitude'];
    if (lat is num && lon is num) {
      pickupLocation = ll.LatLng(lat.toDouble(), lon.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      createdDonationId != null
          ? 'Finish photo upload'
          : isEditing
          ? 'Edit listing'
          : 'Share a resource',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            DropdownButtonFormField(
              initialValue: cat,
              items: donationCategories
                  .map(
                    (x) => DropdownMenuItem(value: x, child: Text(pretty(x))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => cat = v!),
            ),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Product photos (${(widget.donation?['imageUrls'] as List? ?? []).length + photos.length}/5)',
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      busy ||
                          createdDonationId != null ||
                          photos.length +
                                  (widget.donation?['imageUrls'] as List? ?? [])
                                      .length >=
                              5
                      ? null
                      : pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add photos'),
                ),
              ],
            ),
            if (photos.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(photos.length, (index) {
                  final photo = photos[index];
                  return InputChip(
                    avatar: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(photo.path),
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    label: Text('Photo ${index + 1}'),
                    onDeleted: busy || createdDonationId != null
                        ? null
                        : () => setState(() => photos.removeAt(index)),
                  );
                }),
              ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PNG or JPEG, up to 8 MB each. Maximum 5 photos.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            DropdownButtonFormField(
              initialValue: condition,
              items: const ['NEW', 'LIKE_NEW', 'GOOD', 'FAIR', 'NEEDS_REPAIR']
                  .map(
                    (x) => DropdownMenuItem(value: x, child: Text(pretty(x))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => condition = v!),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Pickup address'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy || createdDonationId != null
                    ? null
                    : choosePickupLocation,
                icon: const Icon(Icons.place_outlined),
                label: Text(
                  pickupLocation == null
                      ? 'Choose pickup point on map'
                      : 'Pickup point selected',
                ),
              ),
            ),
            if (!MapTilerMap.enabled)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Configure MAPTILER_API_KEY in mobile/maptiler.env.json to select a pin.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: 'City'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(
          busy
              ? (createdDonationId == null
                    ? (isEditing ? 'Saving…' : 'Publishing…')
                    : 'Uploading…')
              : (createdDonationId == null
                    ? (isEditing ? 'Save changes' : 'Publish')
                    : 'Retry photo upload'),
        ),
      ),
    ],
  );

  Future<void> choosePickupLocation() async {
    if (!MapTilerMap.enabled) {
      snack(
        context,
        'Configure MAPTILER_API_KEY in mobile/maptiler.env.json to choose a pickup point.',
      );
      return;
    }
    final selected = await showDialog<PickedLocation>(
      context: context,
      builder: (_) => MapLocationPicker(
        initialLocation: pickupLocation,
        requireAddress: true,
      ),
    );
    if (mounted && selected != null) {
      setState(() {
        pickupLocation = selected.point;
        if (selected.address?.isNotEmpty == true) {
          address.text = selected.address!;
        }
      });
    }
  }

  Future<void> pickPhotos() async {
    final remaining =
        5 -
        photos.length -
        (widget.donation?['imageUrls'] as List? ?? []).length;
    if (remaining <= 0) {
      snack(context, 'A donation can have up to 5 photos.');
      return;
    }
    try {
      final picked = await imagePicker.pickMultiImage(
        limit: remaining,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (!mounted || picked.isEmpty) return;
      final accepted = picked.take(remaining).toList();
      final supported = accepted.where((photo) {
        final extension = photo.name.toLowerCase().split('.').last;
        return extension == 'png' || extension == 'jpg' || extension == 'jpeg';
      }).toList();
      setState(() => photos.addAll(supported));
      if (supported.length != accepted.length) {
        snack(context, 'Only PNG and JPEG photos are supported.');
      }
      if (picked.length > remaining) {
        snack(context, 'Only five photos can be added to one donation.');
      }
    } catch (_) {
      if (mounted) snack(context, 'Could not open the photo picker.');
    }
  }

  Future<void> save() async {
    if (busy) return;
    if (createdDonationId == null &&
        MapTilerMap.enabled &&
        pickupLocation == null) {
      snack(context, 'Choose the pickup point on the map before publishing.');
      return;
    }
    if (createdDonationId == null && address.text.trim().isEmpty) {
      snack(context, 'Choose a map location or enter the pickup address.');
      return;
    }
    setState(() => busy = true);
    try {
      if (createdDonationId == null) {
        final payload = {
          'title': title.text.trim(),
          'category': cat,
          'description': description.text.trim(),
          'condition': condition,
          'quantity': int.tryParse(qty.text) ?? 1,
          'pickupAddress': address.text.trim(),
          'city': city.text.trim(),
          if (pickupLocation != null) 'latitude': pickupLocation!.latitude,
          if (pickupLocation != null) 'longitude': pickupLocation!.longitude,
        };
        final response = await Api.instance.dio.request(
          isEditing ? '/donations/${widget.donation!['id']}' : '/donations',
          options: Options(method: isEditing ? 'PUT' : 'POST'),
          data: payload,
        );
        final id = isEditing
            ? widget.donation!['id']
            : (response.data as Map<String, dynamic>)['id'];
        if (id is! int) throw StateError('The donation was not returned.');
        if (mounted) setState(() => createdDonationId = id);
      }
      await uploadPhotos();
      if (mounted) {
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              (createdDonationId == null
                  ? (isEditing
                        ? 'Could not update this listing. Check required fields.'
                        : 'Check required fields.')
                  : 'Listing saved, but a photo could not be uploaded. Tap Retry photo upload.'),
        );
      }
    } on StateError catch (e) {
      if (mounted) snack(context, e.message.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> uploadPhotos() async {
    final donationId = createdDonationId;
    if (donationId == null) return;
    for (final photo in photos) {
      if (uploadedPhotoPaths.contains(photo.path)) continue;
      final extension = photo.name.toLowerCase().split('.').last;
      final subtype = switch (extension) {
        'png' => 'png',
        'jpg' || 'jpeg' => 'jpeg',
        _ => null,
      };
      if (subtype == null) {
        throw StateError('Please choose PNG or JPEG photos.');
      }
      await Api.instance.dio.post(
        '/donations/$donationId/images',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            photo.path,
            filename: photo.name,
            contentType: DioMediaType('image', subtype),
          ),
        }),
      );
      uploadedPhotoPaths.add(photo.path);
    }
  }
}

const donationCategories = [
  'FOOD',
  'CLOTHING',
  'ELECTRONICS',
  'BOOKS',
  'FURNITURE',
  'TOYS',
  'HOUSEHOLD',
  'OTHER',
];

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversation});
  final Map<String, dynamic> conversation;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  WebSocketChannel? channel;
  Timer? messageRefreshTimer;
  bool connected = false;
  String? error;
  bool blockedByMe = false;
  bool blockedYou = false;
  final recorder = AudioRecorder();
  bool recordingVoice = false;
  bool sendingVoice = false;
  String? voiceRecordingPath;
  Duration voiceRecordingDuration = Duration.zero;
  Timer? voiceRecordingTimer;
  RTCPeerConnection? peerConnection;
  MediaStream? localAudio;
  bool callActive = false;
  bool callBusy = false;
  String? callLabel;
  bool incomingCall = false;
  bool micMuted = false;
  bool speakerOn = false;
  String? remoteCallName;
  Map<String, dynamic>? pendingCallOffer;
  Duration callDuration = Duration.zero;
  Timer? callDurationTimer;
  bool remoteCallDescriptionSet = false;
  final List<RTCIceCandidate> pendingIceCandidates = [];
  int get conversationId => widget.conversation['id'] as int;
  @override
  void initState() {
    super.initState();
    load();
    connect();
    loadBlockStatus();
    messageRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) load(silent: true);
    });
  }

  Future<void> loadBlockStatus() async {
    final otherId = (widget.conversation['otherUserId'] as num?)?.toInt();
    if (otherId == null) return;
    try {
      final response = await Api.instance.dio.get('/users/$otherId/block');
      if (mounted)
        setState(() {
          blockedByMe = response.data['blockedByMe'] == true;
          blockedYou = response.data['blockedYou'] == true;
        });
    } on DioException {}
  }

  Future<void> toggleBlock() async {
    final otherId = (widget.conversation['otherUserId'] as num?)?.toInt();
    if (otherId == null) return;
    final willBlock = !blockedByMe;
    if (willBlock) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Block this person?'),
          content: const Text(
            'They will not be able to send you messages, and you will not be able to message them. You can unblock them later from this chat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    try {
      final response = willBlock
          ? await Api.instance.dio.put('/users/$otherId/block')
          : await Api.instance.dio.delete('/users/$otherId/block');
      if (mounted)
        setState(() {
          blockedByMe = response.data['blockedByMe'] == true;
          blockedYou = response.data['blockedYou'] == true;
        });
      if (mounted)
        snack(context, willBlock ? 'Person blocked.' : 'Person unblocked.');
    } on DioException catch (e) {
      if (mounted)
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not update block settings.',
        );
    }
  }

  Future<void> load({bool silent = false}) async {
    try {
      final response = await Api.instance.dio.get(
        '/conversations/$conversationId/messages',
      );
      if (!mounted) return;
      final fetched = (response.data as List)
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      final knownIds = messages.map((message) => message['id']).toSet();
      final added = fetched.any((message) => !knownIds.contains(message['id']));
      final merged = <Object?, Map<String, dynamic>>{
        for (final message in messages) message['id']: message,
        for (final message in fetched) message['id']: message,
      }.values.toList();
      merged.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      setState(() {
        messages
          ..clear()
          ..addAll(merged);
        error = null;
      });
      if (added) _scrollToLatest();
    } on DioException catch (e) {
      if (!silent && mounted) {
        setState(
          () => error =
              e.response?.data?['message']?.toString() ??
              'Could not load chat history.',
        );
      }
    }
  }

  void _upsertMessage(Map<String, dynamic> message) {
    if (!mounted) return;
    final wasNew = !messages.any((m) => m['id'] == message['id']);
    setState(() {
      final index = messages.indexWhere((m) => m['id'] == message['id']);
      if (index < 0) {
        messages.add(message);
      } else {
        messages[index] = message;
      }
      messages.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    });
    if (wasNew) _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> connect() async {
    try {
      final base = Uri.parse(Api.instance.dio.options.baseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws',
        query: null,
      );
      final socket = WebSocketChannel.connect(uri);
      channel = socket;
      await socket.ready;
      final auth =
          Api.instance.dio.options.headers['Authorization']?.toString() ?? '';
      socket.sink.add(
        'CONNECT\naccept-version:1.2\nhost:${uri.host}\nAuthorization:$auth\n\n\u0000',
      );
      socket.stream.listen(
        (frame) {
          final text = frame.toString();
          if (text.startsWith('CONNECTED')) {
            socket.sink.add(
              'SUBSCRIBE\nid:rdp-$conversationId\ndestination:/topic/conversations/$conversationId\nack:auto\n\n\u0000',
            );
            if (mounted) setState(() => connected = true);
          } else if (text.startsWith('MESSAGE')) {
            final split = text.indexOf('\n\n');
            if (split < 0) return;
            final body = text
                .substring(split + 2)
                .replaceAll('\u0000', '')
                .trim();
            try {
              final item = Map<String, dynamic>.from(jsonDecode(body));
              if (item['event'] == 'call') {
                handleCallSignal(item);
              } else if (mounted) {
                _upsertMessage(item);
              }
            } catch (_) {}
          } else if (text.startsWith('ERROR') && mounted) {
            setState(() => error = 'Chat connection rejected. Sign in again.');
          }
        },
        onError: (_) {
          if (mounted) setState(() => connected = false);
        },
        onDone: () {
          if (mounted) setState(() => connected = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => connected = false);
    }
  }

  void send() {
    final body = input.text.trim();
    if (body.isEmpty || !connected || blockedByMe || blockedYou) return;
    channel?.sink.add(
      'SEND\ndestination:/app/chat/$conversationId\ncontent-type:application/json\n\n${jsonEncode({'body': body})}\u0000',
    );
    input.clear();
  }

  void sendCallSignal(String type, [Map<String, dynamic> data = const {}]) {
    if (!connected) return;
    channel?.sink.add(
      'SEND\ndestination:/app/calls/$conversationId\ncontent-type:application/json\n\n${jsonEncode({'signalType': type, 'signal': data})}\u0000',
    );
  }

  Future<RTCPeerConnection> _createCallPeer() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    peerConnection = pc;
    localAudio = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    for (final track in localAudio!.getAudioTracks()) {
      track.enabled = !micMuted;
      await pc.addTrack(track, localAudio!);
    }
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) sendCallSignal('ice', candidate.toMap());
    };
    pc.onConnectionState = (state) {
      if (mounted) {
        setState(() {
          callActive =
              state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
          callLabel = callActive ? 'Voice call connected' : state.name;
          if (callActive && callDurationTimer == null) {
            callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (mounted) {
                setState(() => callDuration += const Duration(seconds: 1));
              }
            });
          }
        });
      }
    };
    return pc;
  }

  Future<void> startCall() async {
    if (blockedByMe || blockedYou || callBusy) return;
    if (!connected) {
      snack(context, 'Connect to chat before calling.');
      return;
    }
    setState(() {
      callBusy = true;
      callLabel = 'Calling…';
      incomingCall = false;
      remoteCallName = widget.conversation['otherUserName']?.toString();
      callDuration = Duration.zero;
    });
    try {
      final pc = await _createCallPeer();
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      sendCallSignal('offer', {'sdp': offer.sdp, 'type': offer.type});
    } catch (e) {
      await _closeCall();
      if (mounted) snack(context, 'Could not start voice call: $e');
    } finally {
      if (mounted) setState(() => callBusy = false);
    }
  }

  Future<void> handleCallSignal(Map<String, dynamic> event) async {
    final peerId = (widget.conversation['otherUserId'] as num?)?.toInt();
    if (peerId == null || (event['senderId'] as num?)?.toInt() != peerId)
      return;
    final type = event['signalType']?.toString();
    final signal = Map<String, dynamic>.from(
      event['signal'] as Map? ?? const {},
    );
    if (type == 'offer') {
      if (callBusy || peerConnection != null) return;
      HapticFeedback.vibrate();
      _startIncomingRingtone();
      pendingCallOffer = signal;
      if (mounted) {
        setState(() {
          callBusy = true;
          incomingCall = true;
          callLabel = 'Incoming call';
          remoteCallName = event['senderName']?.toString() ?? 'ShareKind user';
        });
      }
    } else if (type == 'answer' && peerConnection != null) {
      await peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          signal['sdp']?.toString(),
          signal['type']?.toString(),
        ),
      );
      remoteCallDescriptionSet = true;
      for (final candidate in pendingIceCandidates) {
        await peerConnection!.addCandidate(candidate);
      }
      pendingIceCandidates.clear();
      if (mounted) setState(() => callLabel = 'Connecting voice call…');
    } else if (type == 'ice' && peerConnection != null) {
      final candidate = RTCIceCandidate(
        signal['candidate']?.toString(),
        signal['sdpMid']?.toString(),
        (signal['sdpMLineIndex'] as num?)?.toInt(),
      );
      if (remoteCallDescriptionSet) {
        await peerConnection!.addCandidate(candidate);
      } else {
        pendingIceCandidates.add(candidate);
      }
    } else if (type == 'ice') {
      pendingIceCandidates.add(
        RTCIceCandidate(
          signal['candidate']?.toString(),
          signal['sdpMid']?.toString(),
          (signal['sdpMLineIndex'] as num?)?.toInt(),
        ),
      );
    } else if (type == 'reject') {
      await _closeCall();
      if (mounted) snack(context, 'Call declined.');
    } else if (type == 'end') {
      await _closeCall();
      if (mounted) snack(context, 'Call ended.');
    }
  }

  Future<void> acceptIncomingCall() async {
    await _stopIncomingRingtone();
    final signal = pendingCallOffer;
    if (signal == null) return;
    pendingCallOffer = null;
    setState(() {
      incomingCall = false;
      callLabel = 'Connecting…';
      callDuration = Duration.zero;
    });
    try {
      final pc = await _createCallPeer();
      await pc.setRemoteDescription(
        RTCSessionDescription(
          signal['sdp']?.toString(),
          signal['type']?.toString(),
        ),
      );
      remoteCallDescriptionSet = true;
      for (final candidate in pendingIceCandidates) {
        await pc.addCandidate(candidate);
      }
      pendingIceCandidates.clear();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      sendCallSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
    } catch (e) {
      await _closeCall();
      if (mounted) snack(context, 'Could not answer call: $e');
    }
  }

  Future<void> declineIncomingCall() async {
    await _stopIncomingRingtone();
    pendingCallOffer = null;
    sendCallSignal('reject');
    await _closeCall();
  }

  Future<void> toggleCallMic() async {
    micMuted = !micMuted;
    for (final track in localAudio?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !micMuted;
    }
    if (mounted) setState(() {});
  }

  Future<void> toggleCallSpeaker() async {
    final next = !speakerOn;
    try {
      await Helper.setSpeakerphoneOn(next);
      if (mounted) setState(() => speakerOn = next);
    } catch (e) {
      if (mounted) snack(context, 'Could not change audio output: $e');
    }
  }

  Future<void> endCall() async {
    sendCallSignal('end');
    await _closeCall();
  }

  Future<void> _closeCall() async {
    await _stopIncomingRingtone();
    final pc = peerConnection;
    peerConnection = null;
    await pc?.close();
    final stream = localAudio;
    localAudio = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    remoteCallDescriptionSet = false;
    pendingIceCandidates.clear();
    callDurationTimer?.cancel();
    callDurationTimer = null;
    pendingCallOffer = null;
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
    if (mounted)
      setState(() {
        callActive = false;
        callBusy = false;
        callLabel = null;
        incomingCall = false;
        micMuted = false;
        speakerOn = false;
        callDuration = Duration.zero;
      });
  }

  final AudioPlayer ringtonePlayer = AudioPlayer();

  Future<void> _startIncomingRingtone() async {
    try {
      await ringtonePlayer.setAsset('assets/audio/sharekind_ringtone.wav');
      await ringtonePlayer.setLoopMode(LoopMode.one);
      unawaited(ringtonePlayer.play());
    } catch (error) {
      debugPrint('Could not play the incoming call ringtone: $error');
    }
  }

  Future<void> _stopIncomingRingtone() async {
    try {
      if (ringtonePlayer.playing) await ringtonePlayer.stop();
    } catch (_) {}
  }

  Future<void> toggleVoiceRecording() async {
    if (blockedByMe || blockedYou) return;
    if (recordingVoice) {
      await sendVoiceRecording();
      return;
    }
    if (sendingVoice) return;
    try {
      if (!await recorder.hasPermission()) {
        snack(
          context,
          'Microphone permission is required to record a voice message.',
        );
        return;
      }
      voiceRecordingPath =
          '${Directory.systemTemp.path}/sharekind-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 24000,
        ),
        path: voiceRecordingPath!,
      );
      voiceRecordingDuration = Duration.zero;
      voiceRecordingTimer?.cancel();
      voiceRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted)
          setState(() => voiceRecordingDuration += const Duration(seconds: 1));
      });
      if (mounted) setState(() => recordingVoice = true);
    } catch (e) {
      voiceRecordingPath = null;
      if (mounted) snack(context, 'Could not start recording: $e');
    }
  }

  Future<void> cancelVoiceRecording() async {
    voiceRecordingTimer?.cancel();
    voiceRecordingTimer = null;
    try {
      await recorder.cancel();
    } catch (_) {}
    final path = voiceRecordingPath;
    voiceRecordingPath = null;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    if (mounted)
      setState(() {
        recordingVoice = false;
        voiceRecordingDuration = Duration.zero;
      });
  }

  Future<void> sendVoiceRecording() async {
    voiceRecordingTimer?.cancel();
    voiceRecordingTimer = null;
    if (mounted) setState(() => sendingVoice = true);
    String? path;
    try {
      path = await recorder.stop();
      voiceRecordingPath = null;
      if (mounted) setState(() => recordingVoice = false);
      final filePath = path;
      if (filePath == null) throw StateError('The recording is empty.');
      final response = await Api.instance.dio.post(
        '/conversations/$conversationId/voice',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: 'voice.m4a'),
        }),
      );
      final message = Map<String, dynamic>.from(response.data);
      _upsertMessage(message);
    } catch (e) {
      final data = e is DioException ? e.response?.data : null;
      final serverMessage = data is Map ? data['message']?.toString() : null;
      if (mounted)
        snack(
          context,
          serverMessage ?? 'Could not record or send voice message: $e',
        );
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted)
        setState(() {
          sendingVoice = false;
          recordingVoice = false;
          voiceRecordingDuration = Duration.zero;
        });
    }
  }

  Future<void> shareMyLocation() async {
    if (blockedByMe || blockedYou) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted)
          snack(context, 'Turn on location services to share your location.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          snack(context, 'Allow location access to share your location.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final response = await Api.instance.dio.post(
        '/conversations/$conversationId/location',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      final message = Map<String, dynamic>.from(response.data);
      _upsertMessage(message);
    } on DioException catch (e) {
      if (mounted)
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not share location.',
        );
    }
  }

  void viewLocation(double latitude, double longitude, String title) {
    showDialog<void>(
      context: context,
      builder: (c) => DonationMap(
        item: {'latitude': latitude, 'longitude': longitude, 'title': title},
      ),
    );
  }

  String _messageTime(Map<String, dynamic> message) {
    final sentAt = DateTime.tryParse(message['createdAt']?.toString() ?? '')
        ?.toLocal();
    if (sentAt == null) return '';
    return '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}';
  }

  String get _callTime =>
      '${callDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${callDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Widget _callScreen() {
    final name = remoteCallName ?? 'ShareKind user';
    final status = incomingCall
        ? 'Incoming voice call'
        : callActive
        ? _callTime
        : callLabel ?? 'Connecting…';
    Widget roundControl({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool selected = false,
    }) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          iconSize: 28,
          style: IconButton.styleFrom(
            fixedSize: const Size(64, 64),
            backgroundColor: selected
                ? Colors.white
                : Colors.white.withValues(alpha: .13),
            foregroundColor: selected ? const Color(0xff14221e) : Colors.white,
          ),
          icon: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );

    return Material(
      color: const Color(0xff101a18),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff203b34), Color(0xff101a18), Color(0xff090e0d)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
            child: Column(
              children: [
                const Text(
                  'SHAREKIND  ·  AUDIO CALL',
                  style: TextStyle(
                    color: Colors.white54,
                    letterSpacing: 1.4,
                    fontSize: 12,
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff20dfbd).withValues(alpha: .16),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffa4e5c8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  status,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Spacer(flex: 3),
                if (!incomingCall) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      roundControl(
                        icon: micMuted ? Icons.mic_off : Icons.mic,
                        label: micMuted ? 'Unmute' : 'Mute',
                        selected: micMuted,
                        onTap: toggleCallMic,
                      ),
                      roundControl(
                        icon: speakerOn ? Icons.volume_up : Icons.hearing,
                        label: speakerOn ? 'Speaker' : 'Earpiece',
                        selected: speakerOn,
                        onTap: toggleCallSpeaker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 38),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (incomingCall) ...[
                      _callActionButton(
                        icon: Icons.call_end,
                        label: 'Decline',
                        color: const Color(0xffd94a50),
                        onTap: declineIncomingCall,
                      ),
                      const SizedBox(width: 52),
                      _callActionButton(
                        icon: Icons.call,
                        label: 'Accept',
                        color: const Color(0xff32a36c),
                        onTap: acceptIncomingCall,
                      ),
                    ] else
                      _callActionButton(
                        icon: Icons.call_end,
                        label: callActive ? 'End call' : 'Cancel',
                        color: const Color(0xffd94a50),
                        onTap: endCall,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _callActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filled(
        onPressed: onTap,
        iconSize: 32,
        style: IconButton.styleFrom(
          fixedSize: const Size(72, 72),
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70)),
    ],
  );

  Widget messageContent(Map<String, dynamic> message) {
    final kind = message['kind']?.toString() ?? 'TEXT';
    if (kind == 'VOICE') {
      final path = message['attachmentUrl']?.toString() ?? '';
      return VoiceMessageTile(
        url: Uri.parse(Api.instance.dio.options.baseUrl)
            .resolve(path)
            .toString(),
      );
    }
    if (kind == 'LOCATION' &&
        message['latitude'] is num &&
        message['longitude'] is num) {
      final lat = (message['latitude'] as num).toDouble();
      final lon = (message['longitude'] as num).toDouble();
      return OutlinedButton.icon(
        onPressed: () => viewLocation(lat, lon, 'Shared location'),
        icon: const Icon(Icons.location_on_outlined),
        label: const Text('View shared location'),
      );
    }
    return Text(message['body']?.toString() ?? '');
  }

  @override
  void dispose() {
    channel?.sink.close();
    messageRefreshTimer?.cancel();
    voiceRecordingTimer?.cancel();
    callDurationTimer?.cancel();
    recorder.dispose();
    ringtonePlayer.dispose();
    _closeCall();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: callLabel == null
        ? AppBar(
            title: Row(
              children: [
                _conversationAvatar(
                  widget.conversation['otherUserProfileImageUrl']?.toString(),
                  widget.conversation['otherUserName']?.toString(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.conversation['otherUserName']?.toString() ?? 'Chat',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Start voice call',
                onPressed: blockedByMe || blockedYou ? null : startCall,
                icon: const Icon(Icons.call_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Person options',
                onSelected: (value) async {
                  final otherId = (widget.conversation['otherUserId'] as num?)
                      ?.toInt();
                  if (value == 'report' && otherId != null)
                    await _reportPerson(
                      context,
                      otherId,
                      widget.conversation['otherUserName']?.toString() ??
                          'this person',
                    );
                  if (value == 'block' || value == 'unblock')
                    await toggleBlock();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: ListTile(
                      leading: Icon(Icons.flag_outlined),
                      title: Text('Report person'),
                    ),
                  ),
                  PopupMenuItem(
                    value: blockedByMe ? 'unblock' : 'block',
                    child: ListTile(
                      leading: Icon(
                        blockedByMe ? Icons.person_add_alt_1 : Icons.block,
                      ),
                      title: Text(
                        blockedByMe ? 'Unblock person' : 'Block person',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.conversation['donationTitle']?.toString() ??
                          'Listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      connected
                          ? 'Live chat connected'
                          : 'Connecting to live chat…',
                    ),
                  ],
                ),
              ),
            ),
          )
        : null,
    body: Stack(
      children: [
        Column(
          children: [
            if (widget.conversation['pickupLatitude'] is num &&
                widget.conversation['pickupLongitude'] is num)
              MaterialBanner(
                leading: const Icon(Icons.location_on_outlined),
                content: Text(
                  'Pickup location: ${widget.conversation['pickupAddress'] ?? widget.conversation['donationTitle'] ?? 'Donation'}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => viewLocation(
                      (widget.conversation['pickupLatitude'] as num).toDouble(),
                      (widget.conversation['pickupLongitude'] as num)
                          .toDouble(),
                      widget.conversation['donationTitle']?.toString() ??
                          'Pickup location',
                    ),
                    child: const Text('View map'),
                  ),
                ],
              ),
            if (blockedByMe || blockedYou)
              MaterialBanner(
                leading: const Icon(Icons.block),
                content: Text(
                  blockedByMe
                      ? 'You blocked this person. Messaging is paused.'
                      : 'This person blocked you. Messaging is unavailable.',
                ),
                actions: [
                  if (blockedByMe)
                    TextButton(
                      onPressed: toggleBlock,
                      child: const Text('Unblock'),
                    ),
                ],
              ),
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(12),
                children: messages.map((m) {
                  final mine =
                      (m['senderId'] as num?)?.toInt() == Api.instance.userId;
                  final bubbleColor = mine
                      ? const Color(0xff138f7a)
                      : const Color(0xff26332f);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .80,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 5),
                              bottomRight: Radius.circular(mine ? 5 : 18),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(13, 9, 10, 6),
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(color: Colors.white),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!mine)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        m['senderName']?.toString() ??
                                            'Participant',
                                        style: const TextStyle(
                                          color: Color(0xffa4e5c8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  messageContent(m),
                                  const SizedBox(height: 3),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _messageTime(m),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (mine) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            m['readAt'] == null
                                                ? Icons.check
                                                : Icons.done_all,
                                            size: 14,
                                            color: m['readAt'] == null
                                                ? Colors.white60
                                                : const Color(0xff7ed5ff),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recordingVoice)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.fiber_manual_record,
                              color: Colors.red,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recording  ${voiceRecordingDuration.inMinutes.toString().padLeft(2, '0')}:${voiceRecordingDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: cancelVoiceRecording,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Discard'),
                            ),
                            FilledButton.icon(
                              onPressed: sendingVoice
                                  ? null
                                  : sendVoiceRecording,
                              icon: const Icon(Icons.send_rounded),
                              label: const Text('Send'),
                            ),
                          ],
                        ),
                      ),
                    if (!recordingVoice)
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Record voice message',
                            onPressed: blockedByMe || blockedYou || sendingVoice
                                ? null
                                : toggleVoiceRecording,
                            icon: const Icon(Icons.mic_none_rounded),
                          ),
                          IconButton(
                            tooltip: 'Share current location',
                            onPressed: blockedByMe || blockedYou
                                ? null
                                : shareMyLocation,
                            icon: const Icon(Icons.add_location_alt_outlined),
                          ),
                          Expanded(
                            child: TextField(
                              controller: input,
                              onSubmitted: (_) => send(),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: connected && !blockedByMe && !blockedYou
                                ? send
                                : null,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (callLabel != null) Positioned.fill(child: _callScreen()),
      ],
    ),
  );
}

class VoiceMessageTile extends StatefulWidget {
  const VoiceMessageTile({super.key, required this.url});
  final String url;
  @override
  State<VoiceMessageTile> createState() => _VoiceMessageTileState();
}

class _VoiceMessageTileState extends State<VoiceMessageTile> {
  final player = AudioPlayer();
  bool failed = false;
  Future<void> toggle() async {
    try {
      if (player.playing) {
        await player.pause();
        return;
      }
      if (player.processingState == ProcessingState.idle ||
          player.processingState == ProcessingState.completed) {
        final token = await Api.storage.read(key: 'access_token');
        await player.setUrl(
          widget.url,
          headers: token == null ? {} : {'Authorization': 'Bearer $token'},
        );
      }
      await player.play();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: failed ? null : toggle,
        icon: Icon(
          player.playing
              ? Icons.pause_circle_outline
              : Icons.play_circle_outline,
          size: 30,
        ),
      ),
      StreamBuilder<Duration?>(
        stream: player.durationStream,
        builder: (context, snapshot) => Text(
          failed
              ? 'Audio unavailable'
              : 'Voice message · ${snapshot.data?.inSeconds ?? 0}s',
        ),
      ),
    ],
  );
}

class PickedLocation {
  const PickedLocation({required this.point, this.address});
  final ll.LatLng point;
  final String? address;
}

class MapTilerMap {
  static const apiKey = String.fromEnvironment('MAPTILER_API_KEY');
  static bool get enabled => apiKey.isNotEmpty;

  static fmap.TileLayer get tileLayer => fmap.TileLayer(
    urlTemplate:
        'https://api.maptiler.com/maps/streets-v4/256/{z}/{x}/{y}.png?key=$apiKey',
    userAgentPackageName: 'edu.rdp.resource_distribution_app',
    maxNativeZoom: 20,
  );

  static Widget get attribution => const fmap.RichAttributionWidget(
    attributions: [
      fmap.TextSourceAttribution('© MapTiler © OpenStreetMap contributors'),
    ],
  );
}

class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({
    super.key,
    this.initialLocation,
    this.requireAddress = false,
  });
  final ll.LatLng? initialLocation;
  final bool requireAddress;
  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  static const fallback = ll.LatLng(24.8607, 67.0011);
  static const _searchUserAgent =
      'flutter_map (edu.rdp.resource_distribution_app)';
  final searchController = TextEditingController();
  final mapController = fmap.MapController();
  final geocodingClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {'User-Agent': _searchUserAgent},
    ),
  );
  List<Map<String, dynamic>> searchResults = [];
  bool searching = false;
  bool mapReady = false;
  String? searchError;
  String? selectedAddress;
  bool resolvingAddress = false;
  late ll.LatLng selected = widget.initialLocation ?? fallback;
  late bool hasSelection = widget.initialLocation != null;

  @override
  void dispose() {
    searchController.dispose();
    geocodingClient.close();
    mapController.dispose();
    super.dispose();
  }

  Future<void> searchPlaces() async {
    final query = searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        searchResults = [];
        searchError = 'Enter at least 2 characters to search.';
      });
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      searching = true;
      searchError = null;
      searchResults = [];
    });
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'api.maptiler.com',
        pathSegments: ['geocoding', '$query.json'],
        queryParameters: {
          'key': MapTilerMap.apiKey,
          'limit': '5',
          'autocomplete': 'true',
          'language': 'en',
          'proximity': '${selected.longitude},${selected.latitude}',
        },
      );
      final response = await geocodingClient.getUri(uri);
      final features = response.data is Map ? response.data['features'] : null;
      final results = features is List
          ? features.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        searchResults = results;
        if (results.isEmpty) {
          searchError = 'No places found. Try another search.';
        }
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        searchError =
            'Location search failed. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  void choosePlace(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    if (coordinates is! List || coordinates.length < 2) return;
    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (longitude is! num || latitude is! num) return;
    final point = ll.LatLng(latitude.toDouble(), longitude.toDouble());
    setState(() {
      selected = point;
      hasSelection = true;
      searchResults = [];
      searchError = null;
      selectedAddress =
          feature['place_name']?.toString() ?? feature['text']?.toString();
      searchController.text = selectedAddress ?? '';
    });
    if (mapReady) mapController.move(point, 15);
  }

  Future<String?> reverseGeocode(ll.LatLng point) async {
    final uri = Uri(
      scheme: 'https',
      host: 'api.maptiler.com',
      pathSegments: ['geocoding', '${point.longitude},${point.latitude}.json'],
      queryParameters: {
        'key': MapTilerMap.apiKey,
        'limit': '1',
        'language': 'en',
      },
    );
    final response = await geocodingClient.getUri(uri);
    final features = response.data is Map ? response.data['features'] : null;
    if (features is! List || features.isEmpty || features.first is! Map) {
      return null;
    }
    final feature = Map<String, dynamic>.from(features.first as Map);
    final name = feature['place_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final text = feature['text']?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> useSelectedLocation() async {
    if (resolvingAddress) return;
    var address = selectedAddress;
    if (address == null || address.isEmpty) {
      if (!widget.requireAddress) {
        Navigator.pop(context, PickedLocation(point: selected));
        return;
      }
      setState(() {
        resolvingAddress = true;
        searchError = null;
      });
      try {
        address = await reverseGeocode(selected);
      } on DioException {
        address = null;
      } finally {
        if (mounted) setState(() => resolvingAddress = false);
      }
    }
    if (!mounted) return;
    if (address == null || address.isEmpty) {
      setState(() {
        searchError = 'Could not find an address for this point. Search for a place or tap a nearby street.';
      });
      return;
    }
    Navigator.pop(context, PickedLocation(point: selected, address: address));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose pickup point'),
    content: SizedBox(
      width: 520,
      height: 470,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => searchPlaces(),
            decoration: InputDecoration(
              hintText: 'Search for a city, area, or address',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Search places',
                      onPressed: searchPlaces,
                      icon: const Icon(Icons.arrow_forward),
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          if (searchResults.isNotEmpty)
            SizedBox(
              height: searchResults.length > 1 ? 108 : 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: searchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  final label =
                      result['place_name']?.toString() ??
                      result['text']?.toString() ??
                      'Unknown place';
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => choosePlace(result),
                  );
                },
              ),
            )
          else if (searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                searchError!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              'Choose a result or tap a spot on the map. Search by MapTiler.',
            ),
          ),
          Expanded(
            child: fmap.FlutterMap(
              mapController: mapController,
              options: fmap.MapOptions(
                initialCenter: selected,
                initialZoom: 13,
                onMapReady: () {
                  mapReady = true;
                },
                onTap: (_, point) => setState(() {
                  selected = point;
                  selectedAddress = null;
                  searchController.clear();
                  searchError = null;
                  hasSelection = true;
                }),
              ),
              children: [
                MapTilerMap.tileLayer,
                fmap.MarkerLayer(
                  markers: [
                    fmap.Marker(
                      point: selected,
                      width: 44,
                      height: 48,
                      child: const Icon(
                        Icons.location_pin,
                        color: Color(0xff138f7a),
                        size: 44,
                      ),
                    ),
                  ],
                ),
                MapTilerMap.attribution,
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${selected.latitude.toStringAsFixed(5)}, ${selected.longitude.toStringAsFixed(5)}',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: hasSelection && !resolvingAddress
            ? useSelectedLocation
            : null,
        child: Text(
          resolvingAddress ? 'Finding address…' : 'Use this location',
        ),
      ),
    ],
  );
}

class DonationBrowseMap extends StatelessWidget {
  const DonationBrowseMap({super.key, required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    final points = items
        .map(
          (item) => ll.LatLng(
            (item['latitude'] as num).toDouble(),
            (item['longitude'] as num).toDouble(),
          ),
        )
        .toList();
    return fmap.FlutterMap(
      options: fmap.MapOptions(
        initialCenter: points.first,
        initialZoom: 11,
        initialCameraFit: points.length > 1
            ? fmap.CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(48),
                maxZoom: 12,
              )
            : null,
      ),
      children: [
        MapTilerMap.tileLayer,
        fmap.MarkerLayer(
          markers: List.generate(items.length, (index) {
            final item = items[index];
            return fmap.Marker(
              point: points[index],
              width: 42,
              height: 48,
              child: Tooltip(
                message:
                    '${item['title'] ?? 'Resource'} · ${item['city'] ?? ''}',
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xff138f7a),
                  size: 42,
                ),
              ),
            );
          }),
        ),
        MapTilerMap.attribution,
      ],
    );
  }
}

class DonationMap extends StatelessWidget {
  const DonationMap({super.key, required this.item});
  final Map<String, dynamic> item;
  static bool get enabled => MapTilerMap.enabled;
  @override
  Widget build(BuildContext context) {
    final point = ll.LatLng(
      (item['latitude'] as num).toDouble(),
      (item['longitude'] as num).toDouble(),
    );
    return AlertDialog(
      title: Text(item['title']?.toString() ?? 'Pickup location'),
      content: SizedBox(
        width: 500,
        height: 380,
        child: enabled
            ? fmap.FlutterMap(
                options: fmap.MapOptions(initialCenter: point, initialZoom: 14),
                children: [
                  MapTilerMap.tileLayer,
                  fmap.MarkerLayer(
                    markers: [
                      fmap.Marker(
                        point: point,
                        width: 44,
                        height: 48,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xff138f7a),
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                  MapTilerMap.attribution,
                ],
              )
            : Center(
                child: Text(
                  '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class RequestList extends StatefulWidget {
  const RequestList({super.key, required this.incoming});
  final bool incoming;
  @override
  State<RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<RequestList> {
  late Future<dynamic> future;
  final Set<dynamic> ratedRequests = {};
  final Set<dynamic> busyRequests = {};
  String statusFilter = 'ALL';
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async => (await Api.instance.dio.get(
    widget.incoming ? '/requests/incoming' : '/requests/mine',
  )).data;
  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final allRows = (s.data as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      final rows = statusFilter == 'ALL'
          ? allRows
          : allRows.where((r) => r['status'] == statusFilter).toList();
      if (allRows.isEmpty) {
        return const EmptyPane(
          title: 'No requests',
          subtitle: 'Requests appear here.',
        );
      }
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          children: [
            _AdminSectionHeading(
              title: widget.incoming ? 'Incoming requests' : 'My requests',
              subtitle: widget.incoming
                  ? 'Review people requesting your donations.'
                  : 'Track requests through pickup.',
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                          'ALL',
                          'PENDING',
                          'ACCEPTED',
                          'COMPLETED',
                          'CANCELLED',
                          'REJECTED',
                        ]
                        .map(
                          (v) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                v == 'ALL'
                                    ? 'All'
                                    : v == 'ACCEPTED'
                                    ? 'Accepted / ongoing'
                                    : pretty(v),
                              ),
                              selected: statusFilter == v,
                              onSelected: (_) =>
                                  setState(() => statusFilter = v),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            if (rows.isEmpty)
              const EmptyPane(
                title: 'No matching requests',
                subtitle: 'Choose another status filter.',
              ),
            ...rows.map((x) {
              final r = Map<String, dynamic>.from(x);
              final status = r['status'];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xff123a34),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: Color(0xff20dfbd),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['donationTitle'] ?? 'Donation',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.incoming ? (r['recipientName'] ?? 'Recipient') : (r['donorName'] ?? 'Donor')} · ${r['quantity'] ?? 1} item(s)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xff9eafb2),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _requestStatusBadge(status?.toString() ?? 'PENDING'),
                        ],
                      ),
                      if (status == 'ACCEPTED' &&
                          (r['pickupAddress']?.toString().isNotEmpty ??
                              false)) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xff202b2f),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xff20dfbd),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r['pickupAddress'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xffd3dfdf),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (status == 'PENDING' && widget.incoming)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busyRequests.contains(r['id'])
                                    ? null
                                    : () => decide(r['id'], 'REJECTED'),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: busyRequests.contains(r['id'])
                                    ? null
                                    : () => decide(r['id'], 'ACCEPTED'),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Accept request'),
                              ),
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (status == 'ACCEPTED' || status == 'COMPLETED')
                              OutlinedButton.icon(
                                onPressed: () => openChat(context, r['id']),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                ),
                                label: const Text('Message'),
                              ),
                            if (widget.incoming && status == 'ACCEPTED')
                              FilledButton.icon(
                                onPressed: () => complete(r['id']),
                                icon: const Icon(Icons.done_all_rounded),
                                label: const Text('Mark picked up'),
                              ),
                            if (!widget.incoming &&
                                status == 'COMPLETED' &&
                                !ratedRequests.contains(r['id']))
                              OutlinedButton.icon(
                                onPressed: () => rate(context, r['id']),
                                icon: const Icon(Icons.star_outline_rounded),
                                label: const Text('Rate donor'),
                              ),
                            if (status == 'PENDING' && !widget.incoming)
                              TextButton.icon(
                                onPressed: busyRequests.contains(r['id'])
                                    ? null
                                    : () => cancel(r['id']),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel request'),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
  Future<void> decide(dynamic id, String status) async {
    await _requestAction(
      id,
      () => Api.instance.dio.patch(
        '/requests/$id/decision',
        data: {'status': status},
      ),
      status == 'ACCEPTED' ? 'Request accepted.' : 'Request rejected.',
    );
  }

  Future<void> complete(dynamic id) async {
    await _requestAction(
      id,
      () => Api.instance.dio.patch('/requests/$id/complete'),
      'Pickup marked complete.',
    );
  }

  Future<void> cancel(dynamic id) => _requestAction(
    id,
    () => Api.instance.dio.patch('/requests/$id/cancel'),
    'Request cancelled.',
  );
  Future<void> _requestAction(
    dynamic id,
    Future<dynamic> Function() action,
    String message,
  ) async {
    setState(() => busyRequests.add(id));
    try {
      await action();
      await refresh();
      if (mounted) snack(context, message);
    } on DioException catch (e) {
      if (mounted)
        snack(
          context,
          e.response?.data is Map
              ? e.response?.data['message']?.toString() ??
                    'Request action failed.'
              : 'Request action failed.',
        );
    } finally {
      if (mounted) setState(() => busyRequests.remove(id));
    }
  }

  Future<void> openChat(BuildContext context, dynamic requestId) async {
    try {
      final response = await Api.instance.dio.post(
        '/requests/$requestId/conversation',
      );
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversation: Map<String, dynamic>.from(response.data),
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ?? 'Chat is unavailable.',
        );
      }
    }
  }

  Future<void> rate(BuildContext context, dynamic requestId) async {
    var score = 5;
    final review = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Rate your pickup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: score,
                items: List.generate(5, (i) => 5 - i)
                    .map(
                      (n) =>
                          DropdownMenuItem(value: n, child: Text('$n stars')),
                    )
                    .toList(),
                onChanged: (v) => update(() => score = v ?? score),
              ),
              TextField(
                controller: review,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Optional review'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) return;
    try {
      await Api.instance.dio.post(
        '/requests/$requestId/rating',
        data: {'score': score, 'review': review.text},
      );
      if (mounted) setState(() => ratedRequests.add(requestId));
      if (context.mounted) snack(context, 'Thank you for your rating.');
    } on DioException catch (e) {
      if (context.mounted) {
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not submit your rating.',
        );
      }
    }
  }
}

Widget _conversationAvatar(String? path, String? name) {
  final url = path == null || path.isEmpty
      ? null
      : Uri.parse(Api.instance.dio.options.baseUrl).resolve(path).toString();
  return CircleAvatar(
    backgroundImage: url == null ? null : NetworkImage(url),
    child: url == null
        ? Text(name != null && name.isNotEmpty ? name[0].toUpperCase() : '?')
        : null,
  );
}

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});
  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late Future<dynamic> future;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    future = load();
    refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) => refresh());
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/conversations')).data;

  void refresh() => setState(() => future = load());

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorPane(onRetry: refresh);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final conversations = snapshot.data as List;
      if (conversations.isEmpty) {
        return const EmptyPane(
          title: 'No messages yet',
          subtitle: 'Message a donor from a listing to start a conversation.',
        );
      }
      return RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: conversations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final conversation = Map<String, dynamic>.from(
              conversations[index],
            );
            final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
            final lastMessage = conversation['lastMessage']?.toString();
            return Card(
              child: ListTile(
                leading: _conversationAvatar(
                  conversation['otherUserProfileImageUrl']?.toString(),
                  conversation['otherUserName']?.toString(),
                ),
                title: Text(
                  conversation['otherUserName']?.toString() ?? 'Conversation',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conversation['donationTitle']?.toString() ?? 'Listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      lastMessage?.isNotEmpty == true
                          ? lastMessage!
                          : 'Start a conversation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread > 0 ? FontWeight.w600 : null,
                        color: unread > 0
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unread > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(conversation: conversation),
                    ),
                  );
                  if (mounted) refresh();
                },
              ),
            );
          },
        ),
      );
    },
  );
}

class DonorProfilePage extends StatefulWidget {
  const DonorProfilePage({super.key, required this.donorId});
  final int donorId;
  @override
  State<DonorProfilePage> createState() => _DonorProfilePageState();
}

class _DonorProfilePageState extends State<DonorProfilePage> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = Api.instance.dio
        .get('/donors/${widget.donorId}/profile')
        .then((response) => response.data);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Donor profile')),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorPane(
            onRetry: () => setState(() {
              future = Api.instance.dio
                  .get('/donors/${widget.donorId}/profile')
                  .then((response) => response.data);
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final donor = Map<String, dynamic>.from(snapshot.data);
        final name = donor['name']?.toString() ?? 'Donor';
        final imagePath = donor['profileImageUrl']?.toString();
        final imageUrl = imagePath == null || imagePath.isEmpty
            ? null
            : Uri.parse(Api.instance.dio.options.baseUrl)
                  .resolve(imagePath)
                  .toString();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
              child: imageUrl == null
                  ? Text(name.characters.first.toUpperCase())
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              donor['city']?.toString().isNotEmpty == true
                  ? donor['city'].toString()
                  : 'City not provided',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: const Text('Listings shared'),
                trailing: Text('${donor['listingsPosted'] ?? 0}'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Pickups completed'),
                trailing: Text('${donor['pickupsCompleted'] ?? 0}'),
              ),
            ),
            if (donor['joinedAt'] != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Member since'),
                  trailing: Text(donor['joinedAt'].toString().split('T').first),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _reportPerson(context, widget.donorId, name),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report this person'),
            ),
          ],
        );
      },
    ),
  );
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = Api.instance.dio.get('/favorites').then((r) => r.data);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) => s.hasError
        ? ErrorPane(
            onRetry: () => setState(
              () => future = Api.instance.dio
                  .get('/favorites')
                  .then((r) => r.data),
            ),
          )
        : !s.hasData
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: (s.data as List)
                .map((x) => DonationCard(item: Map<String, dynamic>.from(x)))
                .toList(),
          ),
  );
}

class RecsPage extends StatefulWidget {
  const RecsPage({super.key});
  @override
  State<RecsPage> createState() => _RecsPageState();
}

class _RecsPageState extends State<RecsPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = Api.instance.dio.get('/recommendations').then((r) => r.data);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) => s.hasError
        ? ErrorPane(
            onRetry: () => setState(
              () => future = Api.instance.dio
                  .get('/recommendations')
                  .then((r) => r.data),
            ),
          )
        : !s.hasData
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: (s.data as List)
                .map((x) => DonationCard(item: Map<String, dynamic>.from(x)))
                .toList(),
          ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Map<String, dynamic> user;
  bool uploading = false;
  @override
  void initState() {
    super.initState();
    user = Map<String, dynamic>.from(widget.user);
  }

  String? get imageUrl {
    final path = user['profileImageUrl']?.toString();
    if (path == null || path.isEmpty) return null;
    return Uri.parse(Api.instance.dio.options.baseUrl).resolve(path).toString();
  }

  Future<void> changePhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image == null || !mounted) return;
    setState(() => uploading = true);
    try {
      final response = await Api.instance.dio.post(
        '/profile/photo',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        }),
      );
      if (mounted) {
        setState(() => user = Map<String, dynamic>.from(response.data));
        snack(context, 'Profile photo updated.');
      }
    } on DioException catch (e) {
      if (mounted)
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not upload your photo.',
        );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Center(
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundImage: imageUrl == null
                  ? null
                  : NetworkImage(imageUrl!),
              onBackgroundImageError: imageUrl == null ? null : (_, _) {},
              child: imageUrl == null
                  ? Text(
                      (user['name'] ?? '?')[0].toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            CircleAvatar(
              radius: 18,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Change profile photo',
                onPressed: uploading ? null : changePhoto,
                icon: uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined, size: 18),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: uploading ? null : changePhoto,
        icon: const Icon(Icons.photo_camera_back_outlined),
        label: Text(
          uploading ? 'Uploading photo…' : 'Add or change profile photo',
        ),
      ),
      Text(
        user['name'] ?? '',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        user['username'] ?? user['email'] ?? '',
        textAlign: TextAlign.center,
      ),
      Text(
        '${user['role']} · ${user['city'] ?? 'City not set'}',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const SecurityQuestionsSetupPage()),
        ),
        icon: const Icon(Icons.lock_reset_outlined),
        label: const Text('Set or update password recovery answers'),
      ),
    ],
  );
}

class SecurityQuestionsSetupPage extends StatefulWidget {
  const SecurityQuestionsSetupPage({super.key});
  @override
  State<SecurityQuestionsSetupPage> createState() =>
      _SecurityQuestionsSetupPageState();
}

class _SecurityQuestionsSetupPageState
    extends State<SecurityQuestionsSetupPage> {
  final currentPassword = TextEditingController();
  final answers = List.generate(4, (_) => TextEditingController());
  bool busy = false;
  String? error;

  @override
  void dispose() {
    currentPassword.dispose();
    for (final answer in answers) {
      answer.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (currentPassword.text.isEmpty ||
        answers.any((answer) => answer.text.trim().isEmpty)) {
      setState(
        () => error = 'Enter your current password and all four answers.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.instance.dio.put(
        '/auth/security-questions',
        data: {
          'currentPassword': currentPassword.text,
          'answer1': answers[0].text.trim(),
          'answer2': answers[1].text.trim(),
          'answer3': answers[2].text.trim(),
          'answer4': answers[3].text.trim(),
        },
      );
      if (mounted) {
        snack(context, 'Password recovery answers saved.');
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => error = e.response?.data is Map
              ? e.response!.data['message']?.toString() ??
                    'Could not save answers.'
              : 'Cannot reach the server.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Password recovery')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Choose answers you can remember. Your answers are stored as protected hashes. You will need all four to reset your password.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: currentPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        for (var i = 0; i < recoveryQuestions.length; i++)
          TextField(
            controller: answers[i],
            decoration: InputDecoration(labelText: recoveryQuestions[i]),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save recovery answers'),
        ),
      ],
    ),
  );
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});
  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final username = TextEditingController();
  final answers = List.generate(4, (_) => TextEditingController());
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool busy = false;
  bool completed = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    for (final answer in answers) {
      answer.dispose();
    }
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> reset() async {
    if (newPassword.text.length < 10 || newPassword.text.length > 72) {
      setState(() => error = 'Choose a password between 10 and 72 characters.');
      return;
    }
    if (newPassword.text != confirmPassword.text) {
      setState(() => error = 'The new passwords do not match.');
      return;
    }
    if (answers.any((answer) => answer.text.trim().isEmpty)) {
      setState(() => error = 'Please answer all four recovery questions.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.instance.dio.post(
        '/auth/password/reset',
        data: {
          'username': username.text.trim(),
          'answer1': answers[0].text.trim(),
          'answer2': answers[1].text.trim(),
          'answer3': answers[2].text.trim(),
          'answer4': answers[3].text.trim(),
          'newPassword': newPassword.text,
        },
      );
      if (mounted) setState(() => completed = true);
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => error = e.response?.data is Map
              ? e.response!.data['message']?.toString() ??
                    'Could not reset password.'
              : 'Cannot reach the server.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: completed
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 54),
                  const SizedBox(height: 12),
                  const Text('Password updated. You can sign in now.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Enter your username and the four answers you saved when setting up recovery.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              for (var i = 0; i < recoveryQuestions.length; i++)
                TextField(
                  controller: answers[i],
                  decoration: InputDecoration(labelText: recoveryQuestions[i]),
                ),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (10–72 characters)',
                ),
              ),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : reset,
                child: Text(
                  busy ? 'Checking answers…' : 'Verify answers and reset',
                ),
              ),
            ],
          ),
  );
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, this.onNavigate});
  final void Function(int destination, String? roleFilter)? onNavigate;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<dynamic> future;
  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/admin/stats')).data;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final stats = Map<String, dynamic>.from(s.data as Map);
      final metrics = <(String, String, IconData, int, String?)>[
        ('totalUsers', 'Community members', Icons.groups_2_outlined, 1, null),
        ('donors', 'Donors', Icons.volunteer_activism_outlined, 1, 'DONOR'),
        ('recipients', 'Recipients', Icons.people_alt_outlined, 1, 'RECIPIENT'),
        (
          'activeUsers',
          'Active accounts',
          Icons.verified_user_outlined,
          1,
          null,
        ),
        ('totalDonations', 'All listings', Icons.inventory_2_outlined, 2, null),
        (
          'availableDonations',
          'Available now',
          Icons.storefront_outlined,
          2,
          null,
        ),
        (
          'completedDonations',
          'Completed pickups',
          Icons.task_alt_outlined,
          2,
          null,
        ),
        ('totalRequests', 'All requests', Icons.receipt_long_outlined, 3, null),
        (
          'pendingRequests',
          'Pending requests',
          Icons.mark_email_unread_outlined,
          3,
          null,
        ),
        ('openReports', 'Open reports', Icons.flag_outlined, 4, null),
      ];
      final categories =
          (stats['donationsByCategory'] as List? ?? const [])
              .map((raw) => Map<String, dynamic>.from(raw as Map))
              .toList()
            ..sort((a, b) => (b['count'] as num).compareTo(a['count'] as num));
      final largest = categories.fold<int>(1, (current, category) {
        final count = (category['count'] as num?)?.toInt() ?? 0;
        return count > current ? count : current;
      });
      return RefreshIndicator(
        onRefresh: () async => setState(() => future = load()),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff21483a), Color(0xff192823)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADMIN CONSOLE',
                          style: TextStyle(
                            color: Color(0xffa7d8bf),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Community overview',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Monitor activity and keep listings moving.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh dashboard',
                    onPressed: () => setState(() => future = load()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _AdminSectionHeading(
              title: 'At a glance',
              subtitle: 'Live totals from the platform',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                crossAxisCount: constraints.maxWidth > 700 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: constraints.maxWidth > 700 ? 1.8 : 1.42,
                children: metrics
                    .map(
                      (metric) => _AdminMetricCard(
                        value: stats[metric.$1] ?? 0,
                        label: metric.$2,
                        icon: metric.$3,
                        onTap: () =>
                            widget.onNavigate?.call(metric.$4, metric.$5),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            const _AdminSectionHeading(
              title: 'Listings by category',
              subtitle: 'Where community donations are coming from',
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: categories.isEmpty
                    ? const Text(
                        'Category activity will appear here as listings are added.',
                      )
                    : Column(
                        children: categories.map((category) {
                          final count =
                              (category['count'] as num?)?.toInt() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pretty(
                                          category['category']?.toString() ??
                                              'Other',
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$count',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: count / largest,
                                    minHeight: 7,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AdminSectionHeading extends StatelessWidget {
  const _AdminSectionHeading({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final dynamic value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, this.roleFilter});
  final String? roleFilter;
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<dynamic> future;
  final search = TextEditingController();
  String statusFilter = 'ALL';
  String roleFilter = 'ALL';
  @override
  void initState() {
    super.initState();
    roleFilter = widget.roleFilter ?? 'ALL';
    future = load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<dynamic> load() async => (await Api.instance.dio.get(
    '/admin/users',
    queryParameters: {
      if (search.text.trim().isNotEmpty) 'q': search.text.trim(),
      if (roleFilter != 'ALL') 'role': roleFilter,
      'size': 100,
    },
  )).data;

  Future<void> changeStatus(Map<String, dynamic> user, String status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${pretty(status)} account?'),
        content: Text(
          'Change ${user['name']} to ${pretty(status).toLowerCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Confirm ${pretty(status).toLowerCase()}'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.instance.dio.patch(
        '/admin/users/${user['id']}/status',
        data: {'status': status},
      );
      if (mounted) {
        snack(context, 'Account status updated.');
        setState(() => future = load());
      }
    } on DioException catch (error) {
      if (mounted) {
        snack(
          context,
          error.response?.data is Map
              ? error.response?.data['message']?.toString() ??
                    'Could not update account.'
              : 'Could not update account.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (c, s) {
      if (s.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final payload = Map<String, dynamic>.from(s.data as Map);
      final allUsers = (payload['items'] as List? ?? const [])
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList();
      final users = statusFilter == 'ALL'
          ? allUsers
          : allUsers.where((u) => u['status'] == statusFilter).toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
        children: [
          _AdminSectionHeading(
            title: roleFilter == 'ALL'
                ? 'People'
                : '${pretty(roleFilter)} accounts',
            subtitle:
                '${payload['totalItems'] ?? allUsers.length} accounts in the community',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() => future = load()),
            decoration: InputDecoration(
              hintText: 'Search name or email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search users',
                onPressed: () => setState(() => future = load()),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'DONOR', 'RECIPIENT', 'ADMIN']
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          value == 'ALL' ? 'All roles' : pretty(value),
                        ),
                        selected: roleFilter == value,
                        onSelected: (_) => setState(() {
                          roleFilter = value;
                          future = load();
                        }),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'ACTIVE', 'SUSPENDED', 'BANNED']
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value == 'ALL' ? 'All' : pretty(value)),
                        selected: statusFilter == value,
                        onSelected: (_) => setState(() => statusFilter = value),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (users.isEmpty)
            const EmptyPane(
              title: 'No matching accounts',
              subtitle: 'Try another search or status filter.',
            ),
          ...users.map(
            (user) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xff244437),
                      child: Text(
                        (user['name']?.toString().isNotEmpty ?? false)
                            ? user['name'].toString()[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xffa7e3c4),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name']?.toString() ?? 'Unnamed user',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user['username']?.toString() ??
                                user['email']?.toString() ??
                                '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: [
                              _AdminTag(
                                label: pretty(
                                  user['role']?.toString() ?? 'USER',
                                ),
                                icon: Icons.person_outline,
                              ),
                              _AdminTag(
                                label: pretty(
                                  user['status']?.toString() ?? 'ACTIVE',
                                ),
                                icon: Icons.circle,
                                tone: user['status'] == 'ACTIVE'
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                              if ((user['city']?.toString().isNotEmpty ??
                                  false))
                                _AdminTag(
                                  label: user['city'].toString(),
                                  icon: Icons.location_on_outlined,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Account actions',
                      onSelected: (value) => changeStatus(user, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'ACTIVE', child: Text('Activate')),
                        PopupMenuItem(
                          value: 'SUSPENDED',
                          child: Text('Suspend'),
                        ),
                        PopupMenuItem(value: 'BANNED', child: Text('Ban')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class AdminDonationsPage extends StatefulWidget {
  const AdminDonationsPage({super.key});
  @override
  State<AdminDonationsPage> createState() => _AdminDonationsPageState();
}

class _AdminDonationsPageState extends State<AdminDonationsPage> {
  late Future<dynamic> future;
  final search = TextEditingController();
  String statusFilter = 'ALL';
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/admin/donations')).data;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> removeListing(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: Text(
          '“${item['title'] ?? 'Donation'}” will be removed from the community.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove listing'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.instance.dio.delete('/admin/donations/${item['id']}');
      if (mounted) {
        snack(context, 'Listing removed.');
        setState(() => future = load());
      }
    } on DioException catch (error) {
      if (mounted) {
        snack(
          context,
          error.response?.data is Map
              ? error.response?.data['message']?.toString() ??
                    'Could not remove listing.'
              : 'Could not remove listing.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final allItems = (snapshot.data as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();
      final items = allItems.where((item) {
        final matchesStatus =
            statusFilter == 'ALL' || item['status'] == statusFilter;
        final query = search.text.trim().toLowerCase();
        final matchesQuery =
            query.isEmpty ||
            [
              item['title'],
              item['donorName'],
              item['city'],
              item['pickupAddress'],
            ].any(
              (value) =>
                  value?.toString().toLowerCase().contains(query) ?? false,
            );
        return matchesStatus && matchesQuery;
      }).toList();
      if (items.isEmpty) {
        if (allItems.isEmpty) {
          return const EmptyPane(
            title: 'No listings yet',
            subtitle: 'Community listings will appear here.',
          );
        }
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
        children: [
          _AdminSectionHeading(
            title: 'Listings',
            subtitle: '${allItems.length} total community posts',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search title, donor, or city',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search listings',
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['ALL', 'AVAILABLE', 'RESERVED', 'PICKED_UP', 'CANCELLED']
                      .map(
                        (value) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value == 'ALL' ? 'All' : pretty(value)),
                            selected: statusFilter == value,
                            onSelected: (_) =>
                                setState(() => statusFilter = value),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const EmptyPane(
              title: 'No matching listings',
              subtitle: 'Try a different search or status filter.',
            ),
          ...items.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xff123a34),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']?.toString() ?? 'Donation',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item['donorName'] ?? 'Unknown donor'} · ${item['city'] ?? 'No city'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AdminTag(
                          label: pretty(
                            item['status']?.toString() ?? 'AVAILABLE',
                          ),
                          icon: Icons.circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${pretty(item['category']?.toString() ?? 'OTHER')} · ${item['availableQuantity'] ?? item['quantity'] ?? 0} available',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if ((item['pickupAddress']?.toString().isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          item['pickupAddress'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    const SizedBox(height: 9),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => removeListing(item),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove listing'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});
  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  late Future<dynamic> future;
  final search = TextEditingController();
  String statusFilter = 'ALL';
  final Set<dynamic> busy = {};
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/admin/requests')).data;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> act(Map<String, dynamic> row, String action) async {
    final id = row['id'];
    setState(() => busy.add(id));
    try {
      if (action == 'complete') {
        await Api.instance.dio.patch('/admin/requests/$id/complete');
      } else {
        await Api.instance.dio.patch(
          '/admin/requests/$id/decision',
          data: {'status': action},
        );
      }
      if (mounted) {
        snack(context, 'Request updated.');
        setState(() => future = load());
      }
    } on DioException catch (e) {
      if (mounted)
        snack(
          context,
          e.response?.data is Map
              ? e.response?.data['message']?.toString() ??
                    'Could not update request.'
              : 'Could not update request.',
        );
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return ErrorPane(onRetry: () => setState(() => future = load()));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final all = (snapshot.data as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();
      final q = search.text.trim().toLowerCase();
      final rows = all
          .where(
            (r) =>
                (statusFilter == 'ALL' || r['status'] == statusFilter) &&
                [
                  r['donationTitle'],
                  r['donorName'],
                  r['recipientName'],
                ].any((v) => v?.toString().toLowerCase().contains(q) ?? false),
          )
          .toList();
      return RefreshIndicator(
        onRefresh: () async => setState(() => future = load()),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          children: [
            _AdminSectionHeading(
              title: 'Donation requests',
              subtitle: '${all.length} requests across the community',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search listing, donor, or recipient',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                          'ALL',
                          'PENDING',
                          'ACCEPTED',
                          'COMPLETED',
                          'CANCELLED',
                          'REJECTED',
                        ]
                        .map(
                          (v) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(v == 'ALL' ? 'All' : pretty(v)),
                              selected: statusFilter == v,
                              onSelected: (_) =>
                                  setState(() => statusFilter = v),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            if (all.isEmpty)
              const EmptyPane(
                title: 'No requests yet',
                subtitle: 'Donation requests will appear here.',
              ),
            if (all.isNotEmpty && rows.isEmpty)
              const EmptyPane(
                title: 'No matching requests',
                subtitle: 'Try another search or status.',
              ),
            ...rows.map(
              (r) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r['donationTitle']?.toString() ?? 'Donation',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _AdminTag(
                            label: pretty(r['status']?.toString() ?? 'PENDING'),
                            icon: Icons.circle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Donor: ${r['donorName'] ?? 'Unknown'}  ·  Recipient: ${r['recipientName'] ?? 'Unknown'}',
                      ),
                      Text('Quantity: ${r['quantity'] ?? 1}'),
                      if ((r['message']?.toString().isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('“${r['message']}”'),
                        ),
                      if (r['status'] == 'PENDING' ||
                          r['status'] == 'ACCEPTED') ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (r['status'] == 'PENDING')
                              OutlinedButton.icon(
                                onPressed: busy.contains(r['id'])
                                    ? null
                                    : () => act(r, 'REJECTED'),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            if (r['status'] == 'PENDING')
                              FilledButton.icon(
                                onPressed: busy.contains(r['id'])
                                    ? null
                                    : () => act(r, 'ACCEPTED'),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                              ),
                            if (r['status'] == 'ACCEPTED')
                              FilledButton.icon(
                                onPressed: busy.contains(r['id'])
                                    ? null
                                    : () => act(r, 'complete'),
                                icon: const Icon(Icons.done_all),
                                label: const Text('Complete'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  late Future<dynamic> future;
  String statusFilter = 'OPEN';
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/admin/reports')).data;
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorPane(onRetry: () => setState(() => future = load()));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final reports = (snapshot.data as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();
      if (reports.isEmpty) {
        return const EmptyPane(
          title: 'No reports',
          subtitle: 'New community reports will appear here.',
        );
      }
      final visibleReports = statusFilter == 'ALL'
          ? reports
          : reports
                .where((report) => report['status'] == statusFilter)
                .toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
        children: [
          _AdminSectionHeading(
            title: 'Community reports',
            subtitle: '${reports.length} reports · review and resolve concerns',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['OPEN', 'REVIEWED', 'RESOLVED', 'DISMISSED', 'ALL']
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value == 'ALL' ? 'All' : pretty(value)),
                        selected: statusFilter == value,
                        onSelected: (_) => setState(() => statusFilter = value),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (visibleReports.isEmpty)
            const EmptyPane(
              title: 'No reports in this view',
              subtitle: 'Choose another status to see more reports.',
            ),
          ...visibleReports.map(
            (report) => Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pretty(report['reason']?.toString() ?? 'REPORT'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _AdminTag(
                          label: pretty(report['status']?.toString() ?? 'OPEN'),
                          icon: Icons.flag_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Reported by ${report['reporterName'] ?? 'Unknown user'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['reportedUserName'] != null
                          ? 'Account: ${report['reportedUserName']}'
                          : 'Listing: ${report['donationTitle'] ?? 'Unknown listing'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if ((report['details']?.toString().trim().isNotEmpty ??
                        false))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(report['details'].toString()),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (report['status'] == 'OPEN')
                          OutlinedButton(
                            onPressed: () =>
                                _setReportStatus(report['id'], 'REVIEWED'),
                            child: const Text('Mark reviewed'),
                          ),
                        if (report['status'] != 'RESOLVED')
                          FilledButton.tonal(
                            onPressed: () =>
                                _setReportStatus(report['id'], 'RESOLVED'),
                            child: const Text('Resolve'),
                          ),
                        if (report['status'] != 'DISMISSED')
                          TextButton(
                            onPressed: () =>
                                _setReportStatus(report['id'], 'DISMISSED'),
                            child: const Text('Dismiss'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _setReportStatus(dynamic id, String status) async {
    try {
      await Api.instance.dio.patch(
        '/admin/reports/$id',
        queryParameters: {'status': status},
      );
      if (mounted) {
        snack(context, 'Report marked ${pretty(status).toLowerCase()}.');
        setState(() => future = load());
      }
    } on DioException catch (error) {
      if (mounted) {
        snack(
          context,
          error.response?.data is Map
              ? error.response?.data['message']?.toString() ??
                    'Could not update report.'
              : 'Could not update report.',
        );
      }
    }
  }
}

class _AdminTag extends StatelessWidget {
  const _AdminTag({required this.label, required this.icon, this.tone});
  final String label;
  final IconData icon;
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/notifications')).data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorPane(onRetry: () => setState(() => future = load()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data as List;
        if (rows.isEmpty) {
          return const EmptyPane(
            title: 'All caught up',
            subtitle: 'Your notifications will show here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => future = load()),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _AdminSectionHeading(
                title: 'Your updates',
                subtitle:
                    '${rows.where((raw) => (raw as Map)['read'] != true).length} unread notifications',
              ),
              const SizedBox(height: 12),
              ...rows.map((raw) {
                final row = Map<String, dynamic>.from(raw);
                final unread = row['read'] != true;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: unread
                          ? Theme.of(context).colorScheme.primary
                                .withValues(alpha: .15)
                          : null,
                      child: Icon(
                        unread
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none,
                        color: unread
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    title: Text(
                      row['title']?.toString() ?? 'Update',
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(row['body']?.toString() ?? ''),
                    ),
                    trailing: unread
                        ? IconButton(
                            tooltip: 'Mark as read',
                            icon: const Icon(Icons.done),
                            onPressed: () async {
                              try {
                                await Api.instance.dio.patch(
                                  '/notifications/${row['id']}/read',
                                );
                                if (mounted) setState(() => future = load());
                              } on DioException catch (e) {
                                if (mounted)
                                  snack(
                                    context,
                                    e.response?.data?['message']?.toString() ??
                                        'Could not update notification.',
                                  );
                              }
                            },
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: unread
                        ? () async {
                            try {
                              await Api.instance.dio.patch(
                                '/notifications/${row['id']}/read',
                              );
                              if (mounted) setState(() => future = load());
                            } on DioException catch (e) {
                              if (mounted)
                                snack(
                                  context,
                                  e.response?.data?['message']?.toString() ??
                                      'Could not update notification.',
                                );
                            }
                          }
                        : null,
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );
}

class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key});
  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  final input = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool busy = false;
  Future<void> send() async {
    final question = input.text.trim();
    if (question.isEmpty || busy) return;
    input.clear();
    setState(() {
      messages.add({'text': question, 'who': 'You'});
      busy = true;
    });
    try {
      final response = await Api.instance.dio.post(
        '/chatbot',
        data: {'message': question},
      );
      if (mounted) {
        setState(
          () => messages.add({
            'text': response.data['answer']?.toString() ?? 'Please try again.',
            'who': 'ShareKind help',
          }),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => messages.add({
            'text':
                e.response?.data?['message']?.toString() ??
                'The help service could not respond.',
            'who': 'ShareKind help',
          }),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ShareKind help'),
    content: SizedBox(
      width: 420,
      height: 420,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: messages
                  .map(
                    (m) => ListTile(
                      title: Text(m['who']!),
                      subtitle: Text(m['text']!),
                    ),
                  )
                  .toList(),
            ),
          ),
          TextField(
            controller: input,
            onSubmitted: (_) => send(),
            decoration: InputDecoration(
              hintText: 'Ask how the platform works',
              suffixIcon: IconButton(
                onPressed: busy ? null : send,
                icon: const Icon(Icons.send),
              ),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class ErrorPane extends StatelessWidget {
  const ErrorPane({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 48),
        const Text('Could not load data. Check the API connection.'),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.volunteer_activism, size: 52, color: Colors.grey),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Text(subtitle),
      ],
    ),
  );
}

String pretty(String s) => s
    .toLowerCase()
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
Future<void> _reportPerson(
  BuildContext context,
  int userId,
  String name,
) async {
  String reason = 'OTHER';
  final details = TextEditingController();
  final submit = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, update) => AlertDialog(
        title: Text('Report $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: const [
                DropdownMenuItem(
                  value: 'HARASSMENT',
                  child: Text('Harassment or abuse'),
                ),
                DropdownMenuItem(value: 'FRAUD', child: Text('Fraud or scam')),
                DropdownMenuItem(
                  value: 'INAPPROPRIATE',
                  child: Text('Inappropriate behavior'),
                ),
                DropdownMenuItem(value: 'OTHER', child: Text('Other concern')),
              ],
              onChanged: (value) => update(() => reason = value ?? reason),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: details,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Tell us what happened',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send report'),
          ),
        ],
      ),
    ),
  );
  if (submit == true) {
    try {
      await Api.instance.dio.post(
        '/reports',
        data: {
          'reportedUserId': userId,
          'reason': reason,
          'details': details.text.trim(),
        },
      );
      if (context.mounted)
        snack(context, 'Report sent to the moderation team.');
    } on DioException catch (e) {
      if (context.mounted)
        snack(
          context,
          e.response?.data?['message']?.toString() ??
              'Could not submit the report.',
        );
    }
  }
  details.dispose();
}

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
