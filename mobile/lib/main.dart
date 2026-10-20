import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'core/api.dart';

void main() => runApp(const RdpApp());

class RdpApp extends StatelessWidget {
  const RdpApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ShareKind',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff176b55),
        brightness: Brightness.dark,
        primary: const Color(0xff82d6b4),
        secondary: const Color(0xffe8b56d),
        surface: const Color(0xff1b2622),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff101714),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff101714),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xffedf5f0),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xff1b2622),
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .22),
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff1b2622),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xff34443d)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xff82d6b4), width: 1.5),
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
        backgroundColor: const Color(0xff151f1b),
        indicatorColor: const Color(0xff294b3e),
        elevation: 8,
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
        backgroundColor: const Color(0xff1b2622),
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
    } catch (_) {
      await Api.instance.setToken(null);
    }
    if (mounted) setState(() => loading = false);
  }

  void signedIn(Map<String, dynamic> u) => setState(() {
    user = u;
    Api.instance.role = u['role']?.toString();
  });
  Future<void> signOut() async {
    await Api.instance.setToken(null);
    Api.instance.role = null;
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
      email = TextEditingController(),
      password = TextEditingController(),
      city = TextEditingController();
  String role = 'RECIPIENT';
  bool register = false, busy = false;
  String? error;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = register
          ? await Api.instance.register(
              name.text,
              email.text,
              password.text,
              role,
              city.text,
            )
          : await Api.instance.login(email.text, password.text);
      await Api.instance.setToken(res['token']);
      widget.onSignedIn(Map<String, dynamic>.from(res['user']));
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
                    color: const Color(0xff203b31),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism,
                    size: 40,
                    color: Color(0xff82d6b4),
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
                const SizedBox(height: 24),
                if (register) ...[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
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
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (10+ characters)',
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Please wait…'
                        : register
                        ? 'Create account'
                        : 'Sign in',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    register = !register;
                    error = null;
                  }),
                  child: Text(register ? 'Sign in' : 'Create an account'),
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

class _HomeState extends State<Home> {
  int index = 0;
  final myDonationsKey = GlobalKey<_DonationListState>();
  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'];
    final donor = role == 'DONOR', admin = role == 'ADMIN';
    final labels = admin
        ? ['Overview', 'Users', 'Donations', 'Reports']
        : donor
        ? ['Donations', 'Requests', 'Messages', 'Profile']
        : [
            'Explore',
            'Requests',
            'Favorites',
            'For you',
            'Messages',
            'Profile',
          ];
    final pages = admin
        ? [
            const AdminPage(),
            const UsersPage(),
            const AdminDonationsPage(),
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
        ? [Icons.dashboard, Icons.people, Icons.inventory_2, Icons.flag]
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
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xff203b31),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.volunteer_activism,
                size: 19,
                color: Color(0xff82d6b4),
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
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_outlined),
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
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
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

  void refresh() => setState(() => future = load());
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!widget.mine)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: search,
                onSubmitted: (_) => refresh(),
                decoration: InputDecoration(
                  hintText: 'Search resources',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: refresh,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
              Row(
                children: [
                  DropdownButton<String?>(
                    value: category,
                    hint: const Text('All categories'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...cats.map(
                        (x) =>
                            DropdownMenuItem(value: x, child: Text(pretty(x))),
                      ),
                    ],
                    onChanged: (v) {
                      category = v;
                      refresh();
                    },
                  ),
                  IconButton(
                    tooltip: mapView ? 'Show list' : 'Show map',
                    onPressed: () => setState(() => mapView = !mapView),
                    icon: Icon(mapView ? Icons.list_alt : Icons.map_outlined),
                  ),
                  TextButton.icon(
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
                          : Icons.clear,
                    ),
                    label: Text(
                      nearbyLatitude == null ? 'Nearby' : 'Clear nearby',
                    ),
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
        ? const Color(0xff203b31)
        : reserved
        ? const Color(0xff48351f)
        : const Color(0xff303936);
    final foreground = available
        ? const Color(0xff82d6b4)
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volunteer_activism,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['title'] ?? 'Donation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _StatusPill(status: item['status']?.toString() ?? 'AVAILABLE'),
              if (Api.instance.role == 'RECIPIENT')
                IconButton(
                  tooltip: favorite ? 'Remove saved item' : 'Save item',
                  onPressed: savingFavorite ? null : toggleFavorite,
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite ? Colors.red : null,
                  ),
                ),
            ],
          ),
          ..._donationPhotoStrip(item),
          Text(
            '${pretty(item['category'] ?? '')} · ${item['availableQuantity'] ?? item['quantity'] ?? 1} ${item['status'] == 'AVAILABLE' ? 'available' : 'remaining'}',
          ),
          Text('${item['city'] ?? item['donorCity'] ?? 'Location not set'}'),
          TextButton.icon(
            onPressed: () => viewDonor(context),
            icon: const Icon(Icons.person_outline),
            label: Text('View ${item['donorName'] ?? 'donor'} profile'),
          ),
          if (widget.isOwner &&
              (item['pickupAddress']?.toString().isNotEmpty ?? false))
            Text('Pickup address: ${item['pickupAddress']}'),
          Text(
            item['description'] ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (item['latitude'] != null && item['longitude'] != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DonationMap(item: item),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Pickup map'),
              ),
            ),
          if (widget.isOwner)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  if (item['status'] == 'AVAILABLE')
                    TextButton.icon(
                      onPressed: () => edit(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  if (item['status'] != 'PICKED_UP' &&
                      item['status'] != 'CANCELLED')
                    TextButton.icon(
                      onPressed: () => delete(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                ],
              ),
            ),
          if (!widget.isOwner && item['status'] == 'RESERVED')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Pickup is being arranged',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.isOwner &&
              Api.instance.role == 'RECIPIENT' &&
              item['status'] == 'AVAILABLE')
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => contactDonor(context),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message donor'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => request(context),
                    child: const Text('Request item'),
                  ),
                ],
              ),
            ),
        ],
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
  bool connected = false;
  String? error;
  int get conversationId => widget.conversation['id'] as int;
  @override
  void initState() {
    super.initState();
    load();
    connect();
  }

  Future<void> load() async {
    try {
      final response = await Api.instance.dio.get(
        '/conversations/$conversationId/messages',
      );
      if (mounted) {
        setState(
          () => messages
            ..clear()
            ..addAll(
              (response.data as List).map((x) => Map<String, dynamic>.from(x)),
            ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => error =
              e.response?.data?['message']?.toString() ??
              'Could not load chat history.',
        );
      }
    }
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
              if (mounted) setState(() => messages.add(item));
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
    if (body.isEmpty || !connected) return;
    channel?.sink.add(
      'SEND\ndestination:/app/chat/$conversationId\ncontent-type:application/json\n\n${jsonEncode({'body': body})}\u0000',
    );
    input.clear();
  }

  @override
  void dispose() {
    channel?.sink.close();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.conversation['otherUserName']?.toString() ?? 'Chat'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(42),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.conversation['donationTitle']?.toString() ?? 'Listing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                connected ? 'Live chat connected' : 'Connecting to live chat…',
              ),
            ],
          ),
        ),
      ),
    ),
    body: Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [TextButton(onPressed: load, child: const Text('Retry'))],
          ),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            children: messages
                .map(
                  (m) => Align(
                    alignment: Alignment.centerLeft,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['senderName']?.toString() ?? 'Participant',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(m['body']?.toString() ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
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
                  onPressed: connected ? send : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
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
                        color: Color(0xff176b55),
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
                  color: Color(0xff176b55),
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
                          color: Color(0xff176b55),
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
      final rows = s.data as List;
      if (rows.isEmpty) {
        return const EmptyPane(
          title: 'No requests',
          subtitle: 'Requests appear here.',
        );
      }
      return ListView(
        children: rows.map((x) {
          final r = Map<String, dynamic>.from(x);
          final status = r['status'];
          return Card(
            child: ListTile(
              title: Text(r['donationTitle'] ?? 'Donation'),
              subtitle: Text(
                '${r['recipientName'] ?? r['donorName']} · ${pretty(status)}',
              ),
              trailing: status == 'PENDING' && widget.incoming
                  ? Wrap(
                      children: [
                        IconButton(
                          onPressed: () => decide(r['id'], 'REJECTED'),
                          icon: const Icon(Icons.close),
                        ),
                        IconButton(
                          onPressed: () => decide(r['id'], 'ACCEPTED'),
                          icon: const Icon(Icons.check),
                        ),
                      ],
                    )
                  : status == 'ACCEPTED' || status == 'COMPLETED'
                  ? Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Chat',
                          onPressed: () => openChat(context, r['id']),
                          icon: const Icon(Icons.chat_bubble_outline),
                        ),
                        if (widget.incoming && status == 'ACCEPTED')
                          IconButton(
                            tooltip: 'Mark picked up',
                            onPressed: () => complete(r['id']),
                            icon: const Icon(Icons.done_all),
                          ),
                        if (!widget.incoming &&
                            status == 'COMPLETED' &&
                            !ratedRequests.contains(r['id']))
                          IconButton(
                            tooltip: 'Rate donor',
                            onPressed: () => rate(context, r['id']),
                            icon: const Icon(Icons.star_outline),
                          ),
                      ],
                    )
                  : null,
            ),
          );
        }).toList(),
      );
    },
  );
  Future<void> decide(dynamic id, String status) async {
    await Api.instance.dio.patch(
      '/requests/$id/decision',
      data: {'status': status},
    );
    await refresh();
  }

  Future<void> complete(dynamic id) async {
    await Api.instance.dio.patch('/requests/$id/complete');
    await refresh();
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

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});
  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<dynamic> load() async =>
      (await Api.instance.dio.get('/conversations')).data;

  void refresh() => setState(() => future = load());

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
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.chat_bubble_outline),
                ),
                title: Text(
                  conversation['otherUserName']?.toString() ?? 'Conversation',
                ),
                subtitle: Text(
                  conversation['donationTitle']?.toString() ?? 'Listing',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(conversation: conversation),
                  ),
                ),
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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      CircleAvatar(
        radius: 42,
        child: Text((user['name'] ?? '?')[0].toString().toUpperCase()),
      ),
      Text(
        user['name'] ?? '',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(user['email'] ?? '', textAlign: TextAlign.center),
      Text(
        '${user['role']} · ${user['city'] ?? 'City not set'}',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
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
      final metrics = <(String, String, IconData)>[
        ('totalUsers', 'Community members', Icons.groups_2_outlined),
        ('donors', 'Donors', Icons.volunteer_activism_outlined),
        ('recipients', 'Recipients', Icons.people_alt_outlined),
        ('activeUsers', 'Active accounts', Icons.verified_user_outlined),
        ('totalDonations', 'All listings', Icons.inventory_2_outlined),
        ('availableDonations', 'Available now', Icons.storefront_outlined),
        ('completedDonations', 'Completed pickups', Icons.task_alt_outlined),
        (
          'pendingRequests',
          'Pending requests',
          Icons.mark_email_unread_outlined,
        ),
        ('openReports', 'Open reports', Icons.flag_outlined),
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
  });
  final dynamic value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
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
  );
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<dynamic> future;
  final search = TextEditingController();
  String statusFilter = 'ALL';
  @override
  void initState() {
    super.initState();
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
            title: 'People',
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
                            user['email']?.toString() ?? '',
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
                            color: const Color(0xff203b31),
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
        return ListView(
          children: rows.map((raw) {
            final row = Map<String, dynamic>.from(raw);
            return ListTile(
              leading: Icon(
                row['read'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined,
              ),
              title: Text(row['title']?.toString() ?? 'Update'),
              subtitle: Text(row['body']?.toString() ?? ''),
              onTap: row['read'] == true
                  ? null
                  : () async {
                      await Api.instance.dio.patch(
                        '/notifications/${row['id']}/read',
                      );
                      if (mounted) setState(() => future = load());
                    },
            );
          }).toList(),
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
void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
